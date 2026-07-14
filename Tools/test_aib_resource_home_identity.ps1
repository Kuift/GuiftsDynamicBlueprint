$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$common = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBHomeResourceCommon.as') -Raw
$types = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBStrategicTypes.as') -Raw
$world = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBWorldModel.as') -Raw
$jobs = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBStrategicJobs.as') -Raw
$brain = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as') -Raw
$scenarios = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBTestScenarios.as') -Raw

foreach ($needle in @(
    'const string AIBR_ASSIGNED_HOME_KEY = "aib strategy resource home";',
    'CBlob@ AIBR_GetAssignedResourceHome(CBlob@ builder)',
    '!builder.get_bool("aib strategy assigned")',
    'AIBR_IsFriendlyResourceHome(builder, home)'
)) {
    if (!$common.Contains($needle)) { throw "Assigned resource-home contract is incomplete: $needle" }
}
if (!$types.Contains('u16 resourceHomeID;') -or
    !$world.Contains('world.resourceHomeID = resourceHome is null ? 0 : resourceHome.getNetworkID();')) {
    throw 'World observation does not preserve the selected resource-home identity'
}
foreach ($needle in @(
    'void AIBS_SetBuilderResourceHome(CBlob@ builder, const u16 homeID)',
    'u16 AIBS_WorldResourceHomeID(AIBWorldState@ world)',
    'AIBS_SetBuilderResourceHome(teamBuilders[i], resourceHomeID);',
    'AIBM_StopDirectorControl(builder);'
)) {
    if (!$jobs.Contains($needle)) { throw "Director assignment does not own resource-home identity: $needle" }
}
$getHome = [regex]::Match($brain, 'CBlob@ AIB_GetTeamHome[\s\S]*?\n\}').Value
if (!$getHome.Contains('CBlob@ assignedHome = AIBR_GetAssignedResourceHome(blob);') -or
    !$getHome.Contains('if (assignedHome !is null) return assignedHome;')) {
    throw 'Production builders do not prefer the director-selected resource home'
}
if ($getHome.IndexOf('assignedHome') -gt $getHome.IndexOf('AIB_GetNearestTeamBlob(blob, "tent")')) {
    throw 'Nearest-home fallback still overrides the director-selected home'
}
foreach ($needle in @(
    'CBlob@ secondaryHome = AIBT_SpawnTentTeam(300, 5);',
    'CBlob@ stockRunner = AIBT_Spawn("aibuilder", 5, AIBT_Pos(302, AIBT_GROUND_Y - 2));',
    'stockWorld.resourceHomeID == stockHome.getNetworkID()',
    'stockRunner.get_netid(AIBR_ASSIGNED_HOME_KEY) == stockHome.getNetworkID()',
    'assigned_resource_home_pinned=true nearer_secondary_ignored=true'
)) {
    if (!$scenarios.Contains($needle)) { throw "Runtime-ready multi-home fixture is incomplete: $needle" }
}

$strategicX = 408
$homes = @(
    [pscustomobject]@{ Id=31; X=410; Kind='tent' },
    [pscustomobject]@{ Id=32; X=300; Kind='tent' }
)
$selected = $homes | Sort-Object @{ Expression={ [math]::Abs($_.X - $strategicX) } }, Id | Select-Object -First 1
$runnerX = 302
$nearestToRunner = $homes | Sort-Object @{ Expression={ [math]::Abs($_.X - $runnerX) } }, Id | Select-Object -First 1
if ($selected.Id -ne 31 -or $nearestToRunner.Id -ne 32 -or $selected.Id -eq $nearestToRunner.Id) {
    throw 'Multi-home mirror does not reproduce the director/executor anchor disagreement'
}

Write-Output 'AIB authoritative resource-home identity contract passed'
