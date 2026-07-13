$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$common = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBActionBoundaryCommon.as') -Raw
$transport = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBPlayerActionLog.as') -Raw
$blueprint = Get-Content -LiteralPath (Join-Path $root 'Scripts\BlueprintData.as') -Raw
$network = Get-Content -LiteralPath (Join-Path $root 'Scripts\BlueprintNetwork.as') -Raw
$renderer = Get-Content -LiteralPath (Join-Path $root 'Scripts\CustomRenderer.as') -Raw
$shop = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Industry\CTFShops\AIBuilderShop\AIBuilderShop.as') -Raw
$parser = Get-Content -LiteralPath (Join-Path $root 'Tools\parse_aib_player_actions.ps1') -Raw
$summarizer = Get-Content -LiteralPath (Join-Path $root 'Tools\summarize_aib_player_episodes.ps1') -Raw

foreach ($needle in @(
    'const uint AIB_ACTION_BOUNDARY_FIELDS = 10;',
    'const uint AIB_ACTION_BOUNDARY_MAX_RECORDS = 256;',
    'queue.push_back(getGameTime());',
    'rules.get_bool("aib player action log enabled")',
    'human_blueprint_delta = 1',
    'plan_publish',
    'task_reserve',
    'task_complete',
    'task_damage'
)) {
    if (!$common.Contains($needle)) { throw "Boundary queue contract is missing: $needle" }
}
if ($common -match 'addCommandID|SendCommand|\bprint\s*\(') { throw 'Boundary producers must not add commands or print per-event strings' }

foreach ($needle in @(
    'const u8 AIB_ACTION_SCHEMA_VERSION = 3;',
    'void AIB_ActionDrainBoundaries',
    'AIB_ActionRecordHeader(9)',
    'AIB_ActionRecordHeader(10)',
    'AIB_ActionU32(queue[i]);',
    'AIB_ActionFlush(rules, "boundary_size")',
    'AIB_ActionClearBoundaryQueue(rules);'
)) {
    if (!$transport.Contains($needle)) { throw "Boundary transport contract is missing: $needle" }
}

foreach ($needle in @(
    'AIBActionBoundary::plan_publish',
    'AIBActionBoundary::plan_archive',
    'AIBActionBoundary::task_reserve',
    'AIBActionBoundary::task_complete',
    'AIBActionBoundary::task_damage'
)) {
    if (!$blueprint.Contains($needle)) { throw "Production plan/task boundary is missing: $needle" }
}
if ($blueprint -notmatch 'if \(newClaim\)\s*\{[\s\S]*?AIBActionBoundary::task_reserve') { throw 'Reservation boundaries must be ownership-change-only' }

foreach ($needle in @('AIBActionBoundary::human_blueprint_delta','AIBActionBoundary::human_blueprint_prefab','AIBActionBoundary::human_blueprint_clear')) {
    if (!$network.Contains($needle)) { throw "Accepted human blueprint boundary is missing: $needle" }
}
foreach ($needle in @('AIBActionBoundary::director_mode','AIBActionBoundary::overseer_order')) {
    if (!$renderer.Contains($needle)) { throw "Accepted player director boundary is missing: $needle" }
}
if ([regex]::Matches($shop, 'AIBActionBoundary::purchase').Count -ne 2 -or !$shop.Contains('AIBActionPurchase::autobuilder_speed')) {
    throw 'Director workshop purchase boundaries must cover deployment and flight upgrades'
}

foreach ($needle in @("9 {","`$r.action='boundary'","`$r.event_tick=Read-U32","task_complete","actor_kind_code")) {
    if (!$parser.Contains($needle)) { throw "Schema-v3 parser support is missing: $needle" }
}
foreach ($needle in @('authoritative_boundaries','blueprint_edits','overseer_orders','director_mode_changes','purchases','purchase_value')) {
    if (!$summarizer.Contains($needle)) { throw "Episode boundary aggregation is missing: $needle" }
}
if (!$summarizer.Contains('boundary_records_dropped') -or !(Get-Content -LiteralPath (Join-Path $root 'Tools\compare_aib_task_episodes.ps1') -Raw).Contains('incomplete telemetry')) {
    throw 'Boundary loss must propagate to episodes and reject comparison cohorts'
}

Write-Output 'AIB authoritative action-boundary contract passed'
