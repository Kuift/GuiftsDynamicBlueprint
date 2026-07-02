$ErrorActionPreference = "Stop"
$compare = Join-Path $PSScriptRoot "compare_aib_wave_results.ps1"
$logPath = Join-Path $env:TEMP ("aib-wave-compare-" + [guid]::NewGuid().ToString("N") + ".log")

function New-WaveLine {
    param([int]$Sequence, [string]$Scenario, [string]$Variant, [int]$Offset)
    $crossings = if ($Variant -eq "plan") { 2 + $Offset } else { 5 + $Offset }
    $firstBreach = if ($Variant -eq "plan") { 320 + $Offset } else { 200 + $Offset }
    $route = if ($Variant -eq "plan") { "true" } else { "true" }
    $routePenalty = if ($Variant -eq "plan") { -0.1 } else { 0.0 }
    return "[AIBEVT] t=1200 seq=$Sequence scenario=manual source=strategy action=wave_result actor=team:0 seed=77 variant=$Variant scenario=$Scenario elapsed=1200 first_breach=$firstBreach crossings=$crossings enemy_deaths=7 builder_deaths=0 flag_approaches=4 plan_completed_delta=3 plan_pending=1 plan_damaged=2 damage_events=3 damage_absorbed_cost=40 plan_cost=200 completion_tick=600 first_damage_tick=700 structure_lifetime=500 builder_travel=123.5 builder_idle_ticks=30 reservation_conflicts=0 replans=1 route_preserved=$route friendly_route_penalty=$routePenalty"
}

try {
    $lines = @()
    $sequence = 0
    $offset = 0
    foreach ($scenario in @("knight", "archer", "bomb", "mixed")) {
        $sequence++; $lines += New-WaveLine $sequence $scenario "control" $offset
        $sequence++; $lines += New-WaveLine $sequence $scenario "plan" $offset
        $offset += 10
    }
    Set-Content -LiteralPath $logPath -Value $lines -Encoding UTF8

    $json = (& $compare -LogPath $logPath -AsJson) -join "`n"
    $result = $json | ConvertFrom-Json
    if ($result.Pairs.Count -ne 4 -or $result.Aggregate.PairCount -ne 4 -or $result.Aggregate.ScenarioCount -ne 4) {
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

    Add-Content -LiteralPath $logPath -Value (New-WaveLine 99 "knight" "plan" 0) -Encoding UTF8
    $duplicateRejected = $false
    try { & $compare -LogPath $logPath -AsJson | Out-Null } catch { $duplicateRejected = $_.Exception.Message -match "exactly one control and one plan" }
    if (!$duplicateRejected) { throw "Duplicate wave result was not rejected" }

    Set-Content -LiteralPath $logPath -Value $lines[0..6] -Encoding UTF8
    $missingRejected = $false
    try { & $compare -LogPath $logPath -AsJson | Out-Null } catch { $missingRejected = $_.Exception.Message -match "exactly one control and one plan" }
    if (!$missingRejected) { throw "Missing wave pair was not rejected" }

    Write-Output "AIB wave result comparator passed"
}
finally {
    Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue
}
