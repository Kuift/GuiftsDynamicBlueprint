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
    foreach ($side in @('left','right')) {
        $team = $side -eq 'left' ? 0 : 1
        foreach ($run in 1..3) {
            $ticks = 150 + $run + $team * 10
            $rows += "[AIBGYMI] schema=3 status=result run=workshops_${side}_${run} variant=candidate metric=protected_class_workshops_physical fixture_id=map_111_200x80 fixture_version=2 team=$team team_side=$side map_hash=111 map_width=200 map_height=80 initial_terrain_hash=$run initial_fingerprint=w1-workshops-$side-$run template=protected_workshops resource_home=tent resource_home_x=12 resource_home_y=35 resource_home_exact=true anchor_x=30 ground_y=40 enemy_direction=1 plan_id=4 plan_version=3 tasks=70 initial_matches=0 physical_matches=70 foundation_matches=40 access_matches=0 shell_matches=28 completed=70 pending=0 plan_status=2 reservations=0 desired_tiles=70 work_tiles=0 archived_complete=true knight_shop=true archer_shop=true knight_shop_healthy=true archer_shop_healthy=true roof_cover_matches=10 roof_cover_expected=10 backing_cover_matches=28 backing_cover_expected=28 side_cover_matches=4 side_cover_expected=4 bounded_cover=true home_gate=true home_gate_x=22 home_upper_cover=true enemy_wall_matches=3 enemy_wall_expected=3 enemy_wall_x=38 friendly_route_penalty=0 home_route_started=true home_route_reached=true home_route_ticks=80 home_start_distance_tiles=3 home_access_rise=6 knight_shop_used=true archer_shop_used=true class_use_ticks=30 final_class=archer ally_home_entered=true ally_home_exited=true ally_traversal_ticks=$ticks ally_final_x=1 ally_final_y=1 ally_progress_px=180 completion_tick=1900 elapsed=2100 ai_actor_cap=8 managed_actor_peak=2 passed=true reason=protected_workshops_home_route_class_use_and_return_complete"
        }
    }
    foreach ($side in @('left','right')) {
        $team = $side -eq 'left' ? 0 : 1
        $enemyTeam = $team -eq 0 ? 1 : 0
        foreach ($run in 1..3) {
            $rows += "[AIBGYMI] schema=4 status=result run=gate_breach_${side}_${run} variant=candidate metric=flag_gatehouse_enemy_breach_physical fixture_id=map_111_200x80 fixture_version=3 team=$team enemy_team=$enemyTeam team_side=$side map_hash=111 map_width=200 map_height=80 initial_terrain_hash=$run initial_fingerprint=w1-gate-breach-$side-$run template=flag_gatehouse anchor_x=36 ground_y=40 enemy_direction=1 plan_id=5 plan_version=4 tasks=36 initial_matches=0 physical_matches=36 completed=36 pending=0 reservations=0 work_tiles=0 pre_attack_physical_matches=36 pre_attack_foundation_matches=12 pre_attack_access_matches=13 pre_attack_shell_matches=11 pre_attack_plan_complete=true archived_complete=true physical_matches_final=34 foundation_matches_final=12 access_matches_final=11 shell_matches_final=11 friendly_validated=true ally_home_entered=true ally_home_exited=true ally_traversal_ticks=45 ally_final_x=1 ally_final_y=1 enemy_probe_real=true enemy_class=builder enemy_attack_kind=pickaxe enemy_player_bound=true enemy_attack_origin=client_existing_pickaxe_command enemy_movement_controller=server_static_outer_stance_then_bounded_velocity enemy_pickaxe_commands=20 enemy_contact=true enemy_damage_observed=true enemy_entered=true enemy_crossed=true enemy_initial_blockers=2 enemy_final_blockers=0 enemy_initial_blocker_health=2 enemy_final_blocker_health=0 enemy_first_command_ticks=1 enemy_last_command_ticks=220 enemy_first_contact_ticks=20 enemy_first_damage_ticks=35 enemy_entry_ticks=100 enemy_crossing_ticks=220 enemy_probe_ticks=220 enemy_outcome=crossed enemy_final_x=2 enemy_final_y=2 completion_tick=1070 elapsed=1400 ai_actor_cap=8 managed_actor_peak=2 passed=true reason=real_enemy_pickaxe_crossing_complete"
            $rows += "[AIBGYMI] schema=4 status=result run=workshop_breach_${side}_${run} variant=control metric=protected_class_workshops_enemy_breach_physical fixture_id=map_111_200x80 fixture_version=4 team=$team enemy_team=$enemyTeam team_side=$side map_hash=111 map_width=200 map_height=80 initial_terrain_hash=$run initial_fingerprint=w1-workshop-breach-$side-$run template=protected_workshops anchor_x=30 ground_y=40 enemy_direction=1 plan_id=6 plan_version=4 tasks=70 initial_matches=0 physical_matches=70 completed=70 pending=0 reservations=0 work_tiles=0 pre_attack_physical_matches=70 pre_attack_foundation_matches=40 pre_attack_access_matches=0 pre_attack_shell_matches=28 pre_attack_plan_complete=true archived_complete=true physical_matches_final=69 foundation_matches_final=40 access_matches_final=0 shell_matches_final=27 friendly_validated=true ally_home_entered=true ally_home_exited=true ally_traversal_ticks=180 ally_final_x=1 ally_final_y=1 enemy_probe_real=true enemy_class=builder enemy_attack_kind=pickaxe enemy_player_bound=true enemy_attack_origin=client_existing_pickaxe_command enemy_movement_controller=server_static_outer_stance_then_bounded_velocity enemy_pickaxe_commands=75 enemy_contact=true enemy_damage_observed=true enemy_entered=false enemy_crossed=false enemy_initial_blockers=4 enemy_final_blockers=3 enemy_initial_blocker_health=1 enemy_final_blocker_health=1 enemy_first_command_ticks=1 enemy_last_command_ticks=895 enemy_first_contact_ticks=30 enemy_first_damage_ticks=60 enemy_entry_ticks=0 enemy_crossing_ticks=0 enemy_probe_ticks=900 enemy_outcome=resisted enemy_final_x=2 enemy_final_y=2 completion_tick=1900 elapsed=3000 ai_actor_cap=8 managed_actor_peak=2 passed=true reason=real_enemy_pickaxe_resisted_until_deadline"
        }
    }
    # Exact console/TCPR duplication must not inflate run counts.
    $rows += $rows[0]
    # Auxiliary site/probe records use the same prefix but are not result rows.
    $rows += '[AIBGYMI] AIBGYMI|WORKSHOP_SITES|run=diagnostic|sites=14@26,29:rise0:valid'
    $rows += '[AIBGYMI] AIBGYMI|PROBE|run=diagnostic|boundary=home_landing_reached|class=builder|x=1|y=2'
    [IO.File]::WriteAllLines($log, $rows)
    $summary = @(& $tool -LogPath $log -MinimumRunsPerCohort 3 -RequireAllPassed -AsJson | ConvertFrom-Json)
    if ($summary.Count -ne 8 -or @($summary | Where-Object Runs -ne 3).Count -ne 0 -or
        @($summary | Where-Object { !$_.AcceptancePassed }).Count -ne 0) {
        throw 'Valid mirrored cohorts were not summarized or deduplicated correctly.'
    }

    $shortRejected = $false
    try { & $tool -LogPath $log -MinimumRunsPerCohort 4 -AsJson | Out-Null }
    catch { $shortRejected = $_.Exception.Message -match 'requires 4' }
    if (!$shortRejected) { throw 'Minimum unique-run enforcement did not reject a short cohort.' }

    # A single control row must not borrow the candidate arm's three samples to
    # satisfy the minimum-run gate for the same fixture/team/side.
    $variantIsolation = Join-Path $temp 'variant-isolation.txt'
    $candidateArm = @($rows | Where-Object { $_ -match 'run=gate_breach_left_[123] ' })
    $controlArm = $candidateArm[0] -replace 'run=gate_breach_left_1 ', 'run=gate_breach_left_control_1 ' -replace 'variant=candidate', 'variant=control'
    [IO.File]::WriteAllLines($variantIsolation, @($candidateArm + $controlArm))
    $variantRejected = $false
    try { & $tool -LogPath $variantIsolation -MinimumRunsPerCohort 3 -AsJson | Out-Null }
    catch { $variantRejected = $_.Exception.Message -match 'requires 3' }
    if (!$variantRejected) { throw 'Control and candidate rows were pooled across the variant boundary.' }

    $conflict = Join-Path $temp 'conflict.txt'
    [IO.File]::WriteAllLines($conflict, @($rows[0], ($rows[0] -replace 'passed=true','passed=false')))
    $conflictRejected = $false
    try { & $tool -LogPath $conflict -MinimumRunsPerCohort 1 -AsJson | Out-Null }
    catch { $conflictRejected = $_.Exception.Message -match 'Conflicting AIBGYMI records reuse run id' }
    if (!$conflictRejected) { throw 'Conflicting duplicate run ids were not rejected.' }

    $weakWorkshop = Join-Path $temp 'weak-workshop.txt'
    $weakWorkshopLine = (($rows | Where-Object { $_ -match 'run=workshops_left_1 ' }) -replace 'bounded_cover=true','bounded_cover=false')
    [IO.File]::WriteAllText($weakWorkshop, $weakWorkshopLine)
    $weakRejected = $false
    try { & $tool -LogPath $weakWorkshop -MinimumRunsPerCohort 1 -RequireAllPassed -AsJson | Out-Null }
    catch { $weakRejected = $_.Exception.Message -match 'Infrastructure acceptance failed' }
    if (!$weakRejected) { throw 'Workshop metric accepted a result without bounded cover.' }

    $openEnemyWall = Join-Path $temp 'open-enemy-wall.txt'
    $openEnemyWallLine = (($rows | Where-Object { $_ -match 'run=workshops_left_1 ' }) -replace 'enemy_wall_matches=3','enemy_wall_matches=2')
    [IO.File]::WriteAllText($openEnemyWall, $openEnemyWallLine)
    $openEnemyWallRejected = $false
    try { & $tool -LogPath $openEnemyWall -MinimumRunsPerCohort 1 -RequireAllPassed -AsJson | Out-Null }
    catch { $openEnemyWallRejected = $_.Exception.Message -match 'Infrastructure acceptance failed' }
    if (!$openEnemyWallRejected) { throw 'Workshop metric accepted incomplete enemy-facing wall cover.' }

    $noHomeReturn = Join-Path $temp 'no-home-return.txt'
    $noHomeReturnLine = (($rows | Where-Object { $_ -match 'run=workshops_left_1 ' }) -replace 'ally_home_exited=true','ally_home_exited=false')
    [IO.File]::WriteAllText($noHomeReturn, $noHomeReturnLine)
    $noHomeReturnRejected = $false
    try { & $tool -LogPath $noHomeReturn -MinimumRunsPerCohort 1 -RequireAllPassed -AsJson | Out-Null }
    catch { $noHomeReturnRejected = $_.Exception.Message -match 'Infrastructure acceptance failed' }
    if (!$noHomeReturnRejected) { throw 'Workshop metric accepted class use without a physical home-side return.' }

    $noEnemyDamage = Join-Path $temp 'no-enemy-damage.txt'
    $noEnemyDamageLine = (($rows | Where-Object { $_ -match 'run=gate_breach_left_1 ' }) -replace 'enemy_damage_observed=true','enemy_damage_observed=false')
    [IO.File]::WriteAllText($noEnemyDamage, $noEnemyDamageLine)
    $noEnemyDamageRejected = $false
    try { & $tool -LogPath $noEnemyDamage -MinimumRunsPerCohort 1 -RequireAllPassed -AsJson | Out-Null }
    catch { $noEnemyDamageRejected = $_.Exception.Message -match 'Infrastructure acceptance failed' }
    if (!$noEnemyDamageRejected) { throw 'Enemy breach metric accepted movement without observed structure damage.' }

    $unboundEnemy = Join-Path $temp 'unbound-enemy.txt'
    $unboundEnemyLine = (($rows | Where-Object { $_ -match 'run=gate_breach_left_1 ' }) -replace 'enemy_player_bound=true','enemy_player_bound=false')
    [IO.File]::WriteAllText($unboundEnemy, $unboundEnemyLine)
    $unboundEnemyRejected = $false
    try { & $tool -LogPath $unboundEnemy -MinimumRunsPerCohort 1 -RequireAllPassed -AsJson | Out-Null }
    catch { $unboundEnemyRejected = $_.Exception.Message -match 'Infrastructure acceptance failed' }
    if (!$unboundEnemyRejected) { throw 'Enemy breach metric accepted an unbound synthetic probe.' }

    $emptyResistance = Join-Path $temp 'empty-resistance.txt'
    $emptyResistanceLine = (($rows | Where-Object { $_ -match 'run=workshop_breach_left_1 ' }) -replace 'enemy_final_blockers=3','enemy_final_blockers=0')
    [IO.File]::WriteAllText($emptyResistance, $emptyResistanceLine)
    $emptyResistanceRejected = $false
    try { & $tool -LogPath $emptyResistance -MinimumRunsPerCohort 1 -RequireAllPassed -AsJson | Out-Null }
    catch { $emptyResistanceRejected = $_.Exception.Message -match 'Infrastructure acceptance failed' }
    if (!$emptyResistanceRejected) { throw 'Enemy resistance outcome accepted after every blocker was lost.' }

    $staleResistance = Join-Path $temp 'stale-resistance.txt'
    $staleResistanceLine = (($rows | Where-Object { $_ -match 'run=workshop_breach_left_1 ' }) -replace 'enemy_last_command_ticks=895','enemy_last_command_ticks=100')
    [IO.File]::WriteAllText($staleResistance, $staleResistanceLine)
    $staleResistanceRejected = $false
    try { & $tool -LogPath $staleResistance -MinimumRunsPerCohort 1 -RequireAllPassed -AsJson | Out-Null }
    catch { $staleResistanceRejected = $_.Exception.Message -match 'Infrastructure acceptance failed' }
    if (!$staleResistanceRejected) { throw 'Enemy resistance outcome accepted after the attack command stream went stale.' }

    'AIB infrastructure summary tests passed.'
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
