$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$templates = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBBlueprintTemplates.as') -Raw
$planner = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBPlacementPlanner.as') -Raw
$common = Get-Content -LiteralPath (Join-Path $root 'Scripts\BlueprintCommon.as') -Raw
$data = Get-Content -LiteralPath (Join-Path $root 'Scripts\BlueprintData.as') -Raw
$brain = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as') -Raw

$towerStart = $templates.IndexOf('AIBPlanCandidate@ AIBS_FrontlineTowerTemplate(')
$perchStart = $templates.IndexOf('AIBPlanCandidate@ AIBS_ArcherPerchTemplate(', $towerStart)
if ($towerStart -lt 0 -or $perchStart -le $towerStart) {
    throw 'Frontline tower template could not be isolated'
}
$tower = $templates.Substring($towerStart, $perchStart - $towerStart)
foreach ($needle in @(
    'for (int y = 1; y <= 3; y++)',
    'AIBS_AddTask(c, anchorX - 1, groundY - y, AIBP_STONE_BACKWALL, AIBP_Phase::foundation);',
    'AIBS_AddTask(c, anchorX + 1, groundY - y, AIBP_STONE_BACKWALL, AIBP_Phase::foundation);',
    'AIBS_AddTask(c, anchorX, groundY - 1, AIBP_STONE_BACKWALL, AIBP_Phase::foundation);'
)) {
    if (!$tower.Contains($needle)) { throw "Frontline tower does not retain the grounded seven-cell foundation: $needle" }
}
if ($tower.Contains('for (int y = 1; y <= 6; y++)')) {
    throw 'Frontline tower still creates foundation cells above future platform dependencies'
}
foreach ($needle in @(
    'AIBS_AddTask(c, anchorX - 2, groundY - 1, AIBP_EncodeBlock(AIBP_STONE_DOOR, 1), AIBP_Phase::closure);',
    'AIBS_AddTask(c, anchorX + 2, groundY - 1, AIBP_EncodeBlock(AIBP_STONE_DOOR, 1), AIBP_Phase::closure);'
)) {
    if (!$tower.Contains($needle)) { throw "Frontline tower does not defer doors until solid shell adjacency exists: $needle" }
}
if ($tower.Contains('AIBP_EncodeBlock(AIBP_STONE_DOOR, 1), AIBP_Phase::access')) {
    throw 'Frontline tower can still place a door before its durable shell support'
}
foreach ($needle in @(
    'for (int y = 2; y <= 5; y++) AIBS_AddTask(c, anchorX, groundY - y, AIBP_LADDER, AIBP_Phase::access);',
    'AIBPlanCandidate@ AIBS_FrontlineTowerTemplate(const int anchorX, const int groundY, const s8 enemyDirection = 1)',
    'AIBS_AddTask(c, anchorX + enemyDirection, groundY - 7, AIBP_STONE_BLOCK, AIBP_Phase::roof);',
    'AIBS_AddTask(c, anchorX + enemyDirection, groundY - 4, AIBP_PLATFORM, AIBP_Phase::access);'
)) {
    if (!$tower.Contains($needle)) { throw "Frontline tower does not preserve its bounded ladder chain and two-tile home hatch: $needle" }
}
if ($tower.Contains('for (int y = 2; y <= 6; y++)')) {
    throw 'Frontline tower still asks access phase to stabilize a five-ladder unsupported chain'
}
if ($tower.Contains('AIBS_AddTask(c, anchorX, groundY - 6, AIBP_LADDER')) {
    throw 'Frontline tower still creates an unsupported fifth ladder under a sealed roof'
}
if ($tower.Contains('AIBS_AddTask(c, anchorX - 1, groundY - 4, AIBP_PLATFORM') -or
    $tower.Contains('AIBS_AddTask(c, anchorX + 1, groundY - 4, AIBP_PLATFORM')) {
    throw 'Frontline tower still creates a runner-width-blocking symmetric platform pair'
}
if (!$common.Contains('shell = 2,') -or !$common.Contains('roof = 3,') -or !$common.Contains('closure = 4')) {
    throw 'Blueprint phases do not expose separate post-wall roof and final closure boundaries'
}
foreach ($needle in @(
    'AIBS_AddTask(c, anchorX + enemyDirection, groundY - 7, AIBP_STONE_BLOCK, AIBP_Phase::roof);',
    'for (int y = 2; y <= 7; y++)'
)) {
    if (!$tower.Contains($needle)) { throw "Frontline tower does not keep walls open until their dedicated roof phase: $needle" }
}
if ($tower.Contains('for (int x = -2; x <= 2; x++) AIBS_AddTask(c, anchorX + x, groundY - 7, AIBP_STONE_BLOCK, AIBP_Phase::shell);')) {
    throw 'Frontline tower can still seal its roof while an opposite wall remains pending'
}

$validateStart = $planner.IndexOf('bool AIBS_ValidateCandidate(')
$reachableGate = $planner.IndexOf('candidate.rejection = "unreachable_tasks"', $validateStart)
$routeGate = $planner.IndexOf('candidate.rejection = "friendly_route"', $validateStart)
if ($validateStart -lt 0 -or $reachableGate -le $validateStart -or $routeGate -le $reachableGate) {
    throw 'Candidate validation can still mask unreachable tasks as a friendly-route failure'
}

foreach ($needle in @(
    'bool AIBP_IsAIWorkTile(const u8 team, const u16 x, const u16 y)',
    'return index < work.length && work[index] != 0;'
)) {
    if (!$data.Contains($needle)) { throw "Director approach ownership helper is missing: $needle" }
}
$approachStart = $brain.IndexOf('Vec2f AIB_GetBlueprintBuildApproach(')
$clearanceStart = $brain.IndexOf('bool AIB_HasBuilderClearance(', $approachStart)
if ($approachStart -lt 0 -or $clearanceStart -le $approachStart) {
    throw 'Blueprint build-approach function could not be isolated'
}
$approach = $brain.Substring($approachStart, $clearanceStart - $approachStart)
foreach ($needle in @(
    'const f32 anchorWorldX = anchor.x * ts + ts * 0.5f;',
    'AIBP_IsAIWorkTile(team, tileX, tileY)',
    'Vec2f interior = center + Vec2f(inward * ts, 0.0f);',
    'AIBP_CurrentTaskPhase(team) == AIBP_Phase::closure',
    'CBlob@ home = AIB_GetTeamHome(blob);',
    'Vec2f hatchApproach = Vec2f(anchorWorldX + homeward * ts * 0.5f, center.y - 2.0f * ts);',
    'return hatchApproach;',
    'Vec2f elevatedInterior = interior - Vec2f(0.0f, 2.0f * ts);',
    'Vec2f elevatedAnchor = Vec2f(anchorWorldX, center.y - 2.0f * ts);',
    'if (blob.getPosition().y < center.y && (elevatedAnchor - center).Length() <= 32.0f &&',
    'if (blob.getPosition().y < center.y && AIB_HasBuilderClearance(elevatedInterior, blob.getTeamNum()))',
    'if (AIB_HasBuilderClearance(interior, blob.getTeamNum())) return interior;'
)) {
    if (!$approach.Contains($needle)) { throw "Director shell approach does not prefer the clear plan interior: $needle" }
}
if (!$templates.Contains('AIBS_FrontlineTowerTemplate(x, AIBS_SurfaceAt(x), world.enemyDirection)')) {
    throw 'Frontline tower generation does not orient the two-tile hatch toward team home'
}

$clearPositionStart = $brain.IndexOf('bool AIB_ClearBlueprintPlacementPosition(')
$goToStart = $brain.IndexOf('void AIB_GoTo(', $clearPositionStart)
if ($clearPositionStart -lt 0 -or $goToStart -le $clearPositionStart) {
    throw 'Blueprint collision-clearance function could not be isolated'
}
$clearPosition = $brain.Substring($clearPositionStart, $goToStart - $clearPositionStart)
foreach ($needle in @(
    'const bool primaryClear = AIB_HasBuilderClearance',
    'const bool alternateClear = AIB_HasBuilderClearance',
    'if (!primaryClear && !alternateClear)',
    'f32 vertical = pos.y < center.y ? -1.0f : 1.0f;',
    'blob.setKeyPressed(vertical < 0.0f ? key_up : key_down, true);'
)) {
    if (!$clearPosition.Contains($needle)) { throw "Blueprint overlap recovery cannot leave a horizontally sealed tower cell: $needle" }
}

$buildStart = $brain.IndexOf('void AIB_BuildBlueprintBlock(')
$clearSiteStart = $brain.IndexOf('bool AIB_ClearBlueprintPlacementPosition(', $buildStart)
if ($buildStart -lt 0 -or $clearSiteStart -le $buildStart) {
    throw 'Blueprint build executor could not be isolated'
}
$build = $brain.Substring($buildStart, $clearSiteStart - $buildStart)
foreach ($needle in @(
    'const Vec2f delta = approach - blob.getPosition();',
    '(blob.isOnLadder() || AIB_HasBlueprintLadderNear(blob))',
    'AIB_EndBrainPath(blob);',
    'if (Maths::Abs(delta.x) > 1.5f)',
    'blob.setKeyPressed(delta.x < 0.0f ? key_left : key_right, true);',
    'blob.setKeyPressed(key_down, true);'
)) {
    if (!$build.Contains($needle)) { throw "Blueprint executor cannot own a short downward ladder approach: $needle" }
}

foreach ($needle in @(
    'bool AIB_HasBlueprintLadderNear(CBlob@ blob)',
    'const Vec2f space = map.getTileSpacePosition(blob.getPosition());',
    'for (s32 yOffset = -1; yOffset <= 1; yOffset++)',
    'AIB_GetBlueprintLadderAt(Vec2f(tileX * tilesize, y * tilesize))'
)) {
    if (!$brain.Contains($needle)) { throw "Blueprint ladder descent lacks placed-ladder proximity detection: $needle" }
}

$touchStart = $planner.IndexOf('bool AIBS_TaskTouchesSupportedPlan(')
$mapSupportStart = $planner.IndexOf('bool AIBS_MapProvidesImmediateSupport(', $touchStart)
if ($touchStart -lt 0 -or $mapSupportStart -le $touchStart) {
    throw 'Planner dependency-support traversal could not be isolated'
}
$touch = $planner.Substring($touchStart, $mapSupportStart - $touchStart)
if (!$touch.Contains('if (other.phase > task.phase) continue;')) {
    throw 'Planner can still use a future-phase task to support current work'
}
if ($touch.Contains('!AIBS_CandidateBackwallBlock(task.block)')) {
    throw 'Backwalls still bypass the planner phase-order dependency rule'
}

Write-Output 'AIB acyclic blueprint phase-dependency contract passed'
