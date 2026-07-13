$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root 'Scripts\AIBTestScenarios.as'
$source = Get-Content -LiteralPath $path -Raw

foreach ($needle in @(
    'strategic_mirrored_sides_select_safe_inward_candidates',
    'strategic_uneven_right_edge_selects_reachable_fallback',
    'strategic_scarcity_penalizes_unfunded_large_plan',
    'strategic_collapse_pressure_prefers_emergency_barrier',
    'bool AIBT_RepresentativeDirectorCandidate',
    'AIBWorldState@ world = AIBS_ObserveWorld(team);',
    'AIBPlanCandidate@ candidate = AIBS_SelectCandidate(world);',
    'AIBS_ValidateCandidate(world, candidate)',
    'representative_not_inward',
    'representative_task_out_of_bounds',
    'representative_fixture_not_uneven',
    'uneven_edge_primary_not_rejected',
    'AIBS_GenerateCandidates(world, generated);',
    'case 54:',
    'case 55:',
    'case 56:',
    'case 57:'
)) {
    if (!$source.Contains($needle)) { throw "Representative director fixture contract is missing: $needle" }
}
if ([regex]::Matches($source, 'case 54:').Count -ne 2 -or [regex]::Matches($source, 'case 55:').Count -ne 2) {
    throw 'Representative director fixtures require exactly one setup and one evaluation case each'
}
if ([regex]::Matches($source, 'case 56:').Count -ne 2) { throw 'Scarcity fixture requires one setup and one evaluation case' }
if ([regex]::Matches($source, 'case 57:').Count -ne 2) { throw 'Pressure fixture requires one setup and one evaluation case' }
if ($source -notmatch 'index != 54 && index != 55 && index != 56 && index != 57') { throw 'Planner-only fixtures are not exempt from the bot requirement' }

Write-Output 'AIB representative director fixture contract passed'
