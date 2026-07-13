$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$brain = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as') -Raw
$scenarios = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBTestScenarios.as') -Raw
$recoveryStart = $brain.IndexOf('bool AIB_TryRecoverStoneCorner(')
$recoveryEnd = $brain.IndexOf('s32 AIB_GetStoneCornerEscapeDirection(', $recoveryStart)
if ($recoveryStart -lt 0 -or $recoveryEnd -le $recoveryStart) {
    throw 'Corner recovery function could not be isolated'
}
$recovery = $brain.Substring($recoveryStart, $recoveryEnd - $recoveryStart)

if ($brain -notmatch 'const u8 AIB_STONE_CORNER_ESCAPE_TICKS = 36;' -or
    $brain -notmatch 'const u8 AIB_STONE_CORNER_ESCAPE_COOLDOWN = 90;') {
    throw 'Corner recovery no longer owns movement for the audited 36/90 tick windows'
}
if ($brain -notmatch 'if \(AIB_TryRecoverStoneCorner\(this, blob, activeState\)\)\s*\{\s*return;') {
    throw 'Corner recovery does not preempt the active state movement controller'
}
if ($brain -notmatch 'if \(until > now\)\s*\{\s*AIB_DriveStoneCornerEscape\(blob\);\s*return true;') {
    throw 'Active corner recovery can fall through into generic pathing'
}
if ($brain -notmatch 'const bool leftOverhang = ceiling && upperLeft && !lowerLeft;' -or
    $brain -notmatch 'const bool rightOverhang = ceiling && upperRight && !lowerRight;') {
    throw 'Corner recovery is not gated by mirrored asymmetric overhang geometry'
}
if ($brain -notmatch 'blob\.setKeyPressed\(key_up, false\);' -or
    $brain -notmatch 'blob\.setKeyPressed\(key_action2, false\);') {
    throw 'Corner escape no longer suppresses jump/ladder input while driving away'
}
if ($recovery -match 'blob\.get_u8\("ai builder job"\) != AIB_JOB_STONE') {
    throw 'Corner recovery has regressed to stone jobs only and cannot protect delivery travel'
}

if ($scenarios -notmatch 'stone_corner_escape_from_mirrored_upper_overhangs') {
    throw 'Mirrored corner fixture is not registered'
}
if ($scenarios -notmatch 'aibt left corner cycle complete' -or
    $scenarios -notmatch 'aibt right corner cycle complete') {
    throw 'Mirrored fixture does not require both complete escape cycles'
}
if ($scenarios -notmatch 'escape cooldown"\) > now' -or
    $scenarios -notmatch 'start x"\) \+ 8\.0f' -or
    $scenarios -notmatch 'start x"\) - 8\.0f') {
    throw 'Mirrored fixture does not prove cooldown entry and one-tile displacement'
}
if ($scenarios -notmatch 'full_escape_cycle=true cooldown_latched=true' -or
    $scenarios -notmatch 'elapsed > 150') {
    throw 'Mirrored fixture can still pass before the longer recovery cycle is observed'
}

Write-Output 'AIB mirrored corner recovery contract passed'
