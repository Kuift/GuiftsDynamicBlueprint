param(
    [Parameter(Mandatory = $true)] [string[]]$BaselinePath,
    [Parameter(Mandatory = $true)] [string[]]$CandidatePath,
    [ValidateRange(1, 1000000)] [int]$MinimumEpisodesPerContext = 3,
    [switch]$RequireQualityGates,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'

function Read-Episodes([string[]]$paths, [string]$label) {
    $rows = foreach ($path in $paths) {
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "$label episode file not found: $path" }
        Get-Content -LiteralPath $path | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json }
    }
    foreach ($row in $rows) {
        if ($row.schema -ne 'aib_task_episode_v1') { throw "$label contains unsupported episode schema '$($row.schema)'" }
        if ([string]::IsNullOrWhiteSpace([string]$row.context_key_v1)) { throw "$label episode is missing context_key_v1" }
        if ($null -ne $row.boundary_records_dropped -and [int]$row.boundary_records_dropped -gt 0) {
            throw "$label contains incomplete telemetry: boundary_records_dropped=$($row.boundary_records_dropped)"
        }
    }
    return @($rows)
}

function Mean($rows, [string]$property) {
    if ($rows.Count -eq 0) { return $null }
    return [Math]::Round([double](($rows | Measure-Object -Property $property -Average).Average), 3)
}

$baseline = @(Read-Episodes $BaselinePath 'Baseline')
$candidate = @(Read-Episodes $CandidatePath 'Candidate')
if ($baseline.Count -eq 0 -or $candidate.Count -eq 0) { throw 'Both baseline and candidate must contain episodes' }

$baselineContexts = @($baseline | Select-Object -ExpandProperty context_key_v1 -Unique | Sort-Object)
$candidateContexts = @($candidate | Select-Object -ExpandProperty context_key_v1 -Unique | Sort-Object)
$allContexts = @($baselineContexts + $candidateContexts | Select-Object -Unique | Sort-Object)
$comparisons = @()
foreach ($context in $allContexts) {
    $b = @($baseline | Where-Object context_key_v1 -eq $context)
    $c = @($candidate | Where-Object context_key_v1 -eq $context)
    if ($b.Count -lt $MinimumEpisodesPerContext -or $c.Count -lt $MinimumEpisodesPerContext) {
        throw "Context '$context' requires at least $MinimumEpisodesPerContext episodes in each cohort; baseline=$($b.Count) candidate=$($c.Count)"
    }
    $bSuccess = [Math]::Round(@($b | Where-Object success).Count / [double]$b.Count, 3)
    $cSuccess = [Math]::Round(@($c | Where-Object success).Count / [double]$c.Count, 3)
    $metrics = @('estimated_cost_v1','duration_ticks','idle_ticks_estimate','travel_px','jumps','deaths','wood_spent','stone_spent','gold_spent','attributed_outcome_weight','low_confidence_outcomes')
    $row = [ordered]@{
        schema = 'aib_task_episode_comparison_v1'; context_key_v1 = $context
        baseline_count = $b.Count; candidate_count = $c.Count
        baseline_success_rate = $bSuccess; candidate_success_rate = $cSuccess
        success_rate_delta = [Math]::Round($cSuccess - $bSuccess, 3)
    }
    foreach ($metric in $metrics) {
        $baselineMean = Mean $b $metric; $candidateMean = Mean $c $metric
        $row["baseline_mean_$metric"] = $baselineMean
        $row["candidate_mean_$metric"] = $candidateMean
        $row["delta_$metric"] = [Math]::Round($candidateMean - $baselineMean, 3)
    }
    $failures = @()
    if ($cSuccess -lt $bSuccess) { $failures += 'success_rate' }
    if ($row.delta_estimated_cost_v1 -gt 0) { $failures += 'estimated_cost' }
    if ($row.delta_deaths -gt 0) { $failures += 'deaths' }
    $row.quality_passed = $failures.Count -eq 0
    $row.quality_failures = $failures -join ','
    $comparisons += [pscustomobject]$row
}

$result = [pscustomobject][ordered]@{
    schema = 'aib_task_episode_comparison_set_v1'
    minimum_episodes_per_context = $MinimumEpisodesPerContext
    context_count = $comparisons.Count
    quality_passed = @($comparisons | Where-Object { !$_.quality_passed }).Count -eq 0
    comparisons = $comparisons
}
if ($RequireQualityGates -and !$result.quality_passed) {
    $summary = @($comparisons | Where-Object { !$_.quality_passed } | ForEach-Object { "$($_.context_key_v1):$($_.quality_failures)" }) -join '; '
    throw "AIB task episode quality gates failed: $summary"
}
if ($AsJson) { $result | ConvertTo-Json -Depth 6 }
else {
    Write-Output 'AIB matched-context episode comparison (candidate - baseline)'
    $comparisons | Format-Table context_key_v1, baseline_count, candidate_count, success_rate_delta, delta_estimated_cost_v1, delta_deaths, quality_passed -AutoSize
}
