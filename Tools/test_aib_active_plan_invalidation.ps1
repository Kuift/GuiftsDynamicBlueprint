$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$planner = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBPlacementPlanner.as') -Raw
$scenarios = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBTestScenarios.as') -Raw

$function = [regex]::Match($planner, 'bool AIBS_ActivePlanInvalid[\s\S]*?\n\}').Value
if (!$function) { throw 'Production active-plan invalidation function is missing' }
foreach ($needle in @(
    'if (AIBP_MapMatchesBlock(xs[i], ys[i], blocks[i], world.team)) continue;',
    'if (!AIBS_InsideBarrierSide(world, center)) return true;',
    'map.getSectorAtPosition(center, "no build") !is null',
    'if (AIBS_OverlapsProtectedBlob(world.team, center)) return true;',
    'if (AIBP_IsRepairablePlanOccupant(world.team, xs[i], ys[i], blocks[i])) continue;',
    'map.isTileBedrock(current) || (map.isTileSolid(current) && !map.isTileGrass(current))',
    'AIBS_ActivePlanHasDependencySupport(world, xs, ys, blocks, phases, states)'
)) {
    if (!$function.Contains($needle)) { throw "Active-plan invalidation is missing: $needle" }
}

$dependencyFunction = [regex]::Match($planner, 'bool AIBS_ActivePlanHasDependencySupport[\s\S]*?\n\}').Value
if (!$dependencyFunction) { throw 'Production active-plan dependency reconstruction is missing' }
foreach ($needle in @(
    'if (states[i] == AIBP_TaskState::cancelled) continue;',
    'BlueprintTask@ task = BlueprintTask(xs[i], ys[i], blocks[i], phases[i]);',
    'task.state = states[i];',
    'AIBS_CandidateHasDependencySupport(world, active)'
)) {
    if (!$dependencyFunction.Contains($needle)) { throw "Active-plan dependency reconstruction is missing: $needle" }
}

$matchAt = $function.IndexOf('if (AIBP_MapMatchesBlock')
$barrierAt = $function.IndexOf('if (!AIBS_InsideBarrierSide')
$noBuildAt = $function.IndexOf('map.getSectorAtPosition(center, "no build")')
$protectedAt = $function.IndexOf('if (AIBS_OverlapsProtectedBlob')
$repairAt = $function.IndexOf('if (AIBP_IsRepairablePlanOccupant')
$terrainAt = $function.IndexOf('map.isTileBedrock(current)')
$dependencyAt = $function.IndexOf('AIBS_ActivePlanHasDependencySupport')
if ($matchAt -lt 0 -or $barrierAt -lt 0 -or $noBuildAt -lt 0 -or $protectedAt -lt 0 -or $repairAt -lt 0 -or $terrainAt -lt 0 -or $dependencyAt -lt 0) {
    throw 'Could not audit active-plan invalidation ordering'
}
if (!($matchAt -lt $barrierAt -and $barrierAt -lt $repairAt -and $noBuildAt -lt $repairAt -and
      $protectedAt -lt $repairAt -and $repairAt -lt $terrainAt -and $terrainAt -lt $dependencyAt)) {
    throw 'Only already-matching work may bypass live safety gates; repairability must precede terrain rejection but follow barrier/no-build/protected checks'
}

if (!$scenarios.Contains('strategic_damaged_front_reactivates_without_plan_replacement') -or
    !$scenarios.Contains('repairable=true plan_identity_stable=true replacement=false')) {
    throw 'Safe damaged-front retention fixture is missing; safety ordering must not make ordinary repairs churn plans'
}
if (!$planner.Contains('rules.set_string("aib strategy replacement reason team " + int(world.team), "invalidated");')) {
    throw 'Unsafe active plans no longer expose the invalidated replacement reason'
}

function Test-Invalid {
    param([bool]$Matches, [bool]$BarrierSafe, [bool]$NoBuild, [bool]$Protected, [bool]$Repairable, [bool]$Solid)
    if ($Matches) { return $false }
    if (!$BarrierSafe -or $NoBuild -or $Protected) { return $true }
    if ($Repairable) { return $false }
    return $Solid
}

if (Test-Invalid $true $false $true $true $false $true) { throw 'Already-complete matching work should not invalidate a plan after the world gate changes' }
if (!(Test-Invalid $false $false $false $false $true $true)) { throw 'Repairable damage across the active barrier was not invalidated' }
if (!(Test-Invalid $false $true $true $false $true $true)) { throw 'Repairable damage inside a no-build sector was not invalidated' }
if (!(Test-Invalid $false $true $false $true $true $true)) { throw 'Repairable damage overlapping a protected building was not invalidated' }
if (Test-Invalid $false $true $false $false $true $true) { throw 'Safe repairable damage must retain the active plan' }
if (!(Test-Invalid $false $true $false $false $false $true)) { throw 'Non-repairable solid occupation must invalidate the active plan' }

function Test-GeneratedSupport {
    param([object[]]$Column)
    foreach ($cell in $Column) {
        if ($cell.Support) { return $true }
        if ($cell.NoBuild -or !$cell.BarrierSafe -or $cell.Protected) { return $false }
    }
    return $false
}

$open = @(
    [pscustomobject]@{ Support=$false; NoBuild=$false; BarrierSafe=$true; Protected=$false },
    [pscustomobject]@{ Support=$false; NoBuild=$false; BarrierSafe=$true; Protected=$false },
    [pscustomobject]@{ Support=$true; NoBuild=$false; BarrierSafe=$true; Protected=$false }
)
if (!(Test-GeneratedSupport $open)) { throw 'Open generated backwall chain should retain the active plan' }
foreach ($field in @('NoBuild', 'Protected')) {
    $blocked = @($open | ForEach-Object { $_.psobject.Copy() })
    $blocked[0].$field = $true
    if (Test-GeneratedSupport $blocked) { throw "Generated support obstruction $field should invalidate the active plan" }
}
$acrossBarrier = @($open | ForEach-Object { $_.psobject.Copy() })
$acrossBarrier[0].BarrierSafe = $false
if (Test-GeneratedSupport $acrossBarrier) { throw 'Generated support across the active barrier should invalidate the active plan' }

Write-Output 'AIB active-plan safety invalidation contract passed'
