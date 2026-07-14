$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root 'Scripts\AIBTestScenarios.as'
$source = Get-Content -LiteralPath $path -Raw

foreach ($needle in @(
    'strategic_mirrored_sides_physically_complete_safe_inward_plans',
    'strategic_uneven_right_edge_fallback_physically_completes',
    'strategic_scarcity_penalizes_unfunded_large_plan',
    'strategic_collapse_pressure_prefers_emergency_barrier',
    'strategic_damaged_front_reactivates_without_plan_replacement',
    'strategic_autobuilder_physically_completes_selected_plan',
    'strategic_no_build_primary_falls_back_and_physically_completes',
    'strategic_occupied_primary_falls_back_and_physically_completes',
    'strategic_barrier_primary_falls_back_and_physically_completes',
    'bool AIBT_PrepareMirroredPlan',
    'void AIBT_SetupMirroredCompletion()',
    'bool AIBT_MirroredPlanComplete',
    'bool AIBT_EvaluateMirroredCompletion',
    'AIBT_PrepareMirroredPlan(0, 1)',
    'AIBT_PrepareMirroredPlan(1, -1)',
    'world.enemyDirection == expectedDirection && world.autoBuilders == 0',
    'AIBPlanCandidate@ selected = AIBS_SelectCandidate(world);',
    'AIBS_ValidateCandidate(world, candidate)',
    'mirrored_plans_physically_complete=true',
    'void AIBT_SetupUnevenEdgeCompletion()',
    'bool AIBT_EvaluateUnevenEdgeCompletion',
    'primaryReason == "occupied_terrain"',
    'terrainVariance >= 2',
    'uneven_edge_fallback_physically_complete=true',
    'const bool obstaclePreserved = map.isTileCastle',
    'AIBS_GenerateCandidates(world, generated);',
    'AIBP_RefreshPlanState(0, true);',
    'AIBS_ActivePlanInvalid(world)',
    'AIBS_ShouldReplacePlan(world, candidate)',
    'AIBS_MakePlan(world, candidate)',
    'AIBP_PublishAIPlan(plan, true)',
    'AIBS_AssignBuilders(assignedWorld)',
    'AIBT_AllPlanTasksPhysicallyComplete',
    'selected_plan_physically_complete=true',
    'AIBT_SetupRepresentativeFallback(AIBT_FALLBACK_NO_BUILD)',
    'AIBT_SetupRepresentativeFallback(AIBT_FALLBACK_OCCUPIED)',
    'AIBT_SetupRepresentativeFallback(AIBT_FALLBACK_BARRIER)',
    'const int barrierX = primaryAnchorX - initialWorld.enemyDirection * 2;',
    'rules.set_bool("aib test resource barrier", true);',
    'rules.set_u16("barrier_x1", barrierWorldX);',
    'for (uint i = 0; i < 6; i++) AIBT_Spawn("knight", 1',
    'const bool initialPrimaryValid = initialPrimary !is null && AIBS_ValidateCandidate(initialWorld, initialPrimary);',
    'obstacleKind == AIBT_FALLBACK_NO_BUILD ? "no_build" :',
    '(obstacleKind == AIBT_FALLBACK_OCCUPIED ? "building_overlap" : "barrier")',
    'primaryReason == expectedReason',
    'representative_fallback_physically_complete=true',
    'AIBT_FallbackPlanRespectsObstacle',
    'AIBS_InsideBarrierSide(world, AIBT_Pos(xs[i], ys[i]))',
    'barrier_active=',
    'RemoveSectorsAtPosition(AIBT_temporary_no_build_points[i], "no build"',
    'case 54:',
    'case 55:',
    'case 56:',
    'case 57:',
    'case 58:',
    'case 59:',
    'case 60:',
    'case 61:',
    'case 62:',
    'case 63:'
)) {
    if (!$source.Contains($needle)) { throw "Representative director fixture contract is missing: $needle" }
}
if ([regex]::Matches($source, 'case 54:').Count -ne 2 -or [regex]::Matches($source, 'case 55:').Count -ne 2) {
    throw 'Representative director fixtures require exactly one setup and one evaluation case each'
}
if ([regex]::Matches($source, 'case 56:').Count -ne 2) { throw 'Scarcity fixture requires one setup and one evaluation case' }
if ([regex]::Matches($source, 'case 57:').Count -ne 2) { throw 'Pressure fixture requires one setup and one evaluation case' }
if ([regex]::Matches($source, 'case 58:').Count -ne 2) { throw 'Damaged-front fixture requires one setup and one evaluation case' }
if ([regex]::Matches($source, 'case 59:').Count -ne 2) { throw 'Physical selected-plan fixture requires one setup and one evaluation case' }
if ([regex]::Matches($source, 'case 61:').Count -ne 2) { throw 'No-build fallback fixture requires one setup and one evaluation case' }
if ([regex]::Matches($source, 'case 62:').Count -ne 2) { throw 'Occupied fallback fixture requires one setup and one evaluation case' }
if ([regex]::Matches($source, 'case 63:').Count -ne 2) { throw 'Barrier fallback fixture requires one setup and one evaluation case' }
if ($source -notmatch 'index != 54 && index != 55 && index != 56 && index != 57 && index != 58') { throw 'Planner-only fixtures are not exempt from the bot requirement' }
if ($source -notmatch 'world\.planPending == 2 && world\.planCompleted == 1 && world\.planDamaged == 2') { throw 'Damaged-front fixture does not assert exact reactivation counts' }
if ($source -notmatch 'AIBT_CountLayerTiles\(0, AIBP_Layer::ai_desired\) == expectedTasks') { throw 'Physical completion fixture does not verify the full desired layer' }
if ($source -notmatch 'AIBT_LayerIsEmpty\(0, AIBP_Layer::ai_work\)') { throw 'Physical completion fixture does not require exhausted work' }

$unevenStart = $source.IndexOf('void AIBT_SetupUnevenEdgeCompletion()')
$initialValid = $source.IndexOf('const bool initialPrimaryValid = initialPrimary !is null && AIBS_ValidateCandidate(initialWorld, initialPrimary);', $unevenStart)
$obstacleAdded = $source.IndexOf('AIBT_SetTemporaryTile(obstacleX, obstacleLowerY, CMap::tile_castle);', $unevenStart)
$fallbackSelected = $source.IndexOf('AIBPlanCandidate@ selected = AIBS_SelectCandidate(world);', $unevenStart)
$planPublished = $source.IndexOf('AIBP_PublishAIPlan(plan, true)', $unevenStart)
$executorSpawned = $source.IndexOf('CBlob@ executor = AIBT_Spawn("autobuilder"', $unevenStart)
$executorAssigned = $source.IndexOf('AIBS_AssignBuilders(assignedWorld);', $unevenStart)
if ($unevenStart -lt 0 -or $initialValid -lt $unevenStart -or $obstacleAdded -le $initialValid -or
    $fallbackSelected -le $obstacleAdded -or $planPublished -le $fallbackSelected -or
    $executorSpawned -le $planPublished -or $executorAssigned -le $executorSpawned) {
    throw 'Uneven-edge fixture must validate the original primary, add terrain, select/publish without an Autobuilder, then spawn and assign the executor'
}

$mirroredStart = $source.IndexOf('void AIBT_SetupMirroredCompletion()')
$leftPrepared = $source.IndexOf('AIBT_PrepareMirroredPlan(0, 1)', $mirroredStart)
$rightPrepared = $source.IndexOf('AIBT_PrepareMirroredPlan(1, -1)', $mirroredStart)
$leftSpawned = $source.IndexOf('@leftExecutor = AIBT_Spawn("autobuilder"', $mirroredStart)
$leftAssigned = $source.IndexOf('AIBS_AssignBuilders(leftWorld);', $mirroredStart)
$rightAssigned = $source.IndexOf('AIBS_AssignBuilders(rightWorld);', $mirroredStart)
if ($mirroredStart -lt 0 -or $leftPrepared -lt $mirroredStart -or $rightPrepared -le $leftPrepared -or
    $leftSpawned -le $rightPrepared -or $leftAssigned -le $leftSpawned -or $rightAssigned -le $leftAssigned) {
    throw 'Mirrored fixture must prepare and publish both ordinary-reachability plans before spawning and assigning either Autobuilder'
}

Write-Output 'AIB representative director fixture contract passed'
