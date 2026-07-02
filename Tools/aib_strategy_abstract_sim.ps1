param(
    [int]$Trials = 500,
    [int]$Seed = 1337,
    [switch]$AsJson
)

$ErrorActionPreference = "Stop"
if ($Trials -lt 1) { throw "Trials must be positive" }

$templates = @(
    [pscustomobject]@{ Name = "control"; Cost = 0; BuildTicks = 0; Defense = 0; Cover = 0; RoutePenalty = 0.00; FriendlyTraversalBonus = 0.00 },
    [pscustomobject]@{ Name = "flag_gatehouse"; Cost = 306; BuildTicks = 250; Defense = 105; Cover = 25; RoutePenalty = 0.05; FriendlyTraversalBonus = 0.00 },
    [pscustomobject]@{ Name = "frontline_tower"; Cost = 352; BuildTicks = 310; Defense = 120; Cover = 45; RoutePenalty = 0.08; FriendlyTraversalBonus = 0.00 },
    [pscustomobject]@{ Name = "emergency_barrier"; Cost = 117; BuildTicks = 90; Defense = 45; Cover = 8; RoutePenalty = 0.03; FriendlyTraversalBonus = 0.00 },
    [pscustomobject]@{ Name = "archer_perch"; Cost = 141; BuildTicks = 100; Defense = 20; Cover = 55; RoutePenalty = 0.02; FriendlyTraversalBonus = 0.05 },
    [pscustomobject]@{ Name = "access_route"; Cost = 60; BuildTicks = 70; Defense = 0; Cover = 0; RoutePenalty = -0.12; FriendlyTraversalBonus = 0.30 }
)

function Get-TemplateUtility {
    param(
        [Parameter(Mandatory)]$Template,
        [Parameter(Mandatory)]$Trial,
        [int]$Knights,
        [int]$Archers,
        [double]$Continuity = 0.0
    )

    if ($Trial.Resources -lt $Template.Cost) { return [double]::NegativeInfinity }
    $pressure = $Knights * 8.0 + $Archers * 4.5
    $lineOfSightPressure = $Archers / [Math]::Max(1.0, $Knights + $Archers)
    $chokeMultiplier = if ($Template.Name -in @("flag_gatehouse", "frontline_tower", "emergency_barrier")) { 1.0 + 0.4 * $Trial.Lane.Choke } else { 1.0 }
    $defense = ($Template.Defense + $Template.Cover * $lineOfSightPressure) * $chokeMultiplier
    $threatFit = switch ($Template.Name) {
        "flag_gatehouse" { $Knights * 5.0 }
        "frontline_tower" { $pressure * 0.35 }
        "emergency_barrier" { if ($pressure -ge 70.0) { 55.0 } else { 5.0 } }
        "archer_perch" { $Archers * 7.0 }
        "access_route" { 100.0 * ($Trial.Lane.ElevationCost / [Math]::Max(1.0, $Trial.Lane.TravelCost)) }
        default { 0.0 }
    }
    $routeValue = $Template.FriendlyTraversalBonus * 80.0 - $Template.RoutePenalty * 60.0
    return $defense + $threatFit + $routeValue + $Continuity - $Template.Cost * 0.08 - $Template.BuildTicks * 0.05
}

Get-Random -SetSeed $Seed | Out-Null
$trialSnapshots = for ($i = 0; $i -lt $Trials; $i++) {
    $knights = Get-Random -Minimum 2 -Maximum 10
    $archers = Get-Random -Minimum 0 -Maximum 7
    $builders = Get-Random -Minimum 1 -Maximum 5
    $resources = Get-Random -Minimum 80 -Maximum 850
    $reinforcementKnights = Get-Random -Minimum 0 -Maximum 7
    $reinforcementArchers = Get-Random -Minimum 0 -Maximum 6
    # Build 2-4 abstract traversal lanes. Each lane is a short graph whose
    # edges carry horizontal distance, elevation cost, exposure, and choke.
    $laneCount = Get-Random -Minimum 2 -Maximum 5
    $lanes = for ($laneIndex = 0; $laneIndex -lt $laneCount; $laneIndex++) {
        $nodeCount = Get-Random -Minimum 4 -Maximum 9
        $distance = 0.0
        $elevationCost = 0.0
        $exposureTotal = 0.0
        $choke = 0.0
        for ($edge = 1; $edge -lt $nodeCount; $edge++) {
            $distance += Get-Random -Minimum 28 -Maximum 61
            $elevationCost += Get-Random -Minimum 0 -Maximum 19
            $edgeExposure = (Get-Random -Minimum 0 -Maximum 101) / 100.0
            $edgeChoke = (Get-Random -Minimum 0 -Maximum 101) / 100.0
            $exposureTotal += $edgeExposure
            $choke = [Math]::Max($choke, $edgeChoke)
        }
        [pscustomobject]@{
            Nodes = $nodeCount
            Distance = $distance
            ElevationCost = $elevationCost
            TravelCost = $distance + $elevationCost
            Exposure = $exposureTotal / [Math]::Max(1, $nodeCount - 1)
            Choke = $choke
        }
    }
    [pscustomobject]@{
        Knights = $knights
        Archers = $archers
        Builders = $builders
        Resources = $resources
        ReinforcementKnights = $reinforcementKnights
        ReinforcementArchers = $reinforcementArchers
        Lane = $lanes | Sort-Object TravelCost | Select-Object -First 1
    }
}

$results = foreach ($template in $templates) {
    $breach = 0.0
    $completion = 0.0
    $idle = 0.0
    $travel = 0.0
    $builderDeaths = 0.0
    $lifetime = 0.0
    $friendlySlowdown = 0.0
	$damageAbsorbed = 0.0
	$replans = 0.0

    for ($i = 0; $i -lt $Trials; $i++) {
        $trial = $trialSnapshots[$i]
        $knights = $trial.Knights
        $archers = $trial.Archers
        $builders = $trial.Builders
        $resources = $trial.Resources
        $lane = $trial.Lane
        $laneDistance = $lane.TravelCost
        $terrainExposure = $lane.Exposure
        $pressure = $knights * 8.0 + $archers * 4.5
        $capacity = $builders * (1.0 - 0.35 * $terrainExposure)
        $effectiveBuildTicks = if ($template.BuildTicks -eq 0) { 0.0 } else { $template.BuildTicks / [Math]::Max(0.25, $capacity) }
        $isAffordable = $resources -ge $template.Cost
        $arrivalTicks = $laneDistance / [Math]::Max(1.0, $pressure * 0.055)
        $builtFraction = if (!$isAffordable) { 0.0 } elseif ($effectiveBuildTicks -eq 0) { 1.0 } else { [Math]::Min(1.0, $arrivalTicks / $effectiveBuildTicks) }
        $chokeMultiplier = if ($template.Name -in @("flag_gatehouse", "frontline_tower", "emergency_barrier")) { 1.0 + 0.4 * $lane.Choke } else { 1.0 }
        $lineOfSightPressure = $archers / [Math]::Max(1.0, $knights + $archers)
        $defense = ($template.Defense + $template.Cover * $lineOfSightPressure) * $builtFraction * $chokeMultiplier
        $repairCapacity = if ($template.Name -eq "control") { 0.0 } else { $builders * 2.0 * $builtFraction * ($resources / [Math]::Max(1.0, $template.Cost)) }
        $trialLifetime = ($defense * 5.0 + $repairCapacity) / [Math]::Max(1.0, $pressure)
        $trialBreach = $arrivalTicks + $trialLifetime
        $exposedTravel = $effectiveBuildTicks * $terrainExposure * 0.18
        $deathRisk = [Math]::Min(0.9, ($pressure / 100.0) * $terrainExposure * (1.0 - 0.55 * $builtFraction))

        $breach += $trialBreach
        $completion += $builtFraction
        $idle += [Math]::Max(0.0, $builders - [Math]::Ceiling($template.BuildTicks / 100.0))
        $travel += $exposedTravel
        $builderDeaths += $deathRisk * $builders
        $lifetime += $trialLifetime
		$friendlySlowdown += ($template.RoutePenalty - $template.FriendlyTraversalBonus * ($lane.ElevationCost / [Math]::Max(1.0, $lane.TravelCost))) * $builtFraction
		$damageAbsorbed += $defense

        # Active in-engine plans are not replaced merely because a somewhat
        # higher-scoring candidate appears. A replacement is counted only when
        # reinforcement pressure collapses the frontline and makes a non-
        # emergency plan strategically insufficient.
        if ($template.Name -ne "control" -and $isAffordable -and $builtFraction -lt 1.0) {
            $shiftedKnights = $knights + $trial.ReinforcementKnights
            $shiftedArchers = $archers + $trial.ReinforcementArchers
            $shiftedPressure = $shiftedKnights * 8.0 + $shiftedArchers * 4.5
            $frontlineCollapsing = $shiftedPressure -ge 70.0
            $currentUtility = Get-TemplateUtility -Template $template -Trial $trial -Knights $shiftedKnights -Archers $shiftedArchers -Continuity (15.0 * $builtFraction)
            $emergency = $templates | Where-Object Name -eq "emergency_barrier" | Select-Object -First 1
            $emergencyUtility = if ($null -eq $emergency) { [double]::NegativeInfinity } else {
                (Get-TemplateUtility -Template $emergency -Trial $trial -Knights $shiftedKnights -Archers $shiftedArchers) + 100.0
            }
            if ($frontlineCollapsing -and $template.Name -ne "emergency_barrier" -and
                $trial.Resources -ge $emergency.Cost -and $emergencyUtility -gt $currentUtility) {
                $replans += 1.0
            }
        }
    }

    [pscustomobject]@{
        Template = $template.Name
        Trials = $Trials
        MeanBreachTicks = [Math]::Round($breach / $Trials, 2)
        MeanCompletion = [Math]::Round($completion / $Trials, 3)
        MeanBuilderTravel = [Math]::Round($travel / $Trials, 2)
        MeanBuilderIdle = [Math]::Round($idle / $Trials, 2)
        MeanBuilderDeaths = [Math]::Round($builderDeaths / $Trials, 3)
        MeanStructureLifetime = [Math]::Round($lifetime / $Trials, 2)
        MeanFriendlyRouteSlowdown = [Math]::Round($friendlySlowdown / $Trials, 3)
		MeanDamageAbsorbed = [Math]::Round($damageAbsorbed / $Trials, 2)
		MeanReplans = [Math]::Round($replans / $Trials, 3)
        MaterialCost = $template.Cost
    }
}

if ($AsJson) {
    $results | ConvertTo-Json -Depth 4
} else {
    $results | Format-Table -AutoSize
}
