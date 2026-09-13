[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$RunId,

    [Parameter(Mandatory)]
    [ValidateSet('control','plan')]
    [string]$Variant,

    [ValidateRange(0,1)]
    [int]$Team = 0,

    [ValidateSet('knight','archer','bomb','mixed')]
    [string]$Scenario = 'mixed',

    [ValidateRange(0,4294967295)]
    [uint64]$Seed = 101,

    [string]$TranscriptPath = '',

    [switch]$CompilerForwarding
)

$ErrorActionPreference = 'Stop'
$modRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$kagRoot = (Resolve-Path (Join-Path $modRoot '..\..')).Path
$rootConfig = Join-Path $kagRoot 'autoconfig.cfg'
$kagExe = Join-Path $kagRoot 'KAG.exe'
$logsDirectory = Join-Path $kagRoot 'Logs'
$tcprSend = Join-Path $PSScriptRoot 'tcpr_send.py'
$aibTestConfig = Join-Path $modRoot 'Rules\AIBTest\gamemode.cfg'
$ctfRules = Join-Path $modRoot 'Rules\CTF\gamemode.cfg'
$disabledCtfRules = "$ctfRules.aibtest-disabled"
$autostart = '../Mods/GuiftsDynamicBlueprint_vDev/Scripts/aib_gym_autostart.as'

if ([string]::IsNullOrWhiteSpace($TranscriptPath)) {
    $TranscriptPath = Join-Path $modRoot "Artifacts\aib_gym\$RunId.tcpr.txt"
} elseif (![IO.Path]::IsPathRooted($TranscriptPath)) {
    $TranscriptPath = Join-Path $modRoot $TranscriptPath
}
$TranscriptPath = [IO.Path]::GetFullPath($TranscriptPath)

function Set-ConfigValue([string]$text, [string]$name, [string]$value) {
    $pattern = '(?m)^' + [regex]::Escape($name) + '\s*=.*$'
    $line = if ([string]::IsNullOrEmpty($value)) { "$name =" } else { "$name = $value" }
    if ([regex]::IsMatch($text, $pattern)) { return [regex]::Replace($text, $pattern, $line) }
    return $text + [Environment]::NewLine + $line + [Environment]::NewLine
}

function Write-RootSettings([bool]$testMode, [bool]$compilerOutput) {
    $text = [IO.File]::ReadAllText($rootConfig)
    $text = Set-ConfigValue $text 'sv_gamemode' 'CTF'
    $text = Set-ConfigValue $text 'sv_mapcycle' ''
    $text = Set-ConfigValue $text 'sv_mapcycle_shuffle' 'true'
    $text = Set-ConfigValue $text 'sv_test' ($testMode ? 'true' : 'false')
    $text = Set-ConfigValue $text 'sv_tcpr' 'true'
    $text = Set-ConfigValue $text 'sv_tcpr_everything' ($compilerOutput ? 'true' : 'false')
    $text = Set-ConfigValue $text 'sv_tcpr_timestamp' 'false'
    [IO.File]::WriteAllText($rootConfig, $text, [Text.UTF8Encoding]::new($false))
}

function Restore-Handoff {
    Write-RootSettings $false $false
    $text = [IO.File]::ReadAllText($aibTestConfig)
    foreach ($name in @('aibtest_scenario','aibtest_start_scenario','aibtest_end_scenario')) {
        $text = Set-ConfigValue $text $name ''
    }
    [IO.File]::WriteAllText($aibTestConfig, $text, [Text.UTF8Encoding]::new($false))
    if (!(Test-Path -LiteralPath $ctfRules -PathType Leaf)) { throw 'Rules/CTF/gamemode.cfg is missing after wave cleanup.' }
    if (Test-Path -LiteralPath $disabledCtfRules) { throw 'Rules/CTF/gamemode.cfg.aibtest-disabled remains after wave cleanup.' }
}

function Stop-OwnedKAG([int]$processId) {
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if (!$process) { return }
        $process | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
    }
    throw "Owned KAG PID $processId did not terminate within 30 seconds."
}

$existing = @(Get-Process -Name KAG -ErrorAction SilentlyContinue)
if ($existing.Count -ne 0) {
    throw "Refusing to start a wave run while $($existing.Count) KAG process(es) already exist."
}

$ownedPid = 0
$runFailure = $null
try {
    Write-RootSettings $true ([bool]$CompilerForwarding)
    $launchTime = Get-Date
    $process = Start-Process -FilePath $kagExe -WorkingDirectory $kagRoot `
        -ArgumentList @('noautoupdate','nolauncher','autostart',$autostart) -PassThru
    $ownedPid = $process.Id
    Write-Host "Started visible KAG wave fixture PID $ownedPid for $RunId"

    $logDeadline = (Get-Date).AddSeconds(15)
    $consoleLog = $null
    do {
        $consoleLog = Get-ChildItem -LiteralPath $logsDirectory -Filter 'console-*.txt' -File |
            Where-Object { $_.LastWriteTime -ge $launchTime.AddSeconds(-2) } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($null -ne $consoleLog) { break }
        Start-Sleep -Milliseconds 200
    } while ((Get-Date) -lt $logDeadline)
    if ($null -eq $consoleLog) { throw 'KAG did not create a console log within 15 seconds.' }

    $expect = 'AIBWAVE\|RESULT\|run=' + [regex]::Escape($RunId)
    $fail = 'ERROR .*GuiftsDynamicBlueprint_vDev.*\.as:|Rules partially failed initialization|Script .* has errors|AIBWAVE\|ABORT\|run=' + [regex]::Escape($RunId)
    $arguments = @(
        $tcprSend,
        '--config', $rootConfig,
        '--connect-timeout-seconds', '45',
        '--stability-seconds', '3',
        '--delay-ms', '250',
        '--transcript', $TranscriptPath,
        '--command', 'getRules().SetCurrentState(GAME)',
        '--command', "getRules().set_u8(`"aib wave request team`", $Team)",
        '--command', "getRules().set_u32(`"aib wave request seed`", $Seed)",
        '--command', "getRules().set_string(`"aib wave request variant`", `"$Variant`")",
        '--command', "getRules().set_string(`"aib wave request scenario`", `"$Scenario`")",
        '--command', "getRules().set_string(`"aib wave request run id`", `"$RunId`")",
        '--command', 'getRules().set_bool("aib wave request", true)',
        '--command', "tcpr(`"AIBWAVE|REQUESTED|run=$RunId`")",
        '--listen-seconds', '180',
        '--expect', $expect,
        '--fail', $fail,
        '--fail-file', $consoleLog.FullName
    )
    & python @arguments
    if ($LASTEXITCODE -ne 0) { throw "tcpr_send.py failed with exit code $LASTEXITCODE." }

    $resultPattern = '^\[AIBEVT\](?=.*\bsource=strategy\b)(?=.*\baction=wave_result\b)(?=.*\brun_id=' + [regex]::Escape($RunId) + '\b)'
    $results = @(Select-String -LiteralPath $TranscriptPath -Pattern $resultPattern)
    $uniqueResultLines = @($results.Line | Select-Object -Unique)
    if ($uniqueResultLines.Count -ne 1) {
        throw "The TCPR transcript must contain one unique wave result row; found raw=$($results.Count) unique=$($uniqueResultLines.Count)."
    }
    Write-Host "AIB_WAVE_RESULT run=$RunId scenario=$Scenario variant=$Variant transcript=$TranscriptPath"
    $uniqueResultLines[0]
} catch {
    $runFailure = $_
} finally {
    if ($ownedPid -ne 0) { Stop-OwnedKAG $ownedPid }
    $drainDeadline = (Get-Date).AddSeconds(30)
    do {
        $otherKag = @(Get-Process -Name KAG -ErrorAction SilentlyContinue)
        if ($otherKag.Count -eq 0) { break }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $drainDeadline)
    if ($otherKag.Count -ne 0) {
        throw "KAG cleanup left $($otherKag.Count) unowned process(es); handoff was not restored while they are live."
    }
    Restore-Handoff
    Write-Host 'KAG wave process stopped; required CTF handoff restored.'
}

if ($null -ne $runFailure) { throw $runFailure }
