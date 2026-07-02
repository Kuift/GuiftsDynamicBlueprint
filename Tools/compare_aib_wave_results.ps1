param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$LogPath,
    [string[]]$Scenarios = @("knight", "archer", "bomb", "mixed"),
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$requiredFields = @(
    "seed", "variant", "scenario", "elapsed", "first_breach", "crossings", "enemy_deaths", "builder_deaths",
    "flag_approaches", "plan_completed_delta", "plan_pending", "plan_damaged", "damage_events", "damage_absorbed_cost", "plan_cost",
    "completion_tick", "first_damage_tick", "structure_lifetime", "builder_travel", "builder_idle_ticks",
    "reservation_conflicts", "replans", "route_preserved", "friendly_route_penalty"
)
$numericProperties = @(
    "Elapsed", "FirstBreach", "Crossings", "EnemyDeaths", "BuilderDeaths", "FlagApproaches", "PlanCompleted",
    "PlanPending", "PlanDamaged", "DamageEvents", "DamageAbsorbedCost", "PlanCost", "CompletionTick", "FirstDamageTick",
    "StructureLifetime", "BuilderTravel", "BuilderIdleTicks", "ReservationConflicts", "Replans", "RoutePreserved",
    "FriendlyRoutePenalty"
)

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
    if ($fields.route_preserved -ne "true" -and $fields.route_preserved -ne "false") {
        throw "Invalid route_preserved value '$($fields.route_preserved)' at $Location"
    }

    [pscustomobject]@{
        Seed = [uint64](ConvertTo-WaveNumber "seed" $fields.seed $Location)
        Variant = $fields.variant
        Scenario = $fields.scenario
        Elapsed = ConvertTo-WaveNumber "elapsed" $fields.elapsed $Location
        FirstBreach = ConvertTo-WaveNumber "first_breach" $fields.first_breach $Location
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
        RoutePreserved = if ($fields.route_preserved -eq "true") { 1.0 } else { 0.0 }
        FriendlyRoutePenalty = ConvertTo-WaveNumber "friendly_route_penalty" $fields.friendly_route_penalty $Location
        Location = $Location
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
foreach ($scenario in $Scenarios) {
    $scenarioRecords = @($records | Where-Object Scenario -eq $scenario)
    if ($scenarioRecords.Count -eq 0) { throw "Missing requested wave scenario: $scenario" }
    $seeds = @($scenarioRecords | Select-Object -ExpandProperty Seed -Unique | Sort-Object)
    foreach ($seed in $seeds) {
        $seedRecords = @($scenarioRecords | Where-Object Seed -eq $seed)
        $controls = @($seedRecords | Where-Object Variant -eq "control")
        $plans = @($seedRecords | Where-Object Variant -eq "plan")
        if ($controls.Count -ne 1 -or $plans.Count -ne 1) {
            throw "Wave pair seed=$seed scenario=$scenario requires exactly one control and one plan; found control=$($controls.Count) plan=$($plans.Count)"
        }
        $control = $controls[0]
        $plan = $plans[0]
        $pair = [ordered]@{ Seed = $seed; Scenario = $scenario }
        foreach ($property in $numericProperties) {
            $pair["${property}Delta"] = [Math]::Round([double]$plan.$property - [double]$control.$property, 3)
        }
        $pairs += [pscustomobject]$pair
    }
}

$aggregate = [ordered]@{
    PairCount = $pairs.Count
    ScenarioCount = $Scenarios.Count
    Seeds = (@($pairs | Select-Object -ExpandProperty Seed -Unique | Sort-Object) -join ",")
}
foreach ($property in $numericProperties) {
    $deltaProperty = "${property}Delta"
    $mean = ($pairs | Measure-Object -Property $deltaProperty -Average).Average
    $aggregate["Mean${property}Delta"] = [Math]::Round([double]$mean, 3)
}
$result = [pscustomobject]@{ Pairs = $pairs; Aggregate = [pscustomobject]$aggregate }

if ($AsJson) {
    $result | ConvertTo-Json -Depth 5
}
else {
    Write-Output "AIB wave pair deltas (plan - control)"
    $pairs | Format-Table -AutoSize
    Write-Output "AIB wave aggregate"
    $result.Aggregate | Format-List
}
