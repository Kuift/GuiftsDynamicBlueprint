$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$brain = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as') -Raw

foreach ($constant in @(
    'const u32 AIB_LOG_NO_PROGRESS_TICKS = 10 * 30;',
    'const u32 AIB_LOG_RETRY_COOLDOWN = 30 * 30;',
    'const f32 AIB_LOG_DISTANCE_PROGRESS = 8.0f;'
)) {
    if (!$brain.Contains($constant)) { throw "Log watchdog timing contract is missing: $constant" }
}

$findStart = $brain.IndexOf('void AIB_FindLog(')
$chopStart = $brain.IndexOf('void AIB_ChopLog(', $findStart)
$woodStart = $brain.IndexOf('void AIB_FindWood(', $chopStart)
if ($findStart -lt 0 -or $chopStart -le $findStart -or $woodStart -le $chopStart) {
    throw 'Log acquisition/chopping functions could not be isolated'
}
$find = $brain.Substring($findStart, $chopStart - $findStart)
$chop = $brain.Substring($chopStart, $woodStart - $chopStart)
if (!$find.Contains('AIB_BeginLogProgress(blob, log);')) {
    throw 'Log acquisition does not initialize the progress watchdog'
}
if (!$chop.Contains('if (AIB_LogProgressExpired(brain, blob, log, distance)) return;')) {
    throw 'Log chopping does not enforce the progress watchdog'
}

$nearestStart = $brain.IndexOf('CBlob@ AIB_GetNearestLog(')
$nearestEnd = $brain.IndexOf('CBlob@ AIB_GetNearestTeamHall(', $nearestStart)
if ($nearestStart -lt 0 -or $nearestEnd -le $nearestStart) {
    throw 'Nearest-log selection could not be isolated'
}
$nearest = $brain.Substring($nearestStart, $nearestEnd - $nearestStart)
if (!$nearest.Contains('AIB_IsLogRetryBlocked(blob, candidate)')) {
    throw 'Nearest-log selection can immediately reacquire an abandoned target'
}
if (!$nearest.Contains('AIB_IsAccessibleResource(blob, candidate)')) {
    throw 'Log cooldown filtering bypasses barrier/threat accessibility'
}

$watchStart = $brain.IndexOf('bool AIB_LogProgressExpired(')
$watchEnd = $brain.IndexOf('void AIB_BeginTreeProgress(', $watchStart)
if ($watchStart -lt 0 -or $watchEnd -le $watchStart) {
    throw 'Log watchdog implementation could not be isolated'
}
$watch = $brain.Substring($watchStart, $watchEnd - $watchStart)
foreach ($needle in @(
    'distance + AIB_LOG_DISTANCE_PROGRESS < previousDistance',
    'health + 0.001f < previousHealth',
    'getGameTime() - blob.get_u32("ai builder log progress tick") <= AIB_LOG_NO_PROGRESS_TICKS',
    'getGameTime() + AIB_LOG_RETRY_COOLDOWN',
    '"target_abandon"',
    'AIB_SetState(blob, AIBuilderState::find_log, "log target made no progress")'
)) {
    if (!$watch.Contains($needle)) { throw "Log watchdog is incomplete: $needle" }
}
if ($watch.Contains('AIBuilderState::return_wood')) {
    throw 'Log abandonment skips other reachable logs instead of returning through find_log'
}

Write-Output 'AIB unreachable-log watchdog contract passed'
