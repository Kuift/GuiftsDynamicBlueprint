$ErrorActionPreference = "Stop"
$compare = Join-Path $PSScriptRoot "compare_aib_wave_results.ps1"
$logPath = Join-Path $env:TEMP ("aib-wave-compare-" + [guid]::NewGuid().ToString("N") + ".log")

function New-WaveLine {
    param([int]$Sequence, [string]$Scenario, [string]$Variant, [int]$Offset, [hashtable]$Overrides = @{})

    $values = @{
        FixtureId = "flat_ctf"
        FixtureVersion = 1
        Team = 0
        TeamSide = "left"
        Seed = 77
        Fingerprint = "canonical-flat-ctf"
        MeasurementFingerprint = "measurement-$Scenario-$Variant"
        Elapsed = 1200
        Breached = "true"
        Crossings = if ($Variant -eq "plan") { 2 + $Offset } else { 5 + $Offset }
        FirstBreach = if ($Variant -eq "plan") { 320 + $Offset } else { 200 + $Offset }
        BuilderDeaths = 0
        Route = "true"
        RoutePenalty = if ($Variant -eq "plan") { -0.1 } else { 0.0 }
    }
    foreach ($key in $Overrides.Keys) { $values[$key] = $Overrides[$key] }

    return "[AIBEVT] t=1200 seq=$Sequence scenario=manual source=strategy action=wave_result actor=team:$($values.Team) fixture_id=$($values.FixtureId) fixture_version=$($values.FixtureVersion) team=$($values.Team) team_side=$($values.TeamSide) seed=$($values.Seed) variant=$Variant scenario=$Scenario initial_fingerprint=$($values.Fingerprint) measurement_fingerprint=$($values.MeasurementFingerprint) elapsed=$($values.Elapsed) breached=$($values.Breached) first_breach=$($values.FirstBreach) crossings=$($values.Crossings) enemy_deaths=7 builder_deaths=$($values.BuilderDeaths) flag_approaches=4 plan_completed_delta=3 plan_pending=1 plan_damaged=2 damage_events=3 damage_absorbed_cost=40 plan_cost=200 completion_tick=600 first_damage_tick=700 structure_lifetime=500 builder_travel=123.5 builder_idle_ticks=30 reservation_conflicts=0 replans=1 route_preserved=$($values.Route) friendly_route_penalty=$($values.RoutePenalty)"
}

try {
    $lines = @()
    $sequence = 0
    $offset = 0
    foreach ($scenario in @("knight", "archer", "bomb", "mixed")) {
        foreach ($seed in @(77, 78, 79)) {
            $sequence++; $lines += New-WaveLine $sequence $scenario "control" $offset @{ Seed = $seed; MeasurementFingerprint = "measure-$scenario-$seed-control" }
            $sequence++; $lines += New-WaveLine $sequence $scenario "plan" $offset @{ Seed = $seed; MeasurementFingerprint = "measure-$scenario-$seed-plan" }
        }
        $offset += 10
    }
    Set-Content -LiteralPath $logPath -Value $lines -Encoding UTF8

    $json = (& $compare -LogPath $logPath -AsJson) -join "`n"
    $result = $json | ConvertFrom-Json
    if ($result.Pairs.Count -ne 12 -or $result.Aggregate.PairCount -ne 12 -or $result.Aggregate.ScenarioCount -ne 4 -or $result.Aggregate.MinimumSeedsPerCohort -ne 3) {
        throw "Valid comparison returned wrong pair/scenario counts"
    }
    foreach ($pair in $result.Pairs) {
        if ($pair.CrossingsDelta -ne -3 -or $pair.FirstBreachDelta -ne 120 -or $pair.FriendlyRoutePenaltyDelta -ne -0.1) {
            throw "Unexpected deltas for $($pair.Scenario): crossing=$($pair.CrossingsDelta) breach=$($pair.FirstBreachDelta) route=$($pair.FriendlyRoutePenaltyDelta)"
        }
    }
    if ($result.Aggregate.MeanCrossingsDelta -ne -3 -or $result.Aggregate.MeanFirstBreachDelta -ne 120) {
        throw "Unexpected aggregate deltas"
    }
    if (!$result.Aggregate.AcceptancePassed -or $result.Aggregate.BothBreachedPairCount -ne 12) {
        throw "Valid non-worsening pairs did not pass semantic acceptance"
    }
    foreach ($pair in $result.Pairs) {
        if ($pair.InitialFingerprint -ne "canonical-flat-ctf" -or $pair.FixtureId -ne "flat_ctf" -or $pair.TeamSide -ne "left" -or
            [string]::IsNullOrWhiteSpace($pair.ControlMeasurementFingerprint) -or [string]::IsNullOrWhiteSpace($pair.PlanMeasurementFingerprint) -or
            !$pair.AcceptancePassed -or $pair.BreachEvidence -ne "plan_delayed_breach") {
            throw "Fingerprint or semantic evidence missing for $($pair.Scenario)"
        }
    }
    & $compare -LogPath $logPath -RequireAcceptanceGates -AsJson | Out-Null

    $underSampled = @(
        New-WaveLine 1 "knight" "control" 0 @{ Seed = 77 }
        New-WaveLine 2 "knight" "plan" 0 @{ Seed = 77 }
        New-WaveLine 3 "knight" "control" 0 @{ Seed = 78 }
        New-WaveLine 4 "knight" "plan" 0 @{ Seed = 78 }
    )
    Set-Content -LiteralPath $logPath -Value $underSampled -Encoding UTF8
    $underSampledRejected = $false
    try { & $compare -LogPath $logPath -Scenarios "knight" -AsJson | Out-Null } catch {
        $underSampledRejected = $_.Exception.Message -match "requires at least 3 distinct seeds"
    }
    if (!$underSampledRejected) { throw "Two-seed cohort was not rejected by the default minimum" }

    $identityMismatch = @(
        New-WaveLine 1 "knight" "control" 0 @{ FixtureId = "fixture-a" }
        New-WaveLine 2 "knight" "plan" 0 @{ FixtureId = "fixture-b" }
    )
    Set-Content -LiteralPath $logPath -Value $identityMismatch -Encoding UTF8
    $identityRejected = $false
    try { & $compare -LogPath $logPath -Scenarios "knight" -MinimumSeedsPerCohort 1 -AsJson | Out-Null } catch {
        $identityRejected = $_.Exception.Message -match "exactly one control and one plan"
    }
    if (!$identityRejected) { throw "Different fixture identities were incorrectly paired" }

    $toleratedRouteIncrease = @(
        New-WaveLine 1 "knight" "control" 0 @{ RoutePenalty = 0.0 }
        New-WaveLine 2 "knight" "plan" 0 @{ RoutePenalty = 0.05 }
    )
    Set-Content -LiteralPath $logPath -Value $toleratedRouteIncrease -Encoding UTF8
    $json = (& $compare -LogPath $logPath -Scenarios "knight" -MinimumSeedsPerCohort 1 -RequireAcceptanceGates -AsJson) -join "`n"
    $pair = @(($json | ConvertFrom-Json).Pairs)[0]
    if (!$pair.FriendlyRouteGatePassed -or $pair.FriendlyRoutePenaltyAllowance -ne 0.1) {
        throw "Small configured route-penalty increase was not tolerated"
    }
    $strictRouteRejected = $false
    try {
        & $compare -LogPath $logPath -Scenarios "knight" -MinimumSeedsPerCohort 1 -RequireAcceptanceGates -MaxFriendlyRoutePenaltyIncrease 0.0 -AsJson | Out-Null
    } catch {
        $strictRouteRejected = $_.Exception.Message -match "friendly_route"
    }
    if (!$strictRouteRejected) { throw "Zero route-penalty allowance did not reject an increase" }

    Set-Content -LiteralPath $logPath -Value $lines -Encoding UTF8

    Add-Content -LiteralPath $logPath -Value (New-WaveLine 99 "knight" "plan" 0) -Encoding UTF8
    $duplicateRejected = $false
    try { & $compare -LogPath $logPath -AsJson | Out-Null } catch { $duplicateRejected = $_.Exception.Message -match "exactly one control and one plan" }
    if (!$duplicateRejected) { throw "Duplicate wave result was not rejected" }

    Set-Content -LiteralPath $logPath -Value $lines[0..($lines.Count - 2)] -Encoding UTF8
    $missingRejected = $false
    try { & $compare -LogPath $logPath -AsJson | Out-Null } catch { $missingRejected = $_.Exception.Message -match "exactly one control and one plan" }
    if (!$missingRejected) { throw "Missing wave pair was not rejected" }

    $fingerprintMismatch = @(
        New-WaveLine 1 "knight" "control" 0 @{ Fingerprint = "fixture-a" }
        New-WaveLine 2 "knight" "plan" 0 @{ Fingerprint = "fixture-b" }
    )
    Set-Content -LiteralPath $logPath -Value $fingerprintMismatch -Encoding UTF8
    $mismatchRejected = $false
    try { & $compare -LogPath $logPath -Scenarios "knight" -MinimumSeedsPerCohort 1 -AsJson | Out-Null } catch { $mismatchRejected = $_.Exception.Message -match "mismatched initial_fingerprint" }
    if (!$mismatchRejected) { throw "Mismatched initial-state fingerprints were not rejected" }

    $censoredImprovement = @(
        New-WaveLine 1 "knight" "control" 0 @{ Crossings = 1; FirstBreach = 200 }
        New-WaveLine 2 "knight" "plan" 0 @{ Crossings = 0; Breached = "false"; FirstBreach = 0 }
    )
    Set-Content -LiteralPath $logPath -Value $censoredImprovement -Encoding UTF8
    $json = (& $compare -LogPath $logPath -Scenarios "knight" -MinimumSeedsPerCohort 1 -AsJson) -join "`n"
    $result = $json | ConvertFrom-Json
    $pair = @($result.Pairs)[0]
    if (!$pair.ControlBreached -or !$pair.PlanCensored -or $null -ne $pair.FirstBreachDelta -or
        $pair.BreachEvidence -ne "plan_censored_after_control_breach" -or !$pair.BreachGatePassed -or
        $result.Aggregate.ControlOnlyBreachedPairCount -ne 1 -or $null -ne $result.Aggregate.MeanFirstBreachDelta) {
        throw "Censored improvement was not represented with censor-aware evidence"
    }
    & $compare -LogPath $logPath -Scenarios "knight" -MinimumSeedsPerCohort 1 -RequireAcceptanceGates -AsJson | Out-Null

    $shorterCensoring = @(
        New-WaveLine 1 "knight" "control" 0 @{ Crossings = 0; Breached = "false"; FirstBreach = 0; Elapsed = 1200 }
        New-WaveLine 2 "knight" "plan" 0 @{ Crossings = 0; Breached = "false"; FirstBreach = 0; Elapsed = 600 }
    )
    Set-Content -LiteralPath $logPath -Value $shorterCensoring -Encoding UTF8
    $json = (& $compare -LogPath $logPath -Scenarios "knight" -MinimumSeedsPerCohort 1 -AsJson) -join "`n"
    $result = $json | ConvertFrom-Json
    $pair = @($result.Pairs)[0]
    if ($pair.BreachEvidence -ne "both_censored_plan_observed_shorter" -or $pair.BreachGatePassed -or $result.Aggregate.AcceptancePassed) {
        throw "Shorter plan censoring was not marked as insufficient breach evidence"
    }
    $shorterCensorRejected = $false
    try { & $compare -LogPath $logPath -Scenarios "knight" -MinimumSeedsPerCohort 1 -RequireAcceptanceGates -AsJson | Out-Null } catch {
        $shorterCensorRejected = $_.Exception.Message -match "breach:both_censored_plan_observed_shorter"
    }
    if (!$shorterCensorRejected) { throw "Acceptance gates allowed a plan with a shorter censored observation" }

    $worsened = @(
        New-WaveLine 1 "knight" "control" 0 @{ Crossings = 2; FirstBreach = 300; BuilderDeaths = 0; Route = "true"; RoutePenalty = 0.0 }
        New-WaveLine 2 "knight" "plan" 0 @{ Crossings = 3; FirstBreach = 200; BuilderDeaths = 1; Route = "false"; RoutePenalty = 1.0 }
    )
    Set-Content -LiteralPath $logPath -Value $worsened -Encoding UTF8
    $json = (& $compare -LogPath $logPath -Scenarios "knight" -MinimumSeedsPerCohort 1 -AsJson) -join "`n"
    $result = $json | ConvertFrom-Json
    $pair = @($result.Pairs)[0]
    if ($pair.AcceptancePassed -or $pair.CrossingsGatePassed -or $pair.BreachGatePassed -or
        $pair.FriendlyRouteGatePassed -or $pair.BuilderDeathsGatePassed -or $result.Aggregate.AcceptancePassed) {
        throw "Raw comparison did not expose all semantic gate failures"
    }
    foreach ($failure in @("crossings", "breach:plan_earlier_breach", "friendly_route", "builder_deaths")) {
        if ($pair.AcceptanceFailures -notmatch [regex]::Escape($failure)) { throw "Missing semantic failure: $failure" }
    }
    $gatesRejected = $false
    try { & $compare -LogPath $logPath -Scenarios "knight" -MinimumSeedsPerCohort 1 -RequireAcceptanceGates -AsJson | Out-Null } catch {
        $gatesRejected = $_.Exception.Message -match "semantic acceptance gates failed" -and $_.Exception.Message -match "builder_deaths"
    }
    if (!$gatesRejected) { throw "Opt-in semantic acceptance gates did not reject worsened results" }

    $invalidOutcome = @(
        New-WaveLine 1 "knight" "control" 0 @{ Breached = "unknown" }
        New-WaveLine 2 "knight" "plan" 0
    )
    Set-Content -LiteralPath $logPath -Value $invalidOutcome -Encoding UTF8
    $invalidOutcomeRejected = $false
    try { & $compare -LogPath $logPath -Scenarios "knight" -MinimumSeedsPerCohort 1 -AsJson | Out-Null } catch { $invalidOutcomeRejected = $_.Exception.Message -match "Invalid breached value" }
    if (!$invalidOutcomeRejected) { throw "Invalid breached outcome was not rejected" }

    Write-Output "AIB wave result comparator passed"
}
finally {
    Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue
}
