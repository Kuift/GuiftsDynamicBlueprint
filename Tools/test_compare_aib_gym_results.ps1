$ErrorActionPreference = 'Stop'
$tool = Join-Path $PSScriptRoot 'compare_aib_gym_results.ps1'
$temp = Join-Path ([IO.Path]::GetTempPath()) ("aib-gym-compare-" + [guid]::NewGuid().ToString('N') + '.log')
try {
    $lines = @()
    foreach ($variant in @('control','candidate')) {
        foreach ($run in 1..3) {
            $delivered = if ($variant -eq 'control') { 100 + $run } else { 130 + $run }
            $terrain = 220 + $run
            $fingerprint = "w1-same-map-run-$run-$variant"
            $lines += "[AIBGYMR] schema=4 status=result run=${variant}${run} variant=$variant metric=resource_collection_180s fixture_id=map_111_200x100 fixture_version=1 team=0 team_side=left map_hash=111 map_width=200 map_height=100 initial_terrain_hash=$terrain initial_fingerprint=$fingerprint builders=1 live_builders=1 order=wood duration=5400 elapsed=5400 collected_wood=$delivered collected_stone=0 collected_gold=0 collected_total=$delivered delivered_wood=$delivered delivered_stone=0 delivered_gold=0 delivered_total=$delivered stock_delta_wood=$delivered stock_delta_stone=0 stock_delta_gold=0 deaths=0 failure_flags=0 idle_ticks=4 travel_px=200 reason=duration_complete"
        }
    }
    # Archived KAG console files prepend [HH:MM:SS], whereas explicit TCPR
    # transcripts start directly at [AIBGYMR]. Both are first-party transports.
    $lines[0] = '[12:34:56] ' + $lines[0]
    # Mixed historical consoles can also contain aborts and pre-schema-4 rows;
    # neither is a completed comparable episode.
    $lines += '[12:34:57] [AIBGYMR] schema=1 status=abort run=old-abort reason=contaminated'
    $lines += '[12:34:58] [AIBGYMR] schema=3 status=result run=old-result metric=resource_collection_180s'
    # Duplicate transports for the same physical episodes must collapse rather
    # than inflating the cohort from three runs to four.
    $lines += $lines[0]
    $lines += $lines[3]
    # A different map must never enter or dilute the valid cohort.
    $lines += '[AIBGYMR] schema=4 status=result run=other variant=control metric=resource_collection_180s fixture_id=map_999_200x100 fixture_version=1 team=0 team_side=left map_hash=999 map_width=200 map_height=100 initial_terrain_hash=888 initial_fingerprint=w1-other builders=1 live_builders=1 order=wood duration=5400 elapsed=5400 collected_wood=9999 collected_stone=0 collected_gold=0 collected_total=9999 delivered_wood=9999 delivered_stone=0 delivered_gold=0 delivered_total=9999 stock_delta_wood=9999 stock_delta_stone=0 stock_delta_gold=0 deaths=0 failure_flags=0 idle_ticks=0 travel_px=1 reason=duration_complete'
    Set-Content -LiteralPath $temp -Value $lines -Encoding utf8
    $result = ((& $tool -LogPath $temp -AsJson -RequireImprovement) -join "`n") | ConvertFrom-Json
    if ($result.CohortCount -ne 1 -or !$result.AcceptancePassed) { throw 'Expected exactly one accepted exact-map cohort.' }
    $cohort = $result.Cohorts[0]
    if ($cohort.BaselineRuns -ne 3 -or $cohort.CandidateRuns -ne 3) {
        throw 'Duplicate transports incorrectly inflated physical episode counts.'
    }
    if ($cohort.BaselineMeanCollected -ne 102 -or $cohort.CandidateMeanCollected -ne 132 -or $cohort.CollectedDelta -ne 30) {
        throw 'Unexpected collected-resource comparison.'
    }
    if ($cohort.MapHash -ne 111 -or $cohort.DistinctInitialFingerprints -ne 6 -or $cohort.DistinctInitialTerrainHashes -ne 3) {
        throw 'Same-map transient fingerprints were not retained as audit evidence.'
    }

    $conflicting = @($lines)
    $conflicting += ($lines[0] -replace 'collected_total=101', 'collected_total=999')
    Set-Content -LiteralPath $temp -Value $conflicting -Encoding utf8
    $conflictRejected = $false
    try {
        & $tool -LogPath $temp -AsJson | Out-Null
    } catch {
        if ($_.Exception.Message -match "Conflicting AIBGYMR records reuse run id 'control1'") {
            $conflictRejected = $true
        } else {
            throw
        }
    }
    if (!$conflictRejected) { throw 'A conflicting reused run id was not rejected.' }
    Write-Output 'compare_aib_gym_results offline regression passed'
} finally {
    Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
}
