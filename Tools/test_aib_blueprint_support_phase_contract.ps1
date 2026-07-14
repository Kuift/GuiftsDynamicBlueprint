$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$brain = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as') -Raw

$nearestStart = $brain.IndexOf('Vec2f AIB_GetNearestBlueprintBuildTile(')
$waitStart = $brain.IndexOf('string AIB_GetBlueprintWaitStatus(', $nearestStart)
if ($nearestStart -lt 0 -or $waitStart -le $nearestStart) {
    throw 'Blueprint selection function could not be isolated'
}
$nearest = $brain.Substring($nearestStart, $waitStart - $nearestStart)
$phaseGate = $nearest.IndexOf('AIBP_TaskAvailableForBuilder(team, u16(x), u16(y), blob.getNetworkID())')
$supportLookup = $nearest.IndexOf('AIB_GetNeededSupportTileFor(tile, block)', $phaseGate)
$generatedReservation = $nearest.IndexOf('AIBP_TaskAvailableForBuilder(team, u16(targetSpace.x), u16(targetSpace.y), blob.getNetworkID())', $supportLookup)
if ($phaseGate -lt 0 -or $supportLookup -le $phaseGate -or $generatedReservation -le $supportLookup) {
    throw 'Generated support work is not gated by its owning explicit task before loose-task reservation'
}
if (!$nearest.Contains('AIB_IsInvalidBlueprintSupportTile(support)')) {
    throw 'Blueprint selection does not reject an unanchored generated support chain'
}

$supportStart = $brain.IndexOf('Vec2f AIB_GetNeededSupportTileFor(')
$materialStart = $brain.IndexOf('u16 AIB_GetBlueprintSupportBackwall(', $supportStart)
if ($supportStart -lt 0 -or $materialStart -le $supportStart) {
    throw 'Generated support resolver could not be isolated'
}
$support = $brain.Substring($supportStart, $materialStart - $supportStart)
foreach ($needle in @(
    'return scan;',
    'return AIB_InvalidBlueprintSupportTile();',
    'return crossedGap ? AIB_InvalidBlueprintSupportTile() : Vec2f_zero;'
)) {
    if (!$support.Contains($needle)) { throw "Generated support resolver is missing bounded first-legal-cell behavior: $needle" }
}
if ($support.Contains('lowestMissing')) {
    throw 'Generated support resolver can still overwrite a legal attachment with a deeper/bottom-row target'
}

foreach ($needle in @(
    'if (!AIB_IsInsideMap(AIB_TileCenter(tile))) return false;',
    'if (map.hasSupportAtPos(AIB_TileCenter(tile))) return true;',
    'Vec2f AIB_InvalidBlueprintSupportTile()',
    'return Vec2f(-8.0f, -8.0f);',
    'AIB_LogEvent("ai", "blueprint_target"'
)) {
    if (!$brain.Contains($needle)) { throw "Blueprint support phase/bounds telemetry contract is missing: $needle" }
}

Write-Output 'AIB blueprint support phase/bounds contract passed'
