$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$templates = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBBlueprintTemplates.as') -Raw
$planner = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBPlacementPlanner.as') -Raw

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
