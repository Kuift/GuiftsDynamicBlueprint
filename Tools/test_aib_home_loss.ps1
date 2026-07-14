$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$types = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBStrategicTypes.as') -Raw
$world = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBWorldModel.as') -Raw
$jobs = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBStrategicJobs.as') -Raw
$manual = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBManualOrderCommon.as') -Raw
$director = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBStrategicDirector.as') -Raw
$boundaries = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBActionBoundaryCommon.as') -Raw
$scenarios = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBTestScenarios.as') -Raw

foreach ($needle in @('Vec2f home;', 'Vec2f resourceHome;')) {
    if (!$types.Contains($needle)) { throw "World-state home distinction is missing: $needle" }
}
foreach ($needle in @(
    'CBlob@ AIBS_TeamResourceHomeBlob(const u8 team, Vec2f from)',
    'CBlob@ tent = AIBS_NearestTeamBlob(team, "tent", from);',
    'return AIBS_NearestTeamBlob(team, "hall", from);',
    'AIBS_TeamResourceHomeBlob(team, world.home)',
    'world.resourceHome = resourceHome is null ? Vec2f_zero : resourceHome.getPosition();'
)) {
    if (!$world.Contains($needle)) { throw "World model does not distinguish strategic and resource homes: $needle" }
}

$bootstrap = [regex]::Match($jobs, 'bool AIBS_TryBootstrapBuilder[\s\S]*?\n\}').Value
$assign = [regex]::Match($jobs, 'void AIBS_AssignBuilders[\s\S]*?\n\}').Value
$stop = [regex]::Match($jobs, 'void AIBS_StopBuilderAssignment[\s\S]*?\n\}').Value
if (!$bootstrap -or !$assign -or !$stop) { throw 'Resource-home job lifecycle helpers are missing' }
if (!$bootstrap.Contains('world.home == Vec2f_zero || world.resourceHome == Vec2f_zero')) {
    throw 'Free runner provisioning must require both a strategic anchor and a tent/hall resource home'
}
foreach ($needle in @(
    'if (world.resourceHome == Vec2f_zero)',
    'AIBS_StopBuilderAssignment(world.team, builder);'
)) {
    if (!$assign.Contains($needle)) { throw "Runner suspension on resource-home loss is incomplete: $needle" }
}
$autoAssignAt = $assign.IndexOf('AIBS_SetBuilderJob(teamBuilders[i], AIBS_JOB_BLUEPRINT, AIBS_STATE_FIND_BLUEPRINT);')
$resourceGateAt = $assign.IndexOf('if (world.resourceHome == Vec2f_zero)')
if ($autoAssignAt -lt 0 -or $resourceGateAt -le $autoAssignAt) {
    throw 'Infinite-resource Autobuilders must remain eligible before ordinary runners are suspended'
}
if (!$stop.Contains('AIBM_StopDirectorControl(builder);')) {
    throw 'Suspended runner cleanup does not use the shared ownership boundary'
}
foreach ($needle in @(
    'AIBP_ReleaseBuilderReservation(u8(team), builder.getNetworkID());',
    'builder.set_bool("aib strategy assigned", false);',
    'builder.set_bool("ai builder job active", false);',
    'builder.set_u8("ai builder state", 0);'
)) {
    if (!$manual.Contains($needle)) { throw "Suspended runner cleanup is incomplete: $needle" }
}
foreach ($needle in @(
    'world.resourceHome == Vec2f_zero) return result;',
    'map.getTileSpacePosition(world.resourceHome);',
    'world.resourceHome == Vec2f_zero) return Vec2f_zero;'
)) {
    if (!$jobs.Contains($needle)) { throw "Bootstrap spawn search is not anchored to the operational tent/hall: $needle" }
}

$handler = [regex]::Match($director, 'void AIBS_HandleMissingHome[\s\S]*?\n\}').Value
$update = [regex]::Match($director, 'void AIBS_UpdateTeam[\s\S]*?\n\}').Value
if (!$handler -or !$update) { throw 'Director strategic-home lifecycle handler is missing' }
foreach ($needle in @(
    'AIBP_CancelCurrentPlan(team, "home_lost")',
    'rules.set_u32("aib strategy important event team " + int(team), getGameTime());',
    'AIBS_StopAssignedBuilders(team);'
)) {
    if (!$handler.Contains($needle)) { throw "Strategic-home loss lifecycle is incomplete: $needle" }
}
if (!$update.Contains('if (world.home == Vec2f_zero) { AIBS_HandleMissingHome(rules, team); return; }') -or
    $update.IndexOf('AIBS_HandleMissingHome(rules, team)') -gt $update.IndexOf('AIBS_SelectCandidate(world)')) {
    throw 'Strategic-home loss must close the active plan before selection or assignment'
}
if (!$boundaries.Contains('if (reason == "home_lost") return 8;')) {
    throw 'Strategic-home closure needs a stable telemetry reason code'
}
foreach ($needle in @(
    'BlueprintPlan@ resourcePlan = AIBT_NewStrategicPlan(3, "resource_home_loss_guard");',
    'BlueprintPlan@ strategicPlan = AIBT_NewStrategicPlan(4, "strategic_home_loss_guard");',
    'resourceWorld.home != Vec2f_zero && resourceWorld.resourceHome == Vec2f_zero',
    '== "home_lost"',
    'resource_home_loss_suspends_runner=true active_plan_preserved=true strategic_home_loss_cancelled=true'
)) {
    if (!$scenarios.Contains($needle)) { throw "Runtime-ready split-home fixture is incomplete: $needle" }
}

function Apply-HomePolicy {
    param([bool]$HasStrategicHome, [bool]$HasResourceHome, [bool]$IsAutoBuilder, [int]$Status, [int]$Reservation, [bool]$Assigned)
    $planClosed = !$HasStrategicHome -and $Status -eq 1
    $runnerSuspended = $HasStrategicHome -and !$HasResourceHome -and !$IsAutoBuilder -and $Assigned
    if ($planClosed) { $Status = 3; $Reservation = 0; $Assigned = $false }
    elseif ($runnerSuspended) { $Reservation = 0; $Assigned = $false }
    [pscustomobject]@{ PlanClosed=$planClosed; RunnerSuspended=$runnerSuspended; Status=$Status; Reservation=$Reservation; Assigned=$Assigned }
}

$flagOnlyRunner = Apply-HomePolicy $true $false $false 1 41 $true
if ($flagOnlyRunner.PlanClosed -or !$flagOnlyRunner.RunnerSuspended -or $flagOnlyRunner.Status -ne 1 -or
    $flagOnlyRunner.Reservation -ne 0 -or $flagOnlyRunner.Assigned) {
    throw 'Flag-only teams must preserve the plan while suspending resource-dependent runners'
}
$flagOnlyOrb = Apply-HomePolicy $true $false $true 1 0 $true
if ($flagOnlyOrb.PlanClosed -or $flagOnlyOrb.RunnerSuspended -or !$flagOnlyOrb.Assigned) {
    throw 'Flag-only teams must allow inventory-free Autobuilders to continue paid work'
}
$noAnchor = Apply-HomePolicy $false $false $false 1 52 $true
if (!$noAnchor.PlanClosed -or $noAnchor.Status -ne 3 -or $noAnchor.Reservation -ne 0 -or $noAnchor.Assigned) {
    throw 'Losing every strategic home must close the plan and release its worker'
}
$healthy = Apply-HomePolicy $true $true $false 1 63 $true
if ($healthy.PlanClosed -or $healthy.RunnerSuspended -or $healthy.Status -ne 1 -or $healthy.Reservation -ne 63 -or !$healthy.Assigned) {
    throw 'A live tent/hall must preserve the active runner assignment'
}

Write-Output 'AIB strategic/resource-home lifecycle contract passed'
