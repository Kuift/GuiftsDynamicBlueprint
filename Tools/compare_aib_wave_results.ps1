param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$LogPath,
    [string[]]$Scenarios = @("knight", "archer", "bomb", "mixed"),
    [Alias("RequireAcceptance", "EnforceAcceptanceGates")]
    [switch]$RequireAcceptanceGates,
    [double]$MaxFriendlyRoutePenaltyIncrease = 0.10,
    [Alias("MinimumSeedsPerScenario")]
    [ValidateRange(1, 1000000)]
    [int]$MinimumSeedsPerCohort = 3,
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"
if ($MaxFriendlyRoutePenaltyIncrease -lt 0.0) {
    throw "MaxFriendlyRoutePenaltyIncrease must be non-negative"
}
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$requiredFields = @(
    "fixture_id", "fixture_version", "team", "team_side", "seed", "variant", "scenario", "initial_fingerprint", "measurement_fingerprint",
    "elapsed", "breached", "first_breach", "crossings", "enemy_deaths", "builder_deaths",
    "flag_approaches", "plan_completed_delta", "plan_pending", "plan_damaged", "damage_events", "damage_absorbed_cost", "plan_cost",
    "completion_tick", "first_damage_tick", "structure_lifetime", "builder_travel", "builder_idle_ticks",
    "reservation_conflicts", "replans", "route_preserved", "friendly_route_penalty"
)
$fixtureV4Fields = @(
    "run_id", "pressure_valid", "driver", "fixture_template", "fixture_anchor_x", "fixture_anchor_y",
    "fixture_direction", "fixture_tasks", "fixture_task_hash", "fixture_corridor_hash",
    "approach_start_x", "approach_start_y", "breach_target_x", "breach_target_y",
    "spawn_limit", "spawned", "pressure_approaches", "attack_ticks", "arrows_fired",
    "bombs_thrown", "bombs_detonated", "bomb_origin", "minimum_target_distance"
)
$compositionDriverFields = @("archers_spawned", "bomb_carriers")
$driverV4Fields = @(
    "outcomes_resolved", "outcome_contract", "duplicate_death_callbacks", "post_cross_deaths", "duplicate_bomb_callbacks"
)
$numericProperties = @(
    "Elapsed", "Crossings", "EnemyDeaths", "BuilderDeaths", "FlagApproaches", "PlanCompleted",
    "PlanPending", "PlanDamaged", "DamageEvents", "DamageAbsorbedCost", "PlanCost", "CompletionTick", "FirstDamageTick",
    "StructureLifetime", "BuilderTravel", "BuilderIdleTicks", "ReservationConflicts", "Replans", "RoutePreserved",
    "FriendlyRoutePenalty", "PressureApproaches", "AttackTicks", "ArrowsFired", "BombsThrown", "BombsDetonated",
    "MinimumTargetDistance", "OutcomesResolved", "DuplicateDeathCallbacks", "PostCrossDeaths", "DuplicateBombCallbacks"
)

function ConvertTo-WaveBoolean {
    param([string]$Name, [string]$Value, [string]$Location)
    if ($Value -eq "true") { return $true }
    if ($Value -eq "false") { return $false }
    throw "Invalid $Name value '$Value' at $Location; expected true or false"
}

function ConvertTo-WaveNumber {
    param([string]$Name, [string]$Value, [string]$Location)
    $parsed = 0.0
    if (![double]::TryParse($Value, [System.Globalization.NumberStyles]::Float, $culture, [ref]$parsed)) {
        throw "Invalid numeric wave metric '$Name=$Value' at $Location"
    }
    return $parsed
}

function ConvertFrom-WaveResultLine {
    param([string]$Line, [string]$Location)
    if ($Line -notmatch "\[AIBEVT\].*\bsource=strategy\b.*\baction=wave_result\b") { return $null }

    $fields = @{}
    foreach ($match in [regex]::Matches($Line, "(?<key>[A-Za-z_]+)=(?<value>\S+)")) {
        $fields[$match.Groups["key"].Value] = $match.Groups["value"].Value
    }
    foreach ($field in $requiredFields) {
        if (!$fields.ContainsKey($field)) { throw "Missing wave metric '$field' at $Location" }
    }
    $fixtureVersion = [uint32](ConvertTo-WaveNumber "fixture_version" $fields.fixture_version $Location)
    if ($fixtureVersion -ge 4) {
        foreach ($field in $fixtureV4Fields) {
            if (!$fields.ContainsKey($field)) { throw "Missing fixture-v4 wave metric '$field' at $Location" }
        }
    }
    if ($fields.variant -ne "control" -and $fields.variant -ne "plan") {
        throw "Invalid wave variant '$($fields.variant)' at $Location"
    }
    if ($fields.team_side -ne "left" -and $fields.team_side -ne "right") {
        throw "Invalid team_side '$($fields.team_side)' at $Location; expected left or right"
    }
    if ([string]::IsNullOrWhiteSpace($fields.fixture_id)) { throw "Empty fixture_id at $Location" }
    if ([string]::IsNullOrWhiteSpace($fields.initial_fingerprint)) { throw "Empty initial_fingerprint at $Location" }
    if ([string]::IsNullOrWhiteSpace($fields.measurement_fingerprint)) { throw "Empty measurement_fingerprint at $Location" }

    $breached = ConvertTo-WaveBoolean "breached" $fields.breached $Location
    $routePreserved = ConvertTo-WaveBoolean "route_preserved" $fields.route_preserved $Location
    $pressureValid = if ($fixtureVersion -ge 4) { ConvertTo-WaveBoolean "pressure_valid" $fields.pressure_valid $Location } else { $false }
    $elapsed = ConvertTo-WaveNumber "elapsed" $fields.elapsed $Location
    $firstBreach = ConvertTo-WaveNumber "first_breach" $fields.first_breach $Location
    if ($elapsed -lt 0) { throw "Invalid negative elapsed value '$($fields.elapsed)' at $Location" }
    if ($breached -and ($firstBreach -lt 0 -or $firstBreach -gt $elapsed)) {
        throw "Breached wave has first_breach=$firstBreach outside elapsed interval 0..$elapsed at $Location"
    }
    if (!$breached -and $firstBreach -ne 0) {
        throw "Censored wave must use first_breach=0 when breached=false at $Location"
    }
    if ($fixtureVersion -ge 4) {
        if ([string]::IsNullOrWhiteSpace($fields.run_id) -or [string]::IsNullOrWhiteSpace($fields.fixture_template)) {
            throw "Fixture-v4 wave must identify run_id and fixture_template at $Location"
        }
        if ($fields.driver -notin @("grounded_candidate_corridor_v1", "grounded_candidate_corridor_v2_opening_archer_shot", "grounded_candidate_corridor_v3_mixed_lead_archer", "grounded_candidate_corridor_v4_exclusive_spawn_outcomes")) {
            throw "Unsupported fixture-v4 wave driver '$($fields.driver)' at $Location"
        }
        if ($fields.driver -in @("grounded_candidate_corridor_v3_mixed_lead_archer", "grounded_candidate_corridor_v4_exclusive_spawn_outcomes")) {
            foreach ($field in $compositionDriverFields) {
                if (!$fields.ContainsKey($field)) { throw "Missing wave composition metric '$field' at $Location" }
            }
        }
        if ($fields.driver -eq "grounded_candidate_corridor_v4_exclusive_spawn_outcomes") {
            foreach ($field in $driverV4Fields) {
                if (!$fields.ContainsKey($field)) { throw "Missing driver-v4 wave metric '$field' at $Location" }
            }
        }
        if ($fields.bomb_origin -ne "server_wave_throw_with_real_explosion") {
            throw "Unsupported fixture-v4 bomb origin '$($fields.bomb_origin)' at $Location"
        }
        $spawnLimit = ConvertTo-WaveNumber "spawn_limit" $fields.spawn_limit $Location
        $spawned = ConvertTo-WaveNumber "spawned" $fields.spawned $Location
        $pressureApproaches = ConvertTo-WaveNumber "pressure_approaches" $fields.pressure_approaches $Location
        $attackTicks = ConvertTo-WaveNumber "attack_ticks" $fields.attack_ticks $Location
        $arrowsFired = ConvertTo-WaveNumber "arrows_fired" $fields.arrows_fired $Location
        $bombsThrown = ConvertTo-WaveNumber "bombs_thrown" $fields.bombs_thrown $Location
        $bombsDetonated = ConvertTo-WaveNumber "bombs_detonated" $fields.bombs_detonated $Location
        $crossings = ConvertTo-WaveNumber "crossings" $fields.crossings $Location
        $enemyDeaths = ConvertTo-WaveNumber "enemy_deaths" $fields.enemy_deaths $Location
        if ($fields.driver -in @("grounded_candidate_corridor_v3_mixed_lead_archer", "grounded_candidate_corridor_v4_exclusive_spawn_outcomes")) {
            $archersSpawned = ConvertTo-WaveNumber "archers_spawned" $fields.archers_spawned $Location
            $bombCarriers = ConvertTo-WaveNumber "bomb_carriers" $fields.bomb_carriers $Location
            if (($fields.scenario -eq "knight" -and ($archersSpawned -ne 0 -or $bombCarriers -ne 0)) -or
                ($fields.scenario -eq "archer" -and ($archersSpawned -ne 7 -or $bombCarriers -ne 0)) -or
                ($fields.scenario -eq "bomb" -and ($archersSpawned -ne 0 -or $bombCarriers -ne 7)) -or
                ($fields.scenario -eq "mixed" -and ($archersSpawned -lt 1 -or $bombCarriers -lt 1))) {
                throw "Invalid wave-driver scenario composition at $Location"
            }
        }
        if ($fields.driver -eq "grounded_candidate_corridor_v4_exclusive_spawn_outcomes") {
            $outcomesResolved = ConvertTo-WaveNumber "outcomes_resolved" $fields.outcomes_resolved $Location
            $duplicateDeathCallbacks = ConvertTo-WaveNumber "duplicate_death_callbacks" $fields.duplicate_death_callbacks $Location
            $postCrossDeaths = ConvertTo-WaveNumber "post_cross_deaths" $fields.post_cross_deaths $Location
            $duplicateBombCallbacks = ConvertTo-WaveNumber "duplicate_bomb_callbacks" $fields.duplicate_bomb_callbacks $Location
            if ($fields.outcome_contract -ne "exclusive_spawn_index_v1") {
                throw "Unsupported driver-v4 outcome contract '$($fields.outcome_contract)' at $Location"
            }
            if ($crossings -lt 0 -or $enemyDeaths -lt 0 -or $outcomesResolved -lt 0 -or
                $crossings -ne [Math]::Truncate($crossings) -or $enemyDeaths -ne [Math]::Truncate($enemyDeaths) -or
                $outcomesResolved -ne [Math]::Truncate($outcomesResolved) -or
                $crossings -gt $spawned -or $enemyDeaths -gt $spawned -or
                $outcomesResolved -ne ($crossings + $enemyDeaths) -or $outcomesResolved -gt $spawned) {
                throw "Invalid driver-v4 mutually exclusive attacker outcomes at $Location"
            }
            if ($bombsDetonated -lt 0 -or $bombsDetonated -gt $bombsThrown -or
                $duplicateDeathCallbacks -lt 0 -or $postCrossDeaths -lt 0 -or $duplicateBombCallbacks -lt 0 -or
                $duplicateDeathCallbacks -ne [Math]::Truncate($duplicateDeathCallbacks) -or
                $postCrossDeaths -ne [Math]::Truncate($postCrossDeaths) -or
                $duplicateBombCallbacks -ne [Math]::Truncate($duplicateBombCallbacks)) {
                throw "Invalid driver-v4 death/detonation diagnostics at $Location"
            }
        }
        if (!$pressureValid -or $spawnLimit -ne 7 -or $spawned -ne $spawnLimit -or $pressureApproaches -le 0 -or $attackTicks -le 0) {
            throw "Invalid fixture-v4 fixed pressure at $Location"
        }
        if ($fields.scenario -in @("archer", "mixed") -and $arrowsFired -le 0) {
            throw "Fixture-v4 $($fields.scenario) wave has no production archer shot at $Location"
        }
        if ($fields.scenario -in @("bomb", "mixed") -and $bombsThrown -le 0) {
            throw "Fixture-v4 $($fields.scenario) wave has no real bomb throw at $Location"
        }
        $startX = ConvertTo-WaveNumber "approach_start_x" $fields.approach_start_x $Location
        $startY = ConvertTo-WaveNumber "approach_start_y" $fields.approach_start_y $Location
        $targetX = ConvertTo-WaveNumber "breach_target_x" $fields.breach_target_x $Location
        $targetY = ConvertTo-WaveNumber "breach_target_y" $fields.breach_target_y $Location
        $corridorLength = [Math]::Sqrt([Math]::Pow($startX - $targetX, 2) + [Math]::Pow($startY - $targetY, 2))
        if ($corridorLength -lt 64.0) { throw "Fixture-v4 approach corridor is shorter than 64 pixels at $Location" }
    }

    $driverSignatureFields = @()
    if ($fixtureVersion -ge 4 -and $fields.driver -in @("grounded_candidate_corridor_v3_mixed_lead_archer", "grounded_candidate_corridor_v4_exclusive_spawn_outcomes")) {
        $driverSignatureFields += $compositionDriverFields
    }
    if ($fixtureVersion -ge 4 -and $fields.driver -eq "grounded_candidate_corridor_v4_exclusive_spawn_outcomes") {
        $driverSignatureFields += $driverV4Fields
    }

    [pscustomobject]@{
        RunId = if ($fixtureVersion -ge 4) { $fields.run_id } else { "" }
        FixtureId = $fields.fixture_id
        FixtureVersion = $fixtureVersion
        Team = [uint32](ConvertTo-WaveNumber "team" $fields.team $Location)
        TeamSide = $fields.team_side
        Seed = [uint64](ConvertTo-WaveNumber "seed" $fields.seed $Location)
        Variant = $fields.variant
        Scenario = $fields.scenario
        InitialFingerprint = $fields.initial_fingerprint
        MeasurementFingerprint = $fields.measurement_fingerprint
        Elapsed = $elapsed
        Breached = $breached
        FirstBreach = $firstBreach
        Crossings = ConvertTo-WaveNumber "crossings" $fields.crossings $Location
        EnemyDeaths = ConvertTo-WaveNumber "enemy_deaths" $fields.enemy_deaths $Location
        BuilderDeaths = ConvertTo-WaveNumber "builder_deaths" $fields.builder_deaths $Location
        FlagApproaches = ConvertTo-WaveNumber "flag_approaches" $fields.flag_approaches $Location
        PlanCompleted = ConvertTo-WaveNumber "plan_completed_delta" $fields.plan_completed_delta $Location
        PlanPending = ConvertTo-WaveNumber "plan_pending" $fields.plan_pending $Location
        PlanDamaged = ConvertTo-WaveNumber "plan_damaged" $fields.plan_damaged $Location
        DamageEvents = ConvertTo-WaveNumber "damage_events" $fields.damage_events $Location
        DamageAbsorbedCost = ConvertTo-WaveNumber "damage_absorbed_cost" $fields.damage_absorbed_cost $Location
        PlanCost = ConvertTo-WaveNumber "plan_cost" $fields.plan_cost $Location
        CompletionTick = ConvertTo-WaveNumber "completion_tick" $fields.completion_tick $Location
        FirstDamageTick = ConvertTo-WaveNumber "first_damage_tick" $fields.first_damage_tick $Location
        StructureLifetime = ConvertTo-WaveNumber "structure_lifetime" $fields.structure_lifetime $Location
        BuilderTravel = ConvertTo-WaveNumber "builder_travel" $fields.builder_travel $Location
        BuilderIdleTicks = ConvertTo-WaveNumber "builder_idle_ticks" $fields.builder_idle_ticks $Location
        ReservationConflicts = ConvertTo-WaveNumber "reservation_conflicts" $fields.reservation_conflicts $Location
        Replans = ConvertTo-WaveNumber "replans" $fields.replans $Location
        RoutePreserved = if ($routePreserved) { 1.0 } else { 0.0 }
        FriendlyRoutePenalty = ConvertTo-WaveNumber "friendly_route_penalty" $fields.friendly_route_penalty $Location
        PressureValid = $pressureValid
        Driver = if ($fixtureVersion -ge 4) { $fields.driver } else { "legacy" }
        FixtureTemplate = if ($fixtureVersion -ge 4) { $fields.fixture_template } else { "" }
        FixtureAnchorX = if ($fixtureVersion -ge 4) { ConvertTo-WaveNumber "fixture_anchor_x" $fields.fixture_anchor_x $Location } else { 0 }
        FixtureAnchorY = if ($fixtureVersion -ge 4) { ConvertTo-WaveNumber "fixture_anchor_y" $fields.fixture_anchor_y $Location } else { 0 }
        FixtureDirection = if ($fixtureVersion -ge 4) { ConvertTo-WaveNumber "fixture_direction" $fields.fixture_direction $Location } else { 0 }
        FixtureTasks = if ($fixtureVersion -ge 4) { ConvertTo-WaveNumber "fixture_tasks" $fields.fixture_tasks $Location } else { 0 }
        FixtureTaskHash = if ($fixtureVersion -ge 4) { $fields.fixture_task_hash } else { "" }
        FixtureCorridorHash = if ($fixtureVersion -ge 4) { $fields.fixture_corridor_hash } else { "" }
        ApproachStartX = if ($fixtureVersion -ge 4) { ConvertTo-WaveNumber "approach_start_x" $fields.approach_start_x $Location } else { 0 }
        ApproachStartY = if ($fixtureVersion -ge 4) { ConvertTo-WaveNumber "approach_start_y" $fields.approach_start_y $Location } else { 0 }
        BreachTargetX = if ($fixtureVersion -ge 4) { ConvertTo-WaveNumber "breach_target_x" $fields.breach_target_x $Location } else { 0 }
        BreachTargetY = if ($fixtureVersion -ge 4) { ConvertTo-WaveNumber "breach_target_y" $fields.breach_target_y $Location } else { 0 }
        SpawnLimit = if ($fixtureVersion -ge 4) { ConvertTo-WaveNumber "spawn_limit" $fields.spawn_limit $Location } else { 0 }
        Spawned = if ($fixtureVersion -ge 4) { ConvertTo-WaveNumber "spawned" $fields.spawned $Location } else { 0 }
        PressureApproaches = if ($fixtureVersion -ge 4) { ConvertTo-WaveNumber "pressure_approaches" $fields.pressure_approaches $Location } else { 0 }
        AttackTicks = if ($fixtureVersion -ge 4) { ConvertTo-WaveNumber "attack_ticks" $fields.attack_ticks $Location } else { 0 }
        ArrowsFired = if ($fixtureVersion -ge 4) { ConvertTo-WaveNumber "arrows_fired" $fields.arrows_fired $Location } else { 0 }
        BombsThrown = if ($fixtureVersion -ge 4) { ConvertTo-WaveNumber "bombs_thrown" $fields.bombs_thrown $Location } else { 0 }
        BombsDetonated = if ($fixtureVersion -ge 4) { ConvertTo-WaveNumber "bombs_detonated" $fields.bombs_detonated $Location } else { 0 }
        ArchersSpawned = if ($fields.ContainsKey("archers_spawned")) { ConvertTo-WaveNumber "archers_spawned" $fields.archers_spawned $Location } else { 0 }
        BombCarriers = if ($fields.ContainsKey("bomb_carriers")) { ConvertTo-WaveNumber "bomb_carriers" $fields.bomb_carriers $Location } else { 0 }
        MinimumTargetDistance = if ($fixtureVersion -ge 4) { ConvertTo-WaveNumber "minimum_target_distance" $fields.minimum_target_distance $Location } else { 0 }
        BombOrigin = if ($fixtureVersion -ge 4) { $fields.bomb_origin } else { "legacy" }
        OutcomesResolved = if ($fields.ContainsKey("outcomes_resolved")) { ConvertTo-WaveNumber "outcomes_resolved" $fields.outcomes_resolved $Location } else { 0 }
        DuplicateDeathCallbacks = if ($fields.ContainsKey("duplicate_death_callbacks")) { ConvertTo-WaveNumber "duplicate_death_callbacks" $fields.duplicate_death_callbacks $Location } else { 0 }
        PostCrossDeaths = if ($fields.ContainsKey("post_cross_deaths")) { ConvertTo-WaveNumber "post_cross_deaths" $fields.post_cross_deaths $Location } else { 0 }
        DuplicateBombCallbacks = if ($fields.ContainsKey("duplicate_bomb_callbacks")) { ConvertTo-WaveNumber "duplicate_bomb_callbacks" $fields.duplicate_bomb_callbacks $Location } else { 0 }
        Signature = (($requiredFields + ($fixtureVersion -ge 4 ? $fixtureV4Fields : @()) + $driverSignatureFields) |
            ForEach-Object { "$_=$($fields[$_])" }) -join "|"
        Location = $Location
    }
}

function Get-BreachEvidence {
    param($Control, $Plan)

    $status = ""
    $gatePassed = $false
    $firstBreachDelta = $null
    if ($Control.Breached -and $Plan.Breached) {
        $firstBreachDelta = [Math]::Round([double]$Plan.FirstBreach - [double]$Control.FirstBreach, 3)
        if ($firstBreachDelta -gt 0) { $status = "plan_delayed_breach" }
        elseif ($firstBreachDelta -eq 0) { $status = "same_breach_time" }
        else { $status = "plan_earlier_breach" }
        $gatePassed = $firstBreachDelta -ge 0
    }
    elseif ($Control.Breached -and !$Plan.Breached) {
        if ($Plan.Elapsed -ge $Control.FirstBreach) {
            $status = "plan_censored_after_control_breach"
            $gatePassed = $true
        }
        else {
            $status = "plan_censored_before_control_breach"
        }
    }
    elseif (!$Control.Breached -and $Plan.Breached) {
        if ($Control.Elapsed -ge $Plan.FirstBreach) {
            $status = "plan_breached_within_control_observation"
        }
        else {
            $status = "control_censored_before_plan_breach"
        }
    }
    else {
        if ($Plan.Elapsed -ge $Control.Elapsed) {
            $status = "both_censored_plan_observed_as_long"
            $gatePassed = $true
        }
        else {
            $status = "both_censored_plan_observed_shorter"
        }
    }

    return [pscustomobject]@{
        Status = $status
        GatePassed = $gatePassed
        FirstBreachDelta = $firstBreachDelta
    }
}

if ($Scenarios.Count -eq 0) { throw "At least one required scenario must be supplied" }
$scenarioSet = @{}
foreach ($scenario in $Scenarios) {
    if ([string]::IsNullOrWhiteSpace($scenario)) { throw "Scenario names cannot be empty" }
    if ($scenarioSet.ContainsKey($scenario)) { throw "Duplicate requested scenario: $scenario" }
    $scenarioSet[$scenario] = $true
}

$records = @()
foreach ($path in $LogPath) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Log not found: $path" }
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $path) {
        $lineNumber++
        $record = ConvertFrom-WaveResultLine $line "${path}:$lineNumber"
        if ($null -ne $record -and $scenarioSet.ContainsKey($record.Scenario)) { $records += $record }
    }
}
if ($records.Count -eq 0) { throw "No requested [AIBEVT] strategy wave_result records found" }

$deduplicated = @()
foreach ($runGroup in @($records | Group-Object { if ($_.FixtureVersion -ge 4) { "v4|$($_.RunId)" } else { "legacy|$($_.Location)" } })) {
    $signatures = @($runGroup.Group | Select-Object -ExpandProperty Signature -Unique)
    if ($signatures.Count -ne 1) {
        throw "Conflicting wave_result records reuse run_id '$($runGroup.Group[0].RunId)'"
    }
    $deduplicated += $runGroup.Group[0]
}
$records = $deduplicated

$pairs = @()
$contexts = @($records | Group-Object FixtureId, FixtureVersion, Team, TeamSide)
foreach ($context in $contexts) {
    $contextRecords = @($context.Group)
    $identity = "fixture=$($contextRecords[0].FixtureId) version=$($contextRecords[0].FixtureVersion) team=$($contextRecords[0].Team) side=$($contextRecords[0].TeamSide)"
    if ($contextRecords[0].FixtureVersion -ge 4) {
        $drivers = @($contextRecords | Select-Object -ExpandProperty Driver -Unique)
        if ($drivers.Count -ne 1) {
            throw "Wave cohort $identity mixes driver contracts: $($drivers -join ',')"
        }
    }
    foreach ($scenario in $Scenarios) {
        $scenarioRecords = @($contextRecords | Where-Object Scenario -eq $scenario)
        if ($scenarioRecords.Count -eq 0) { throw "Missing requested wave scenario '$scenario' for $identity" }
        $seeds = @($scenarioRecords | Select-Object -ExpandProperty Seed -Unique | Sort-Object)
        if ($seeds.Count -lt $MinimumSeedsPerCohort) {
            throw "Wave cohort $identity scenario=$scenario requires at least $MinimumSeedsPerCohort distinct seeds; found $($seeds.Count)"
        }
        foreach ($seed in $seeds) {
            $seedRecords = @($scenarioRecords | Where-Object Seed -eq $seed)
        $controls = @($seedRecords | Where-Object Variant -eq "control")
        $plans = @($seedRecords | Where-Object Variant -eq "plan")
        if ($controls.Count -ne 1 -or $plans.Count -ne 1) {
            throw "Wave pair $identity seed=$seed scenario=$scenario requires exactly one control and one plan; found control=$($controls.Count) plan=$($plans.Count)"
        }
        $control = $controls[0]
        $plan = $plans[0]
        if ($control.InitialFingerprint -cne $plan.InitialFingerprint) {
            throw "Wave pair $identity seed=$seed scenario=$scenario has mismatched initial_fingerprint values: control='$($control.InitialFingerprint)' plan='$($plan.InitialFingerprint)'"
        }
        if ($control.FixtureVersion -ge 4) {
            foreach ($field in @("Driver", "FixtureTemplate", "FixtureAnchorX", "FixtureAnchorY", "FixtureDirection",
                "FixtureTasks", "FixtureTaskHash", "FixtureCorridorHash", "ApproachStartX", "ApproachStartY",
                "BreachTargetX", "BreachTargetY", "SpawnLimit", "ArchersSpawned", "BombCarriers")) {
                if ($control.$field -cne $plan.$field) {
                    throw "Wave pair $identity seed=$seed scenario=$scenario has mismatched fixture field ${field}: control='$($control.$field)' plan='$($plan.$field)'"
                }
            }
        }

        $breachEvidence = Get-BreachEvidence $control $plan
        $gateFailures = @()
        if ($control.FixtureVersion -ge 4 -and !$control.Breached) { $gateFailures += "control_no_breach" }
        if ($plan.Crossings -gt $control.Crossings) { $gateFailures += "crossings" }
        if (!$breachEvidence.GatePassed) { $gateFailures += "breach:$($breachEvidence.Status)" }
        if ($plan.RoutePreserved -lt $control.RoutePreserved -or
            $plan.FriendlyRoutePenalty -gt $control.FriendlyRoutePenalty + $MaxFriendlyRoutePenaltyIncrease + 0.000000001) {
            $gateFailures += "friendly_route"
        }
        if ($plan.BuilderDeaths -gt $control.BuilderDeaths) { $gateFailures += "builder_deaths" }

        $pair = [ordered]@{
            FixtureId = $control.FixtureId
            FixtureVersion = $control.FixtureVersion
            Driver = $control.Driver
            Team = $control.Team
            TeamSide = $control.TeamSide
            Seed = $seed
            Scenario = $scenario
            InitialFingerprint = $control.InitialFingerprint
            ControlMeasurementFingerprint = $control.MeasurementFingerprint
            PlanMeasurementFingerprint = $plan.MeasurementFingerprint
            ControlBreached = [bool]$control.Breached
            PlanBreached = [bool]$plan.Breached
            ControlCensored = ![bool]$control.Breached
            PlanCensored = ![bool]$plan.Breached
            ControlFirstBreach = if ($control.Breached) { [double]$control.FirstBreach } else { $null }
            PlanFirstBreach = if ($plan.Breached) { [double]$plan.FirstBreach } else { $null }
            BreachEvidence = $breachEvidence.Status
            BreachedDelta = [int]$plan.Breached - [int]$control.Breached
            FirstBreachDelta = $breachEvidence.FirstBreachDelta
            CrossingsGatePassed = $plan.Crossings -le $control.Crossings
            BreachGatePassed = [bool]$breachEvidence.GatePassed
            FriendlyRouteGatePassed = ($plan.RoutePreserved -ge $control.RoutePreserved -and
                $plan.FriendlyRoutePenalty -le $control.FriendlyRoutePenalty + $MaxFriendlyRoutePenaltyIncrease + 0.000000001)
            FriendlyRoutePenaltyAllowance = $MaxFriendlyRoutePenaltyIncrease
            BuilderDeathsGatePassed = $plan.BuilderDeaths -le $control.BuilderDeaths
            AcceptancePassed = $gateFailures.Count -eq 0
            AcceptanceFailures = $gateFailures -join ","
        }
        foreach ($property in $numericProperties) {
            $pair["${property}Delta"] = [Math]::Round([double]$plan.$property - [double]$control.$property, 3)
        }
        $pairs += [pscustomobject]$pair
        }
    }
}

$aggregate = [ordered]@{
    PairCount = $pairs.Count
    CohortCount = $contexts.Count
    ScenarioCount = $Scenarios.Count
    MinimumSeedsPerCohort = $MinimumSeedsPerCohort
    FixtureIds = (@($pairs | Select-Object -ExpandProperty FixtureId -Unique | Sort-Object) -join ",")
    Drivers = (@($pairs | Select-Object -ExpandProperty Driver -Unique | Sort-Object) -join ",")
    TeamSides = (@($pairs | Select-Object -ExpandProperty TeamSide -Unique | Sort-Object) -join ",")
    Seeds = (@($pairs | Select-Object -ExpandProperty Seed -Unique | Sort-Object) -join ",")
    BothBreachedPairCount = @($pairs | Where-Object { $_.ControlBreached -and $_.PlanBreached }).Count
    BothCensoredPairCount = @($pairs | Where-Object { $_.ControlCensored -and $_.PlanCensored }).Count
    PlanOnlyBreachedPairCount = @($pairs | Where-Object { $_.ControlCensored -and $_.PlanBreached }).Count
    ControlOnlyBreachedPairCount = @($pairs | Where-Object { $_.ControlBreached -and $_.PlanCensored }).Count
    AcceptancePassed = @($pairs | Where-Object { !$_.AcceptancePassed }).Count -eq 0
    AcceptanceFailureCount = @($pairs | Where-Object { !$_.AcceptancePassed }).Count
}
$timedBreachPairs = @($pairs | Where-Object { $null -ne $_.FirstBreachDelta })
$aggregate["MeanBreachedDelta"] = [Math]::Round([double](($pairs | Measure-Object -Property BreachedDelta -Average).Average), 3)
$aggregate["MeanFirstBreachDelta"] = if ($timedBreachPairs.Count -gt 0) {
    [Math]::Round([double](($timedBreachPairs | Measure-Object -Property FirstBreachDelta -Average).Average), 3)
} else { $null }
foreach ($property in $numericProperties) {
    $deltaProperty = "${property}Delta"
    $mean = ($pairs | Measure-Object -Property $deltaProperty -Average).Average
    $aggregate["Mean${property}Delta"] = [Math]::Round([double]$mean, 3)
}
$result = [pscustomobject]@{ Pairs = $pairs; Aggregate = [pscustomobject]$aggregate }

if ($RequireAcceptanceGates -and !$result.Aggregate.AcceptancePassed) {
    $failureSummary = @($pairs | Where-Object { !$_.AcceptancePassed } | ForEach-Object {
        "seed=$($_.Seed) scenario=$($_.Scenario) failures=$($_.AcceptanceFailures)"
    }) -join "; "
    throw "AIB wave semantic acceptance gates failed: $failureSummary"
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 5
}
else {
    Write-Output "AIB wave pair deltas (plan - control)"
    $pairs | Format-Table -AutoSize
    Write-Output "AIB wave aggregate"
    $result.Aggregate | Format-List
}
