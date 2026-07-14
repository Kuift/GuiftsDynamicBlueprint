$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$brain = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as') -Raw
$manual = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBManualOrderCommon.as') -Raw

$returnStart = $brain.IndexOf('void AIB_ReturnWood(')
$stoneStart = $brain.IndexOf('void AIB_FindStone(', $returnStart)
if ($returnStart -lt 0 -or $stoneStart -le $returnStart) {
    throw 'Resource return function could not be isolated'
}
$return = $brain.Substring($returnStart, $stoneStart - $returnStart)
$stored = $return.IndexOf('AIB_LogEvent("ai", "store_resources"')
$hold = $return.IndexOf('blob.set_u32(AIBM_RESOURCE_HANDOFF_UNTIL_KEY, getGameTime() + AIB_RESOURCE_HANDOFF_HOLD_TICKS);', $stored)
$clear = $return.IndexOf('AIBM_ClearNavigationIntent(blob);', $hold)
$stoneState = $return.IndexOf('AIB_SetState(blob, AIBuilderState::find_stone, "resources delivered");', $clear)
$stoneApply = $return.IndexOf('AIBM_TryApplyDeferredRoleAtSafeBoundary(blob)', $stoneState)
$woodState = $return.IndexOf('AIB_SetState(blob, AIBuilderState::find_tree, "wood delivered");', $stoneApply)
$woodApply = $return.IndexOf('AIBM_TryApplyDeferredRoleAtSafeBoundary(blob)', $woodState)
$quarry = $return.IndexOf('AIB_TryMaintainBaseQuarry(', $woodApply)
if ($stored -lt 0 -or $hold -le $stored -or $clear -le $hold -or $stoneState -le $clear -or $stoneApply -le $stoneState -or
    $woodState -le $stoneApply -or $woodApply -le $woodState -or $quarry -le $woodApply) {
    throw 'Delivery does not clear the completed episode and consume deferred roles before new resource work'
}

$tickStart = $brain.IndexOf('void onTick(CBrain@ this)')
$tickEnd = $brain.IndexOf('void AIB_TickAutoBuilder(', $tickStart)
$tick = $brain.Substring($tickStart, $tickEnd - $tickStart)
$deferred = $tick.IndexOf('AIBM_TryApplyDeferredRoleAtSafeBoundary(blob)')
$holdGate = $tick.IndexOf('AIB_ShouldHoldAtResourceHandoff(blob)', $deferred)
if ($deferred -lt 0 -or $holdGate -le $deferred) {
    throw 'Brain does not apply existing deferred work before holding the new delivery boundary'
}
foreach ($needle in @(
    'const u32 AIB_RESOURCE_HANDOFF_HOLD_TICKS = 31;',
    'bool AIB_ShouldHoldAtResourceHandoff(CBlob@ blob)',
    'getGameTime() >= until',
    'AIBM_IsAtStrategyHandoff(blob)',
    'Waiting for director role update'
)) {
    if (!$brain.Contains($needle)) { throw "Bounded post-delivery director hold is missing: $needle" }
}
foreach ($needle in @(
    'const string AIBM_RESOURCE_HANDOFF_UNTIL_KEY = "aib strategy resource handoff until";',
    'builder.set_u32(AIBM_RESOURCE_HANDOFF_UNTIL_KEY, 0);'
)) {
    if (!$manual.Contains($needle)) { throw "Role/manual ownership does not clear the delivery hold: $needle" }
}

foreach ($needle in @(
    'builder.set_netid("ai builder target", 0);',
    'builder.set_Vec2f("ai builder tile target", Vec2f_zero);',
    'builder.set_Vec2f("ai builder stone route corner", Vec2f_zero);'
)) {
    if (!$manual.Contains($needle)) { throw "Delivery navigation cleanup is incomplete: $needle" }
}
if (!$manual.Contains('!AIBM_IsAtStrategyHandoff(builder)')) {
    throw 'Deferred roles no longer retain the explicit safe-boundary predicate'
}

Write-Output 'AIB delivery/deferred-role handoff contract passed'
