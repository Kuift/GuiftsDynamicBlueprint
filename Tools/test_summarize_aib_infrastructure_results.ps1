$ErrorActionPreference = 'Stop'
$tool = Join-Path $PSScriptRoot 'summarize_aib_infrastructure_results.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ("aibi_summary_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $log = Join-Path $temp 'results.txt'
    $rows = @()
    foreach ($side in @('left','right')) {
        $team = $side -eq 'left' ? 0 : 1
        foreach ($run in 1..3) {
            $ticks = 40 + $run + $team * 10
            $rows += "[AIBGYMI] schema=1 status=result run=${side}_${run} variant=candidate metric=flag_gatehouse_physical fixture_id=map_111_200x80 fixture_version=1 team=$team team_side=$side map_hash=111 map_width=200 map_height=80 initial_terrain_hash=$run initial_fingerprint=w1-$side-$run template=flag_gatehouse flag_x=20 flag_y=30 anchor_x=36 ground_y=40 enemy_direction=1 plan_id=3 plan_version=2 tasks=36 initial_matches=0 physical_matches=36 foundation_matches=12 access_matches=13 shell_matches=11 completed=36 pending=0 plan_status=2 reservations=0 desired_tiles=36 work_tiles=0 archived_complete=true rear_gate=true front_gate=true rear_gate_x=33 front_gate_x=39 friendly_route_penalty=0 ally_rear_entered=true ally_front_exited=true ally_traversal_ticks=$ticks ally_final_x=1 ally_final_y=1 ally_progress_px=62 completion_tick=1070 elapsed=1120 ai_actor_cap=8 managed_actor_peak=2 passed=true reason=physical_gatehouse_and_ally_passage_complete"
        }
    }
    # Exact console/TCPR duplication must not inflate run counts.
    $rows += $rows[0]
    [IO.File]::WriteAllLines($log, $rows)
    $summary = @(& $tool -LogPath $log -MinimumRunsPerCohort 3 -RequireAllPassed -AsJson | ConvertFrom-Json)
    if ($summary.Count -ne 2 -or @($summary | Where-Object Runs -ne 3).Count -ne 0 -or
        @($summary | Where-Object { !$_.AcceptancePassed }).Count -ne 0) {
        throw 'Valid mirrored cohorts were not summarized or deduplicated correctly.'
    }

    $shortRejected = $false
    try { & $tool -LogPath $log -MinimumRunsPerCohort 4 -AsJson | Out-Null }
    catch { $shortRejected = $_.Exception.Message -match 'requires 4' }
    if (!$shortRejected) { throw 'Minimum unique-run enforcement did not reject a short cohort.' }

    $conflict = Join-Path $temp 'conflict.txt'
    [IO.File]::WriteAllLines($conflict, @($rows[0], ($rows[0] -replace 'passed=true','passed=false')))
    $conflictRejected = $false
    try { & $tool -LogPath $conflict -MinimumRunsPerCohort 1 -AsJson | Out-Null }
    catch { $conflictRejected = $_.Exception.Message -match 'Conflicting AIBGYMI records reuse run id' }
    if (!$conflictRejected) { throw 'Conflicting duplicate run ids were not rejected.' }

    'AIB infrastructure summary tests passed.'
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
