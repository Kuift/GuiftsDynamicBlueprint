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
$numericProperties = @(
    "Elapsed", "Crossings", "EnemyDeaths", "BuilderDeaths", "FlagApproaches", "PlanCompleted",
    "PlanPending", "PlanDamaged", "DamageEvents", "DamageAbsorbedCost", "PlanCost", "CompletionTick", "FirstDamageTick",
    "StructureLifetime", "BuilderTravel", "BuilderIdleTicks", "ReservationConflicts", "Replans", "RoutePreserved",
    "FriendlyRoutePenalty"
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
    $elapsed = ConvertTo-WaveNumber "elapsed" $fields.elapsed $Location
    $firstBreach = ConvertTo-WaveNumber "first_breach" $fields.first_breach $Location
    if ($elapsed -lt 0) { throw "Invalid negative elapsed value '$($fields.elapsed)' at $Location" }
    if ($breached -and ($firstBreach -lt 0 -or $firstBreach -gt $elapsed)) {
        throw "Breached wave has first_breach=$firstBreach outside elapsed interval 0..$elapsed at $Location"
    }
    if (!$breached -and $firstBreach -ne 0) {
        throw "Censored wave must use first_breach=0 when breached=false at $Location"
    }

    [pscustomobject]@{
        FixtureId = $fields.fixture_id
        FixtureVersion = [uint32](ConvertTo-WaveNumber "fixture_version" $fields.fixture_version $Location)
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

$pairs = @()
$contexts = @($records | Group-Object FixtureId, FixtureVersion, Team, TeamSide)
foreach ($context in $contexts) {
    $contextRecords = @($context.Group)
    $identity = "fixture=$($contextRecords[0].FixtureId) version=$($contextRecords[0].FixtureVersion) team=$($contextRecords[0].Team) side=$($contextRecords[0].TeamSide)"
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

        $breachEvidence = Get-BreachEvidence $control $plan
        $gateFailures = @()
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
