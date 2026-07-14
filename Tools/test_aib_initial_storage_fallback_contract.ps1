$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$brain = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as') -Raw

$fallbackStart = $brain.IndexOf('bool AIB_DropInitialResourcesAtHome(')
$storeStart = $brain.IndexOf('bool AIB_StoreResourcesInBaseCrates(', $fallbackStart)
$shopStart = $brain.IndexOf('CBlob@ AIB_GetBestBaseBuilderShop(', $storeStart)
if ($fallbackStart -lt 0 -or $storeStart -le $fallbackStart -or $shopStart -le $storeStart) {
    throw 'Base storage function could not be isolated'
}
$fallback = $brain.Substring($fallbackStart, $storeStart - $fallbackStart)
$store = $brain.Substring($storeStart, $shopStart - $storeStart)
foreach ($needle in @(
    'Vec2f storage = AIB_GetBaseStoragePoint(home);',
    'AIB_DropAllResourcesAtPosition(blob, storage);',
    'if (AIB_HasAnyResource(blob)) return false;',
    '"store_resources_loose"',
    'reason=no_initial_crate'
)) {
    if (!$fallback.Contains($needle)) { throw "Initial no-crate delivery fallback is missing: $needle" }
}
if (!$store.Contains('const bool hasBaseCrate = AIB_CountBaseResourceCrates(home) > 0;')) {
    throw 'Storage path does not distinguish the initial base from full-crate overflow'
}
if (($store | Select-String -Pattern 'if \(!hasBaseCrate\) return AIB_DropInitialResourcesAtHome\(blob, home\);' -AllMatches).Matches.Count -ne 2) {
    throw 'Both missing-shop and failed-purchase initial storage paths must deliver safely'
}

$stoneStart = $brain.IndexOf('bool AIB_IsBaseStoneSource(')
$quarryStart = $brain.IndexOf('CBlob@ AIB_GetBestBaseQuarry(', $stoneStart)
if ($stoneStart -lt 0 -or $quarryStart -le $stoneStart) {
    throw 'Base stone source filter could not be isolated'
}
$stone = $brain.Substring($stoneStart, $quarryStart - $stoneStart)
$delivered = $stone.IndexOf('stone.hasTag("aibuilder delivered resource")')
$genericHome = $stone.IndexOf('AIB_GetHomeDropPoint(home)')
if ($delivered -lt 0 -or $genericHome -lt 0 -or $delivered -gt $genericHome) {
    throw 'Delivered loose stone can still be relabeled as a quarry/base source'
}

$scenarios = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBTestScenarios.as') -Raw
if (!$scenarios.Contains('full_crate_creates_grounded_overflow_storage')) {
    throw 'Initial fallback is not paired with the existing full-crate overflow contract'
}

Write-Output 'AIB initial no-crate delivery fallback contract passed'
