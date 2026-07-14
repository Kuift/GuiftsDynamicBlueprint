$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$brain = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as') -Raw
$planner = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBPlacementPlanner.as') -Raw

$conflictStart = $brain.IndexOf('bool AIB_BaseWorkshopConflictsWithBlueprint(')
$approachStart = $brain.IndexOf('u8 AIB_CountBaseWorkshopApproaches(', $conflictStart)
if ($conflictStart -lt 0 -or $approachStart -le $conflictStart) {
    throw 'Base-workshop blueprint conflict function could not be isolated'
}
$conflict = $brain.Substring($conflictStart, $approachStart - $conflictStart)
foreach ($needle in @(
    'AIBP_GetLayerGrid(team, AIBP_Layer::human, @human);',
    'AIBP_GetLayerGrid(team, AIBP_Layer::ai_desired, @desired);',
    'human[index] != 0',
    'desired[index] != 0',
    'AIB_GetBaseWorkshopBounds(pos, siteMin, siteMax);',
    'const f32 tileRadius = map.tilesize * 0.5f;',
    'center.x > siteMin.x - tileRadius',
    'center.y > siteMin.y - tileRadius'
)) {
    if (!$conflict.Contains($needle)) { throw "Workshop siting does not protect blueprint work: $needle" }
}

$validateStart = $brain.IndexOf('bool AIB_CanBuildBaseWorkshopAt(Vec2f pos, CBlob@ home, CBlob@[]@ siteBlobs)')
$storeStart = $brain.IndexOf('bool AIB_StoreResourcesInBaseCrates(', $validateStart)
if ($validateStart -lt 0 -or $storeStart -le $validateStart) {
    throw 'Base-workshop site validator could not be isolated'
}
$validate = $brain.Substring($validateStart, $storeStart - $validateStart)
if (!$validate.Contains('AIB_BaseWorkshopConflictsWithBlueprint(pos, u8(home.getTeamNum()))')) {
    throw 'Workshop site validation can still spawn inside a live team blueprint'
}
if ($validate.IndexOf('AIB_BaseWorkshopConflictsWithBlueprint') -gt $validate.IndexOf('map.isTileSolid')) {
    throw 'Blueprint conflict is not rejected at the shared pre-spawn site boundary'
}

$protectedStart = $planner.IndexOf('bool AIBS_OverlapsProtectedBlob(')
$costStart = $planner.IndexOf('void AIBS_CandidateCosts(', $protectedStart)
if ($protectedStart -lt 0 -or $costStart -le $protectedStart) {
    throw 'Planner protected-building check could not be isolated'
}
$protected = $planner.Substring($protectedStart, $costStart - $protectedStart)
foreach ($needle in @(
    'name == "buildershop" && blob.getTeamNum() == team && blob.hasTag("aibuilder built storage shop")',
    'shape.getBoundingRect(boundsMin, boundsMax);',
    'center.x > boundsMin.x - tileRadius',
    'center.y > boundsMin.y - tileRadius',
    'continue;'
)) {
    if (!$protected.Contains($needle)) { throw "Planner cannot distinguish adjacent storage from overlap: $needle" }
}
if (!$protected.Contains('name == "flag" || name == "tent" || name == "hall" || name == "buildershop"')) {
    throw 'Ordinary buildings no longer retain the broad protected radius'
}

Write-Output 'AIB storage workshop/live-plan conflict contract passed'
