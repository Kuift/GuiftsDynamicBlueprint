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

    [ValidateSet(1,4)]
    [int]$BuilderCount = 1,

    [ValidateSet('wood','stone','mixed')]
    [string]$Order = 'wood',

    [ValidateRange(300,5400)]
    [int]$DurationTicks = 5400,

    [string]$TranscriptPath = '',

    [switch]$CompilerForwarding,

    [switch]$EventLog
)

$ErrorActionPreference = 'Stop'
if ($Order -eq 'mixed' -and $BuilderCount -ne 4) {
    throw 'The mixed resource order requires exactly four builders.'
}
if ($EventLog -and $Variant -ne 'diagnostic') {
    throw 'EventLog is diagnostic-only; comparable control/candidate episodes must run without it.'
}

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
    throw "Refusing to start a gym run while $($existing.Count) KAG process(es) already exist."
}

$ownedPid = 0
$runFailure = $null
try {
    Write-RootSettings ([bool]$CompilerForwarding)
    $process = Start-Process -FilePath $kagExe -WorkingDirectory $kagRoot `
        -ArgumentList @('noautoupdate','nolauncher','autostart',$autostart) -PassThru
    $ownedPid = $process.Id
    Write-Host "Started visible KAG Gym PID $ownedPid for $RunId"

    $listenSeconds = [int][math]::Ceiling($DurationTicks / 30.0) + 75
    $expect = 'AIBGYM\|RESULT\|run=' + [regex]::Escape($RunId)
    $fail = 'ERROR .*GuiftsDynamicBlueprint_vDev.*\.as:|Rules partially failed initialization|Script .* has errors|AIBGYM\|ABORT\|run=' + [regex]::Escape($RunId)
    $eventLogValue = $EventLog ? 'true' : 'false'
    $arguments = @(
        $tcprSend,
        '--config', $rootConfig,
        '--connect-timeout-seconds', '45',
        '--stability-seconds', '3',
        '--delay-ms', '250',
        '--transcript', $TranscriptPath,
        '--command', 'getRules().SetCurrentState(GAME)',
        '--command', "getRules().set_bool(`"aib event log enabled`", $eventLogValue)",
        '--command', "getRules().set_u8(`"aib gym team`", $Team)",
        '--command', "getRules().set_u8(`"aib gym builder count`", $BuilderCount)",
        '--command', "getRules().set_string(`"aib gym resource order`", `"$Order`")",
        '--command', "getRules().set_u32(`"aib gym duration ticks`", $DurationTicks)",
        '--command', "getRules().set_string(`"aib gym variant`", `"$Variant`")",
        '--command', "getRules().set_string(`"aib gym run id`", `"$RunId`")",
        '--command', 'getRules().set_bool("aib gym stop requested", false)',
        '--command', 'getRules().set_bool("aib gym request", true)',
        '--command', "tcpr(`"AIBGYM|ARMED|run=$RunId`")",
        '--listen-seconds', [string]$listenSeconds,
        '--expect', $expect,
        '--fail', $fail
    )
    & python @arguments
    if ($LASTEXITCODE -ne 0) { throw "tcpr_send.py failed with exit code $LASTEXITCODE." }

    $aggregatePattern = '^\[AIBGYMR\](?=.*\bstatus=result\b)(?=.*\brun=' + [regex]::Escape($RunId) + '\b)'
    $aggregate = @(Select-String -LiteralPath $TranscriptPath -Pattern $aggregatePattern)
    $workers = @(Select-String -LiteralPath $TranscriptPath -Pattern ('^\[AIBGYMB\].*\brun=' + [regex]::Escape($RunId) + '\b'))
    if ($aggregate.Count -lt 1) { throw 'The TCPR transcript has no complete aggregate schema-v4 result row.' }
    if ($workers.Count -lt $BuilderCount) { throw "The TCPR transcript has only $($workers.Count) worker rows; expected $BuilderCount." }
    Write-Host "AIBGYM_RESOURCE_RESULT run=$RunId transcript=$TranscriptPath aggregate_rows=$($aggregate.Count) worker_rows=$($workers.Count)"
    $aggregate[0].Line
} catch {
    $runFailure = $_
} finally {
    if ($ownedPid -ne 0) { Stop-OwnedKAG $ownedPid }
    # KAG can briefly remain visible in the process table under a replacement
    # process id while its localhost/client teardown completes. We began only
    # after proving the machine had no KAG process, so wait for that owned
    # process family to drain before deciding cleanup failed. Do not restore
    # configuration during this interval because the final exit can rewrite it.
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
    Write-Host 'KAG Gym process stopped; required CTF handoff restored.'
}

if ($null -ne $runFailure) { throw $runFailure }
