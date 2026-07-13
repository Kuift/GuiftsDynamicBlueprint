$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBWorldFingerprint.as') -Raw
$chat = Get-Content -LiteralPath (Join-Path $root 'Rules\CommonScripts\ChatCommands.as') -Raw
$wave = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBStrategyWaveHarness.as') -Raw

foreach ($needle in @(
    'string AIBWF_CaptureWorldManifest',
    'u32 AIBWF_NoBuildHash',
    'map.getSectorAtPosition(center, "no build")',
    'u32 AIBWF_BlobManifest',
    'blob.isInInventory()',
    'u32 AIBWF_InventoryHash',
    'entries.sortAsc()',
    'blob.getHealth()',
    'blob.getQuantity()',
    'blob.get_u8("grown_times")',
    'blob.get_u8("ai builder job")',
    'blob.get_u8("ai builder state")',
    'u32 AIBWF_StrategyHash',
    'rules.get_u16("barrier_x1")',
    'rules.get_u16("barrier_x2")',
    'AIBWF_LayerHash(team, AIBP_Layer::human)',
    'AIBWF_LayerHash(team, AIBP_Layer::ai_desired)',
    'AIBWF_LayerHash(team, AIBP_Layer::ai_work)',
    'AIBWF_TaskHash(team)',
    'reserved[i] != 0 ? 1 : 0',
    'return "w1-"'
)) {
    if (!$manifest.Contains($needle)) { throw "World manifest is missing contract source: $needle" }
}

foreach ($forbidden in @('getUsername', 'getNetworkID()', 'getGameTime()')) {
    if ($manifest.Contains($forbidden)) { throw "World manifest contains unstable/private identity source: $forbidden" }
}

if ($chat -notmatch 'const u16 fixtureVersion = 3;' -or
    $chat -notmatch 'AIBWF_CaptureWorldManifest\(rules, map, terrainHash, solidTiles, noBuildHash, noBuildTiles,') {
    throw 'Wave arm state does not use the shared v3 world manifest'
}
if ($wave -notmatch 'AIBWF_CaptureWorldManifest\(rules, map, terrainHash, solidTiles, noBuildHash, noBuildTiles,') {
    throw 'Measurement state does not use the same shared world manifest'
}

foreach ($field in @(
    'initial_no_build_hash',
    'initial_no_build_tiles',
    'initial_manifest_blob_count',
    'initial_manifest_blob_hash',
    'initial_manifest_inventory_hash',
    'initial_manifest_strategy_hash',
    'measurement_terrain_hash',
    'measurement_no_build_hash',
    'measurement_blob_hash',
    'measurement_inventory_hash',
    'measurement_strategy_hash'
)) {
    if (!$wave.Contains('" ' + $field + '="')) { throw "Wave evidence omits world-manifest field: $field" }
}

Write-Output 'AIB shared world manifest contract passed'
