$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$brain = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as') -Raw
$manual = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBManualOrderCommon.as') -Raw
$scenarios = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBTestScenarios.as') -Raw

$tryStart = $brain.IndexOf('bool AIB_TryPlaceRecoveryLadder(')
$prepareStart = $brain.IndexOf('bool AIB_PrepareRecoveryLadderSupport(', $tryStart)
$probeStart = $brain.IndexOf('void AIB_RecordRecoveryPathProbe(', $prepareStart)
$canPlaceStart = $brain.IndexOf('bool AIB_CanPlaceRecoveryLadderAt(', $probeStart)
if ($tryStart -lt 0 -or $prepareStart -le $tryStart -or $probeStart -le $prepareStart -or $canPlaceStart -le $probeStart) {
    throw 'Recovery ladder support/probe functions could not be isolated'
}
$tryPlace = $brain.Substring($tryStart, $prepareStart - $tryStart)
$prepare = $brain.Substring($prepareStart, $probeStart - $prepareStart)
$probe = $brain.Substring($probeStart, $canPlaceStart - $probeStart)

$supportBranch = $tryPlace.IndexOf('if (needsBackwall)')
$prepareCall = $tryPlace.IndexOf('AIB_PrepareRecoveryLadderSupport(blob, tile, backwallChain);')
$spawn = $tryPlace.IndexOf('server_CreateBlob("ladder"')
if ($supportBranch -lt 0 -or $prepareCall -le $supportBranch -or $spawn -le $prepareCall) {
    throw 'Recovery support is not staged before ladder creation'
}
$between = $tryPlace.Substring($prepareCall, $spawn - $prepareCall)
if (!$between.Contains('return false;')) {
    throw 'Recovery support and ladder creation can still occur in the same simulation tick'
}
foreach ($needle in @(
    'const bool supportReadyBeforeSpawn = map.hasSupportAtPos(AIB_TileCenter(tile));',
    'ladder.set_bool("aibuilder recovery support ready before spawn", supportReadyBeforeSpawn);',
    'ladder.set_u32("aibuilder recovery support tick", supportTick);',
    'ladder.set_u8("aibuilder recovery support chain", supportChain);',
    'blob.set_bool(AIB_RECOVERY_PROBE_PENDING_KEY, true);'
)) {
    if (!$tryPlace.Contains($needle)) { throw "Recovery ladder creation evidence is missing: $needle" }
}

foreach ($needle in @(
    'if (!AIB_IsSupportBackwall(type)) missing.push_back(backwallChain[i]);',
    'if (missing.length == 0) return false;',
    'const u16 supportCost = missing.length * AIB_LADDER_BACKWALL_WOOD_COST;',
    'AIB_CountWood(blob) < AIB_LADDER_WOOD_COST + supportCost',
    'map.server_SetTile(missing[i], CMap::tile_wood_back);',
    'blob.set_u32(AIB_RECOVERY_SUPPORT_TICK_KEY, getGameTime());',
    '"place_ladder_support"'
)) {
    if (!$prepare.Contains($needle)) { throw "Recovery backwall preparation is incomplete: $needle" }
}
if ($prepare.Contains('backwallChain.length * AIB_LADDER_BACKWALL_WOOD_COST')) {
    throw 'Recovery support charges for existing backwalls instead of only new cells'
}

foreach ($needle in @(
    'AIB_RecordRecoveryPathProbe(blob, path, destination);',
    'getGameTime() <= blob.get_u32(AIB_RECOVERY_LADDER_TICK_KEY)',
    'const Vec2f mineable = AIB_GetMineablePathBlock(blob, path);',
    'const bool accepted = path.isPathing() && next != Vec2f_zero;',
    'ladder.set_bool("aibuilder recovery post path probe", true);',
    'ladder.set_bool("aibuilder recovery post path accepted", accepted);',
    '"ladder_path_probe"',
    'blob.set_bool(AIB_RECOVERY_PROBE_PENDING_KEY, false);'
)) {
    if (!$brain.Contains($needle) -and !$probe.Contains($needle)) { throw "Bounded post-ladder path evidence is missing: $needle" }
}

foreach ($needle in @(
    'builder.set_Vec2f("ai builder recovery support target", Vec2f_zero);',
    'builder.set_bool("ai builder recovery path probe pending", false);',
    'builder.set_netid("ai builder recovery path probe ladder", 0);'
)) {
    if (!$manual.Contains($needle)) { throw "Ownership/navigation cleanup leaves stale recovery evidence: $needle" }
}

foreach ($needle in @(
    'kag_path_builds_supported_ladder_chain',
    'CBlob@ AIBT_GetRecoveryLadderNear',
    'AIBT_recovery_plug_tiles.push_back(map.getTile(AIBT_Pos(x, y)).type);',
    'support_chain_before_ladder=true post_path_accepted=true crossed_preserved_plug=true',
    'ladder.get_u32("aibuilder recovery support tick") > 0',
    'ladder.get_u32("aibuilder recovery support tick") < ladder.get_u32("aibuilder recovery ladder tick")',
    'ladder.get_bool("aibuilder recovery post path accepted")',
    'reachedTargetSide && plugPreserved'
)) {
    if (!$scenarios.Contains($needle)) { throw "Focused recovery scenario remains outcome-weak: $needle" }
}
if ($scenarios.Contains('if (plugCleared || ladderBuilt || reachedTargetSide)')) {
    throw 'Focused recovery scenario can still pass on a partial side effect'
}

Write-Output 'AIB supported recovery ladder contract passed'
