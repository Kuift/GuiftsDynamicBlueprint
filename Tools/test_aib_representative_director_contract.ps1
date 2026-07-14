$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root 'Scripts\AIBTestScenarios.as'
$source = Get-Content -LiteralPath $path -Raw

foreach ($needle in @(
    'strategic_mirrored_sides_select_safe_inward_candidates',
    'strategic_uneven_right_edge_selects_reachable_fallback',
    'strategic_scarcity_penalizes_unfunded_large_plan',
    'strategic_collapse_pressure_prefers_emergency_barrier',
    'strategic_damaged_front_reactivates_without_plan_replacement',
    'strategic_autobuilder_physically_completes_selected_plan',
    'strategic_no_build_primary_falls_back_and_physically_completes',
    'strategic_occupied_primary_falls_back_and_physically_completes',
    'bool AIBT_RepresentativeDirectorCandidate',
    'AIBWorldState@ world = AIBS_ObserveWorld(team);',
    'AIBPlanCandidate@ candidate = AIBS_SelectCandidate(world);',
    'AIBS_ValidateCandidate(world, candidate)',
    'representative_not_inward',
    'representative_task_out_of_bounds',
    'representative_fixture_not_uneven',
    'uneven_edge_primary_not_rejected',
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
    'const bool initialPrimaryValid = initialPrimary !is null && AIBS_ValidateCandidate(initialWorld, initialPrimary);',
    'obstacleKind == AIBT_FALLBACK_NO_BUILD ? "no_build" : "building_overlap"',
    'primaryReason == expectedReason',
    'representative_fallback_physically_complete=true',
    'AIBT_FallbackPlanRespectsObstacle',
    'RemoveSectorsAtPosition(AIBT_temporary_no_build_points[i], "no build"',
    'case 54:',
    'case 55:',
    'case 56:',
    'case 57:',
    'case 58:',
    'case 59:',
    'case 60:',
    'case 61:',
    'case 62:'
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
if ($source -notmatch 'index != 54 && index != 55 && index != 56 && index != 57 && index != 58') { throw 'Planner-only fixtures are not exempt from the bot requirement' }
if ($source -notmatch 'world\.planPending == 2 && world\.planCompleted == 1 && world\.planDamaged == 2') { throw 'Damaged-front fixture does not assert exact reactivation counts' }
if ($source -notmatch 'AIBT_CountLayerTiles\(0, AIBP_Layer::ai_desired\) == expectedTasks') { throw 'Physical completion fixture does not verify the full desired layer' }
if ($source -notmatch 'AIBT_LayerIsEmpty\(0, AIBP_Layer::ai_work\)') { throw 'Physical completion fixture does not require exhausted work' }

Write-Output 'AIB representative director fixture contract passed'
