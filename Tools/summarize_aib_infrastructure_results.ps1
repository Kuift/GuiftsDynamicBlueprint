[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$LogPath,

    [ValidateRange(1,1000)]
    [int]$MinimumRunsPerCohort = 3,

    [switch]$RequireAllPassed,

    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'

function ConvertTo-InfrastructureRecord([string]$line, [string]$source) {
    if ($line -notmatch '^(?:\[\d{2}:\d{2}:\d{2}\]\s+)?\[AIBGYMI\]\s+') { return $null }
    # Site/probe boundary diagnostics share the prefix but are deliberately not
    # cohort rows. Only schema-bearing records enter strict result validation.
    if ($line -notmatch '(?:^|\s)schema=') { return $null }
    $fields = @{}
    foreach ($token in ($line -split '\s+')) {
        if ($token -notmatch '^([^=]+)=(.*)$') { continue }
        $fields[$Matches[1]] = $Matches[2]
    }
    foreach ($key in @('schema','status','run')) {
        if (!$fields.ContainsKey($key)) { throw "Malformed AIBGYMI record in ${source}: missing $key" }
    }
    if ($fields.schema -notin @('1','2','3','4') -or $fields.status -ne 'result') { return $null }
    foreach ($key in @('variant','metric','fixture_id','fixture_version','team','team_side','map_hash','map_width','map_height',
        'template','tasks','physical_matches','completed','pending','reservations','work_tiles','archived_complete',
        'ally_traversal_ticks','completion_tick','elapsed','passed','reason')) {
        if (!$fields.ContainsKey($key)) { throw "Malformed AIBGYMI schema-$($fields.schema) result in ${source}: missing $key" }
    }
    if ($fields.schema -in @('1','2')) {
        foreach ($key in @('rear_gate','front_gate','ally_rear_entered','ally_front_exited')) {
            if (!$fields.ContainsKey($key)) { throw "Malformed AIBGYMI schema-$($fields.schema) result in ${source}: missing $key" }
        }
    }
    $workshopBooleanKeys = @()
    $workshopNumericKeys = @()
    if ($fields.schema -in @('2','3')) {
        foreach ($key in @('resource_home','resource_home_x','resource_home_y','resource_home_exact','knight_shop','archer_shop',
            'knight_shop_healthy','archer_shop_healthy','roof_cover_matches','roof_cover_expected','backing_cover_matches',
            'backing_cover_expected','side_cover_matches','side_cover_expected','bounded_cover','home_route_started',
            'home_route_reached','home_route_ticks','home_start_distance_tiles','knight_shop_used','archer_shop_used',
            'class_use_ticks','final_class')) {
            if (!$fields.ContainsKey($key)) { throw "Malformed AIBGYMI schema-2 result in ${source}: missing $key" }
        }
        $workshopBooleanKeys = @('resource_home_exact','knight_shop','archer_shop','knight_shop_healthy',
            'archer_shop_healthy','bounded_cover','home_route_started','home_route_reached','knight_shop_used','archer_shop_used')
        $workshopNumericKeys = @('resource_home_x','resource_home_y','roof_cover_matches','roof_cover_expected',
            'backing_cover_matches','backing_cover_expected','side_cover_matches','side_cover_expected','home_route_ticks',
            'home_start_distance_tiles','class_use_ticks')
    }
    $schema3BooleanKeys = @()
    $schema3NumericKeys = @()
    if ($fields.schema -eq '3') {
        foreach ($key in @('home_gate','home_gate_x','home_upper_cover','enemy_wall_matches','enemy_wall_expected',
            'enemy_wall_x','ally_home_entered','ally_home_exited','home_access_rise')) {
            if (!$fields.ContainsKey($key)) { throw "Malformed AIBGYMI schema-3 result in ${source}: missing $key" }
        }
        $schema3BooleanKeys = @('home_gate','home_upper_cover','ally_home_entered','ally_home_exited')
        $schema3NumericKeys = @('home_gate_x','enemy_wall_matches','enemy_wall_expected','enemy_wall_x','home_access_rise')
    }
    $schema4BooleanKeys = @()
    $schema4NumericKeys = @()
    if ($fields.schema -eq '4') {
        foreach ($key in @('enemy_team','pre_attack_physical_matches','pre_attack_foundation_matches',
            'pre_attack_access_matches','pre_attack_shell_matches','pre_attack_plan_complete','friendly_validated',
            'ally_home_entered','ally_home_exited','enemy_probe_real','enemy_class','enemy_attack_kind',
            'enemy_player_bound','enemy_attack_origin','enemy_movement_controller','enemy_pickaxe_commands',
            'enemy_contact','enemy_damage_observed','enemy_entered',
            'enemy_crossed','enemy_initial_blockers','enemy_final_blockers','enemy_initial_blocker_health',
            'enemy_final_blocker_health','enemy_first_command_ticks','enemy_last_command_ticks','enemy_first_contact_ticks',
            'enemy_first_damage_ticks','enemy_entry_ticks','enemy_crossing_ticks','enemy_probe_ticks',
            'enemy_outcome','enemy_final_x','enemy_final_y')) {
            if (!$fields.ContainsKey($key)) { throw "Malformed AIBGYMI schema-4 result in ${source}: missing $key" }
        }
        $schema4BooleanKeys = @('pre_attack_plan_complete','friendly_validated','ally_home_entered',
            'ally_home_exited','enemy_probe_real','enemy_player_bound','enemy_contact','enemy_damage_observed',
            'enemy_entered','enemy_crossed')
        $schema4NumericKeys = @('enemy_team','pre_attack_physical_matches','pre_attack_foundation_matches',
            'pre_attack_access_matches','pre_attack_shell_matches','enemy_pickaxe_commands','enemy_initial_blockers',
            'enemy_final_blockers','enemy_initial_blocker_health','enemy_final_blocker_health',
            'enemy_first_command_ticks','enemy_last_command_ticks','enemy_first_contact_ticks','enemy_first_damage_ticks','enemy_entry_ticks',
            'enemy_crossing_ticks','enemy_probe_ticks','enemy_final_x','enemy_final_y')
    }
    $passageBooleanKeys = if ($fields.schema -in @('1','2')) {
        @('rear_gate','front_gate','ally_rear_entered','ally_front_exited')
    } else { @() }
    foreach ($key in @('archived_complete','passed') + $passageBooleanKeys + $workshopBooleanKeys + $schema3BooleanKeys + $schema4BooleanKeys) {
        if ($fields[$key] -notin @('true','false')) { throw "Invalid boolean $key=$($fields[$key]) in $source" }
    }
    $numbers = @{}
    foreach ($key in @('fixture_version','team','map_hash','map_width','map_height','tasks','physical_matches','completed',
        'pending','reservations','work_tiles','ally_traversal_ticks','completion_tick','elapsed') + $workshopNumericKeys + $schema3NumericKeys + $schema4NumericKeys) {
        [double]$value = 0
        if (![double]::TryParse($fields[$key], [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture, [ref]$value)) {
            throw "Invalid numeric $key=$($fields[$key]) in $source"
        }
        $numbers[$key] = $value
    }
    if ($fields.schema -eq '4') {
        if ($fields.enemy_class -ne 'builder' -or $fields.enemy_attack_kind -ne 'pickaxe') {
            throw "Unsupported schema-4 enemy probe $($fields.enemy_class)/$($fields.enemy_attack_kind) in $source"
        }
        if ($fields.enemy_attack_origin -ne 'client_existing_pickaxe_command' -or
            $fields.enemy_movement_controller -ne 'server_static_outer_stance_then_bounded_velocity') {
            throw "Unsupported schema-4 probe authority $($fields.enemy_attack_origin)/$($fields.enemy_movement_controller) in $source"
        }
        if ($fields.enemy_outcome -notin @('crossed','resisted','invalid')) {
            throw "Invalid schema-4 enemy_outcome=$($fields.enemy_outcome) in $source"
        }
    }
    [pscustomobject]@{
        Schema = [int]$fields.schema
        Run = $fields.run
        Variant = $fields.variant
        Metric = $fields.metric
        FixtureId = $fields.fixture_id
        FixtureVersion = [int]$numbers.fixture_version
        Team = [int]$numbers.team
        TeamSide = $fields.team_side
        MapHash = [uint32]$numbers.map_hash
        MapWidth = [int]$numbers.map_width
        MapHeight = [int]$numbers.map_height
        Template = $fields.template
        Tasks = [int]$numbers.tasks
        PhysicalMatches = [int]$numbers.physical_matches
        Completed = [int]$numbers.completed
        Pending = [int]$numbers.pending
        Reservations = [int]$numbers.reservations
        WorkTiles = [int]$numbers.work_tiles
        ArchivedComplete = $fields.archived_complete -eq 'true'
        RearGate = $fields.schema -in @('1','2') -and $fields.rear_gate -eq 'true'
        FrontGate = $fields.schema -in @('1','2') -and $fields.front_gate -eq 'true'
        AllyRearEntered = $fields.schema -in @('1','2') -and $fields.ally_rear_entered -eq 'true'
        AllyFrontExited = $fields.schema -in @('1','2') -and $fields.ally_front_exited -eq 'true'
        HomeGate = $fields.schema -eq '3' -and $fields.home_gate -eq 'true'
        HomeUpperCover = $fields.schema -eq '3' -and $fields.home_upper_cover -eq 'true'
        EnemyWallMatches = if ($fields.schema -eq '3') { [int]$numbers.enemy_wall_matches } else { 0 }
        EnemyWallExpected = if ($fields.schema -eq '3') { [int]$numbers.enemy_wall_expected } else { 0 }
        AllyHomeEntered = $fields.schema -in @(3,4) -and $fields.ally_home_entered -eq 'true'
        AllyHomeExited = $fields.schema -in @(3,4) -and $fields.ally_home_exited -eq 'true'
        AllyTraversalTicks = [int]$numbers.ally_traversal_ticks
        CompletionTick = [int]$numbers.completion_tick
        Elapsed = [int]$numbers.elapsed
        Passed = $fields.passed -eq 'true'
        Reason = $fields.reason
        ResourceHomeExact = $fields.schema -in @('2','3') -and $fields.resource_home_exact -eq 'true'
        KnightShop = $fields.schema -in @('2','3') -and $fields.knight_shop -eq 'true'
        ArcherShop = $fields.schema -in @('2','3') -and $fields.archer_shop -eq 'true'
        KnightShopHealthy = $fields.schema -in @('2','3') -and $fields.knight_shop_healthy -eq 'true'
        ArcherShopHealthy = $fields.schema -in @('2','3') -and $fields.archer_shop_healthy -eq 'true'
        BoundedCover = $fields.schema -in @('2','3') -and $fields.bounded_cover -eq 'true'
        RoofCoverMatches = if ($fields.schema -in @('2','3')) { [int]$numbers.roof_cover_matches } else { 0 }
        RoofCoverExpected = if ($fields.schema -in @('2','3')) { [int]$numbers.roof_cover_expected } else { 0 }
        BackingCoverMatches = if ($fields.schema -in @('2','3')) { [int]$numbers.backing_cover_matches } else { 0 }
        BackingCoverExpected = if ($fields.schema -in @('2','3')) { [int]$numbers.backing_cover_expected } else { 0 }
        SideCoverMatches = if ($fields.schema -in @('2','3')) { [int]$numbers.side_cover_matches } else { 0 }
        SideCoverExpected = if ($fields.schema -in @('2','3')) { [int]$numbers.side_cover_expected } else { 0 }
        HomeRouteStarted = $fields.schema -in @('2','3') -and $fields.home_route_started -eq 'true'
        HomeRouteReached = $fields.schema -in @('2','3') -and $fields.home_route_reached -eq 'true'
        KnightShopUsed = $fields.schema -in @('2','3') -and $fields.knight_shop_used -eq 'true'
        ArcherShopUsed = $fields.schema -in @('2','3') -and $fields.archer_shop_used -eq 'true'
        FinalClass = if ($fields.schema -in @('2','3')) { $fields.final_class } else { '' }
        PreAttackPlanComplete = $fields.schema -eq '4' -and $fields.pre_attack_plan_complete -eq 'true'
        FriendlyValidated = $fields.schema -eq '4' -and $fields.friendly_validated -eq 'true'
        EnemyTeam = if ($fields.schema -eq '4') { [int]$numbers.enemy_team } else { -1 }
        EnemyProbeReal = $fields.schema -eq '4' -and $fields.enemy_probe_real -eq 'true'
        EnemyClass = if ($fields.schema -eq '4') { $fields.enemy_class } else { '' }
        EnemyAttackKind = if ($fields.schema -eq '4') { $fields.enemy_attack_kind } else { '' }
        EnemyAttackOrigin = if ($fields.schema -eq '4') { $fields.enemy_attack_origin } else { '' }
        EnemyMovementController = if ($fields.schema -eq '4') { $fields.enemy_movement_controller } else { '' }
        EnemyPlayerBound = $fields.schema -eq '4' -and $fields.enemy_player_bound -eq 'true'
        EnemyPickaxeCommands = if ($fields.schema -eq '4') { [int]$numbers.enemy_pickaxe_commands } else { 0 }
        EnemyContact = $fields.schema -eq '4' -and $fields.enemy_contact -eq 'true'
        EnemyDamageObserved = $fields.schema -eq '4' -and $fields.enemy_damage_observed -eq 'true'
        EnemyEntered = $fields.schema -eq '4' -and $fields.enemy_entered -eq 'true'
        EnemyCrossed = $fields.schema -eq '4' -and $fields.enemy_crossed -eq 'true'
        EnemyInitialBlockers = if ($fields.schema -eq '4') { [int]$numbers.enemy_initial_blockers } else { 0 }
        EnemyFinalBlockers = if ($fields.schema -eq '4') { [int]$numbers.enemy_final_blockers } else { 0 }
        EnemyInitialBlockerHealth = if ($fields.schema -eq '4') { [double]$numbers.enemy_initial_blocker_health } else { 0.0 }
        EnemyProbeTicks = if ($fields.schema -eq '4') { [int]$numbers.enemy_probe_ticks } else { 0 }
        EnemyLastCommandTicks = if ($fields.schema -eq '4') { [int]$numbers.enemy_last_command_ticks } else { 0 }
        EnemyCrossingTicks = if ($fields.schema -eq '4') { [int]$numbers.enemy_crossing_ticks } else { 0 }
        EnemyOutcome = if ($fields.schema -eq '4') { $fields.enemy_outcome } else { '' }
        Source = $source
        Canonical = (($fields.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ' ')
    }
}

$records = @()
foreach ($path in $LogPath) {
    $resolved = Resolve-Path -LiteralPath $path
    $lineNumber = 0
    foreach ($line in [IO.File]::ReadLines($resolved.Path)) {
        $lineNumber++
        $record = ConvertTo-InfrastructureRecord $line "${resolved}:$lineNumber"
        if ($null -ne $record) { $records += $record }
    }
}
if ($records.Count -eq 0) { throw 'No complete supported AIBGYMI result records found.' }

$unique = @()
foreach ($runGroup in ($records | Group-Object Run)) {
    if ([string]::IsNullOrWhiteSpace($runGroup.Name)) { throw 'AIBGYMI result has a blank run id.' }
    $canonical = @($runGroup.Group | Select-Object -ExpandProperty Canonical -Unique)
    if ($canonical.Count -ne 1) {
        $sources = ($runGroup.Group.Source -join ', ')
        throw "Conflicting AIBGYMI records reuse run id '$($runGroup.Name)' in: $sources"
    }
    $unique += $runGroup.Group[0]
}

$summaries = @()
$groups = $unique | Group-Object {
    # Variant is part of the evidence cohort. Pooling control and candidate
    # rows can satisfy the minimum-run gate while hiding either arm's sample
    # count and replacing the actual treatment delta with a meaningless mean.
    "schema$($_.Schema)|$($_.FixtureId)|$($_.FixtureVersion)|$($_.Team)|$($_.TeamSide)|$($_.MapHash)|$($_.MapWidth)x$($_.MapHeight)|$($_.Metric)|$($_.Template)|$($_.Variant)"
}
foreach ($group in $groups) {
    $runs = @($group.Group)
    if ($runs.Count -lt $MinimumRunsPerCohort) {
        throw "Infrastructure cohort '$($group.Name)' has $($runs.Count) unique run(s); requires $MinimumRunsPerCohort."
    }
    $passed = @($runs | Where-Object Passed)
    $fullPhysical = @($runs | Where-Object {
        $common = $_.PhysicalMatches -eq $_.Tasks -and $_.Completed -eq $_.Tasks -and $_.Pending -eq 0 -and
            $_.Reservations -eq 0 -and $_.WorkTiles -eq 0 -and $_.ArchivedComplete
        if (!$common) { return $false }
        if ($_.Schema -eq 4) {
            $expectedBlockers = if ($_.Metric -eq 'flag_gatehouse_enemy_breach_physical') { 2 }
                elseif ($_.Metric -eq 'protected_class_workshops_enemy_breach_physical') {
                    if ($_.Variant -eq 'candidate') { 7 } else { 4 }
                }
                else { return $false }
            $evidence = $_.PreAttackPlanComplete -and $_.FriendlyValidated -and $_.AllyHomeEntered -and
                $_.AllyHomeExited -and $_.EnemyProbeReal -and $_.EnemyPlayerBound -and
                $_.EnemyClass -eq 'builder' -and $_.EnemyAttackKind -eq 'pickaxe' -and
                $_.EnemyAttackOrigin -eq 'client_existing_pickaxe_command' -and
                $_.EnemyMovementController -eq 'server_static_outer_stance_then_bounded_velocity' -and
                $_.EnemyPickaxeCommands -ge 3 -and
                $_.EnemyContact -and $_.EnemyDamageObserved -and
                $_.EnemyInitialBlockers -eq $expectedBlockers -and $_.EnemyFinalBlockers -lt $_.EnemyInitialBlockers
            if (!$evidence) { return $false }
            if ($_.EnemyOutcome -eq 'crossed') {
                return $_.EnemyEntered -and $_.EnemyCrossed -and $_.EnemyCrossingTicks -gt 0
            }
            if ($_.EnemyOutcome -eq 'resisted') {
                return !$_.EnemyCrossed -and $_.EnemyFinalBlockers -gt 0 -and $_.EnemyProbeTicks -ge 900 -and
                    $_.EnemyLastCommandTicks -ge $_.EnemyProbeTicks - 60
            }
            return $false
        }
        if ($_.Metric -eq 'protected_class_workshops_physical') {
            $workshop = $_.Schema -in @(2,3) -and $_.ResourceHomeExact -and $_.KnightShop -and $_.ArcherShop -and
                $_.KnightShopHealthy -and $_.ArcherShopHealthy -and $_.BoundedCover -and
                $_.RoofCoverMatches -eq $_.RoofCoverExpected -and
                $_.BackingCoverMatches -eq $_.BackingCoverExpected -and
                $_.SideCoverMatches -eq $_.SideCoverExpected -and $_.HomeRouteStarted -and
                $_.HomeRouteReached -and $_.KnightShopUsed -and $_.ArcherShopUsed -and $_.FinalClass -eq 'archer'
            if (!$workshop) { return $false }
            if ($_.Schema -eq 2) {
                return $_.RearGate -and $_.FrontGate -and $_.AllyRearEntered -and $_.AllyFrontExited
            }
            return $_.HomeGate -and $_.HomeUpperCover -and
                $_.EnemyWallMatches -eq $_.EnemyWallExpected -and $_.AllyHomeEntered -and $_.AllyHomeExited
        }
        return $_.Schema -eq 1 -and $_.Metric -eq 'flag_gatehouse_physical' -and
            $_.RearGate -and $_.FrontGate -and $_.AllyRearEntered -and $_.AllyFrontExited
    })
    $summary = [pscustomobject]@{
        CohortKey = $group.Name
        Variant = $runs[0].Variant
        Runs = $runs.Count
        PassedRuns = $passed.Count
        FullPhysicalRuns = $fullPhysical.Count
        PassRate = [Math]::Round($passed.Count / [double]$runs.Count, 4)
        MeanCompletionTick = [Math]::Round(($runs | Measure-Object CompletionTick -Average).Average, 3)
        MeanAllyTraversalTicks = [Math]::Round(($runs | Measure-Object AllyTraversalTicks -Average).Average, 3)
        MinAllyTraversalTicks = ($runs | Measure-Object AllyTraversalTicks -Minimum).Minimum
        MaxAllyTraversalTicks = ($runs | Measure-Object AllyTraversalTicks -Maximum).Maximum
        MeanEnemyPickaxeCommands = [Math]::Round(($runs | Measure-Object EnemyPickaxeCommands -Average).Average, 3)
        MeanEnemyInitialBlockerHealth = [Math]::Round(($runs | Measure-Object EnemyInitialBlockerHealth -Average).Average, 3)
        MeanEnemyProbeTicks = [Math]::Round(($runs | Measure-Object EnemyProbeTicks -Average).Average, 3)
        MeanEnemyCrossingTicks = [Math]::Round(($runs | Measure-Object EnemyCrossingTicks -Average).Average, 3)
        EnemyOutcomes = @($runs.EnemyOutcome | Where-Object { $_ } | Sort-Object -Unique)
        RunIds = @($runs.Run | Sort-Object)
        Reasons = @($runs.Reason | Sort-Object -Unique)
        AcceptancePassed = $passed.Count -eq $runs.Count -and $fullPhysical.Count -eq $runs.Count
    }
    $summaries += $summary
}

if ($RequireAllPassed) {
    $failed = @($summaries | Where-Object { !$_.AcceptancePassed })
    if ($failed.Count -ne 0) {
        throw "Infrastructure acceptance failed for cohort(s): $(($failed.CohortKey) -join ', ')"
    }
}

if ($AsJson) { $summaries | ConvertTo-Json -Depth 6 }
else { $summaries | Format-Table CohortKey,Variant,Runs,PassedRuns,FullPhysicalRuns,PassRate,MeanCompletionTick,MeanAllyTraversalTicks,MeanEnemyPickaxeCommands,MeanEnemyProbeTicks,AcceptancePassed -AutoSize }
