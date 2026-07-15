[CmdletBinding()]
param(
    [ValidateSet('Start','Run','Stop','Status')]
    [string]$Action = 'Run',
    [string]$Scenario = 'strategic_remaining_material_cost',
    [int]$TimeoutSeconds = 90
)

$ErrorActionPreference = 'Stop'
if ($TimeoutSeconds -le 0) { throw 'TimeoutSeconds must be positive.' }

$researchRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$modRoot = Resolve-Path (Join-Path $researchRoot '..')
$kagRoot = Resolve-Path (Join-Path $modRoot '..\..')
$privateRoot = Join-Path $researchRoot 'private\fast_loop'
$statePath = Join-Path $privateRoot 'session.json'
$snapshotRoot = Join-Path $privateRoot 'snapshot'
$metricsPath = Join-Path $privateRoot 'runs.ndjson'
$scenarioSource = Join-Path $modRoot 'Scripts\AIBTestScenarios.as'
$aibConfig = Join-Path $modRoot 'Rules\AIBTest\gamemode.cfg'
$ctfConfig = Join-Path $modRoot 'Rules\CTF\gamemode.cfg'
$ctfDisabled = Join-Path $modRoot 'Rules\CTF\gamemode.cfg.aibtest-disabled'
$rootConfig = Join-Path $kagRoot 'autoconfig.cfg'
$kagExe = Join-Path $kagRoot 'KAG.exe'
$tcprAIBRun = Join-Path $PSScriptRoot 'tcpr_aib_run.py'
$autostart = '../Mods/GuiftsDynamicBlueprint_vDev/research/runtime/aib_fast_test_autostart.as'

function Read-State {
    if (!(Test-Path -LiteralPath $statePath)) { return $null }
    return Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
}

function Write-State($state) {
    if (!(Test-Path -LiteralPath $privateRoot)) {
        New-Item -ItemType Directory -Path $privateRoot | Out-Null
    }
    $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statePath -Encoding utf8
}

function Get-OwnedProcess($state) {
    if ($null -eq $state -or $null -eq $state.pid) { return $null }
    $process = Get-Process -Id ([int]$state.pid) -ErrorAction SilentlyContinue
    if ($null -eq $process) { return $null }
    try {
        $actualPath = $process.Path
        $actualStart = $process.StartTime.ToUniversalTime().Ticks
    } catch {
        return $null
    }
    if (![string]::Equals($actualPath, $kagExe, [StringComparison]::OrdinalIgnoreCase)) { return $null }
    if ([int64]$state.process_start_ticks -ne [int64]$actualStart) { return $null }
    return $process
}

function Get-ScenarioNames {
    $source = Get-Content -Raw -LiteralPath $scenarioSource
    $match = [regex]::Match($source, '(?s)string\[\]\s+AIBT_SCENARIOS\s*=\s*\{(?<body>.*?)\};')
    if (!$match.Success) { throw "Could not parse AIBT_SCENARIOS from $scenarioSource" }
    return @([regex]::Matches($match.Groups['body'].Value, '"(?<name>[^"]+)"') |
        ForEach-Object { $_.Groups['name'].Value })
}

function Assert-Scenario([string]$name) {
    if ([string]::IsNullOrWhiteSpace($name)) { throw 'Scenario cannot be blank.' }
    if ((Get-ScenarioNames) -cnotcontains $name) { throw "Unknown AIBTest scenario: $name" }
}

function Set-ConfigValue([string]$text, [string]$key, [string]$value, [string]$path) {
    $pattern = '(?m)^([ \t]*' + [regex]::Escape($key) + '[ \t]*=[ \t]*).*$'
    if (![regex]::IsMatch($text, $pattern)) { throw "Missing $key in $path" }
    $replacement = '$' + '{1}' + $value
    return [regex]::Replace($text, $pattern, $replacement, 1)
}

function Set-TestSelection([string]$name) {
    $text = Get-Content -Raw -LiteralPath $aibConfig
    $text = Set-ConfigValue $text 'aibtest_scenario' $name $aibConfig
    $text = Set-ConfigValue $text 'aibtest_start_scenario' '' $aibConfig
    $text = Set-ConfigValue $text 'aibtest_end_scenario' '' $aibConfig
    [IO.File]::WriteAllText($aibConfig, $text, [Text.UTF8Encoding]::new($false))
}

function Set-RootHandoff {
    if (!(Test-Path -LiteralPath $rootConfig)) { return }
    $text = Get-Content -Raw -LiteralPath $rootConfig
    $text = Set-ConfigValue $text 'sv_gamemode' 'CTF' $rootConfig
    $text = Set-ConfigValue $text 'sv_mapcycle' '' $rootConfig
    $text = Set-ConfigValue $text 'sv_mapcycle_shuffle' 'true' $rootConfig
    # Preserve the normal explicit-record-only TCPR bridge policy at handoff.
    $text = Set-ConfigValue $text 'sv_tcpr' 'true' $rootConfig
    $text = Set-ConfigValue $text 'sv_tcpr_everything' 'false' $rootConfig
    $text = Set-ConfigValue $text 'sv_tcpr_timestamp' 'false' $rootConfig
    [IO.File]::WriteAllText($rootConfig, $text, [Text.UTF8Encoding]::new($false))
}

function Set-BlankAIBSelection {
    if (!(Test-Path -LiteralPath $aibConfig)) { return }
    $text = Get-Content -Raw -LiteralPath $aibConfig
    $text = Set-ConfigValue $text 'aibtest_scenario' '' $aibConfig
    $text = Set-ConfigValue $text 'aibtest_start_scenario' '' $aibConfig
    $text = Set-ConfigValue $text 'aibtest_end_scenario' '' $aibConfig
    [IO.File]::WriteAllText($aibConfig, $text, [Text.UTF8Encoding]::new($false))
}

function Set-ResearchTCPRForwarding {
    $text = Get-Content -Raw -LiteralPath $rootConfig
    $text = Set-ConfigValue $text 'sv_tcpr' 'true' $rootConfig
    $text = Set-ConfigValue $text 'sv_tcpr_everything' 'true' $rootConfig
    $text = Set-ConfigValue $text 'sv_tcpr_timestamp' 'false' $rootConfig
    [IO.File]::WriteAllText($rootConfig, $text, [Text.UTF8Encoding]::new($false))
}

function Restore-SessionFiles {
    # KAG writes autoconfig on exit, so this is called only after the owned
    # process is confirmed gone.
    if ((Test-Path -LiteralPath $ctfDisabled) -and !(Test-Path -LiteralPath $ctfConfig)) {
        Move-Item -LiteralPath $ctfDisabled -Destination $ctfConfig
    }
    Set-BlankAIBSelection
    Set-RootHandoff
}

function Stop-Session([switch]$Quiet) {
    $state = Read-State
    $process = Get-OwnedProcess $state
    if ($process) {
        if (!$Quiet) { Write-Host "Stopping research-owned visible KAG PID $($process.Id)..." }
        Stop-Process -Id $process.Id -Force
        $process.WaitForExit(10000) | Out-Null
    }
    $stillOwned = Get-OwnedProcess $state
    if ($stillOwned) { throw "Research-owned KAG PID $($stillOwned.Id) did not exit." }
    Restore-SessionFiles
    if (Test-Path -LiteralPath $statePath) { Remove-Item -LiteralPath $statePath -Force }
    if (!$Quiet) { Write-Host 'Persistent AIBTest session stopped; CTF handoff restored.' }
}

function Invoke-TCPRVerdict([bool]$rebuild) {
    $tcprArgs = @(
        '-B',
        $tcprAIBRun,
        '--config', $rootConfig,
        '--scenario', $Scenario,
        '--connect-timeout-seconds', '60',
        '--rules-ready-timeout-seconds', '45',
        '--timeout-seconds', [string]$TimeoutSeconds,
        '--metrics', $metricsPath
    )
    if ($rebuild) { $tcprArgs += '--rebuild' }
    & python @tcprArgs
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "Authoritative TCPR AIBTest run failed with exit code $exitCode."
    }
}

function Start-Session {
    Assert-Scenario $Scenario
    $existing = Read-State
    if (Get-OwnedProcess $existing) { throw 'A research AIBTest session is already active. Use -Action Run or Stop.' }
    $otherKag = @(Get-Process -Name KAG -ErrorAction SilentlyContinue)
    if ($otherKag.Count -gt 0) { throw 'A non-research KAG process is already running; refusing to take ownership.' }
    if (Test-Path -LiteralPath $statePath) { Stop-Session -Quiet }
    if (!(Test-Path -LiteralPath $aibConfig)) { throw "Missing $aibConfig" }
    if (!(Test-Path -LiteralPath $ctfConfig)) { throw "Missing $ctfConfig" }
    if (Test-Path -LiteralPath $ctfDisabled) { throw "Refusing to overwrite stale $ctfDisabled" }
    if (!(Test-Path -LiteralPath $rootConfig)) { throw "Missing $rootConfig" }

    $process = $null
    $stateWritten = $false
    try {
        New-Item -ItemType Directory -Path $snapshotRoot -Force | Out-Null
        Copy-Item -LiteralPath $aibConfig -Destination (Join-Path $snapshotRoot 'aibtest-gamemode.before.cfg') -Force
        Copy-Item -LiteralPath $ctfConfig -Destination (Join-Path $snapshotRoot 'ctf-gamemode.before.cfg') -Force
        Copy-Item -LiteralPath $rootConfig -Destination (Join-Path $snapshotRoot 'autoconfig.before.cfg') -Force
        Set-ResearchTCPRForwarding
        Set-TestSelection $Scenario
        Move-Item -LiteralPath $ctfConfig -Destination $ctfDisabled

        $startedUtc = [datetime]::UtcNow
        $process = Start-Process -FilePath $kagExe -WorkingDirectory $kagRoot -ArgumentList @(
            'noautoupdate','nolauncher','autostart',$autostart
        ) -PassThru
        $state = [ordered]@{
            schema = 1
            pid = $process.Id
            process_start_ticks = $process.StartTime.ToUniversalTime().Ticks
            started_utc = $startedUtc.ToString('o')
            scenario = $Scenario
        }
        Write-State $state
        $stateWritten = $true
        Write-Host "Started visible persistent AIBTest PID $($process.Id)."
        Invoke-TCPRVerdict $false
        Write-Host 'KAG remains visible for the active TCPR/reload iteration session.'
    } catch {
        if ($stateWritten) {
            Stop-Session -Quiet
        } else {
            if ($process -and !$process.HasExited) {
                Stop-Process -Id $process.Id -Force
                $process.WaitForExit(10000) | Out-Null
            }
            Restore-SessionFiles
            if (Test-Path -LiteralPath $statePath) { Remove-Item -LiteralPath $statePath -Force }
        }
        throw
    }
}

function Run-Hot {
    Assert-Scenario $Scenario
    $state = Read-State
    $process = Get-OwnedProcess $state
    if (!$process) {
        if ($state) { Stop-Session -Quiet }
        throw 'No live research-owned AIBTest session; stale handoff state was cleaned. Use -Action Start first.'
    }
    Set-TestSelection $Scenario
    $state.scenario = $Scenario
    Write-State $state
    try {
        Invoke-TCPRVerdict $true
    } catch {
        Stop-Session -Quiet
        throw
    }
}

switch ($Action) {
    'Start' { Start-Session }
    'Run' { Run-Hot }
    'Stop' { Stop-Session }
    'Status' {
        $state = Read-State
        $process = Get-OwnedProcess $state
        if ($process) {
            [PSCustomObject]@{
                active = $true
                pid = $process.Id
                scenario = $state.scenario
                window = $process.MainWindowTitle
            }
        } else {
            [PSCustomObject]@{ active = $false; pid = $null; scenario = ''; window = '' }
        }
    }
}
