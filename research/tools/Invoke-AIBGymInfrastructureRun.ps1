[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$RunId,

    [Parameter(Mandatory)]
    [ValidateSet('control','candidate','diagnostic')]
    [string]$Variant,

    [ValidateRange(0,7)]
    [int]$Team = 0,

    [string]$TranscriptPath = '',

    [switch]$CompilerForwarding
)

$ErrorActionPreference = 'Stop'
$modRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$kagRoot = (Resolve-Path (Join-Path $modRoot '..\..')).Path
$rootConfig = Join-Path $kagRoot 'autoconfig.cfg'
$kagExe = Join-Path $kagRoot 'KAG.exe'
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

function Write-RootSettings([bool]$compilerOutput) {
    $text = [IO.File]::ReadAllText($rootConfig)
    $text = Set-ConfigValue $text 'sv_gamemode' 'CTF'
    $text = Set-ConfigValue $text 'sv_mapcycle' ''
    $text = Set-ConfigValue $text 'sv_mapcycle_shuffle' 'true'
    $text = Set-ConfigValue $text 'sv_tcpr' 'true'
    $text = Set-ConfigValue $text 'sv_tcpr_everything' ($compilerOutput ? 'true' : 'false')
    $text = Set-ConfigValue $text 'sv_tcpr_timestamp' 'false'
    [IO.File]::WriteAllText($rootConfig, $text, [Text.UTF8Encoding]::new($false))
}

function Restore-Handoff {
    Write-RootSettings $false
    $text = [IO.File]::ReadAllText($aibTestConfig)
    foreach ($name in @('aibtest_scenario','aibtest_start_scenario','aibtest_end_scenario')) {
        $text = Set-ConfigValue $text $name ''
    }
    [IO.File]::WriteAllText($aibTestConfig, $text, [Text.UTF8Encoding]::new($false))
    if (!(Test-Path -LiteralPath $ctfRules -PathType Leaf)) { throw 'Rules/CTF/gamemode.cfg is missing after gym cleanup.' }
    if (Test-Path -LiteralPath $disabledCtfRules) { throw 'Rules/CTF/gamemode.cfg.aibtest-disabled remains after gym cleanup.' }
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
    throw "Refusing to start an infrastructure run while $($existing.Count) KAG process(es) already exist."
}

$ownedPid = 0
$runFailure = $null
try {
    Write-RootSettings ([bool]$CompilerForwarding)
    $process = Start-Process -FilePath $kagExe -WorkingDirectory $kagRoot `
        -ArgumentList @('noautoupdate','nolauncher','autostart',$autostart) -PassThru
    $ownedPid = $process.Id
    Write-Host "Started visible KAG infrastructure benchmark PID $ownedPid for $RunId"

    $expect = 'AIBGYMI\|RESULT\|run=' + [regex]::Escape($RunId)
    $fail = 'ERROR .*GuiftsDynamicBlueprint_vDev.*\.as:|Rules partially failed initialization|Script .* has errors|AIBGYMI\|ABORT\|run=' + [regex]::Escape($RunId)
    $arguments = @(
        $tcprSend,
        '--config', $rootConfig,
        '--connect-timeout-seconds', '45',
        '--stability-seconds', '3',
        '--delay-ms', '250',
        '--transcript', $TranscriptPath,
        '--command', 'getRules().SetCurrentState(GAME)',
        '--command', "getRules().set_u8(`"aib infrastructure team`", $Team)",
        '--command', "getRules().set_string(`"aib infrastructure variant`", `"$Variant`")",
        '--command', "getRules().set_string(`"aib infrastructure run id`", `"$RunId`")",
        '--command', 'getRules().set_u32("aib infrastructure readiness deadline", 0)',
        '--command', 'getRules().set_bool("aib infrastructure stop requested", false)',
        '--command', 'getRules().set_bool("aib infrastructure request", true)',
        '--command', "tcpr(`"AIBGYMI|ARMED|run=$RunId`")",
        '--listen-seconds', '150',
        '--expect', $expect,
        '--fail', $fail
    )
    & python @arguments
    if ($LASTEXITCODE -ne 0) { throw "tcpr_send.py failed with exit code $LASTEXITCODE." }

    $resultPattern = '^\[AIBGYMI\](?=.*\bstatus=result\b)(?=.*\brun=' + [regex]::Escape($RunId) + '\b)'
    $results = @(Select-String -LiteralPath $TranscriptPath -Pattern $resultPattern)
    if ($results.Count -lt 1) { throw 'The TCPR transcript has no complete infrastructure result row.' }
    Write-Host "AIBGYM_INFRASTRUCTURE_RESULT run=$RunId transcript=$TranscriptPath result_rows=$($results.Count)"
    $results[0].Line
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
    Write-Host 'KAG infrastructure process stopped; required CTF handoff restored.'
}

if ($null -ne $runFailure) { throw $runFailure }
