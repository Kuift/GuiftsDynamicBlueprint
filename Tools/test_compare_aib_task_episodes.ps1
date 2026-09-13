$ErrorActionPreference = 'Stop'
$compare = Join-Path $PSScriptRoot 'compare_aib_task_episodes.ps1'
$baselinePath = Join-Path $env:TEMP ('aib-episode-baseline-' + [guid]::NewGuid().ToString('N') + '.ndjson')
$candidatePath = Join-Path $env:TEMP ('aib-episode-candidate-' + [guid]::NewGuid().ToString('N') + '.ndjson')

function Episode([string]$context, [double]$cost, [int]$duration, [bool]$success, [int]$deaths = 0) {
    [pscustomobject][ordered]@{
        schema='aib_task_episode_v1'; context_key_v1=$context; success=$success
        estimated_cost_v1=$cost; duration_ticks=$duration; idle_ticks_estimate=10; travel_px=20
        jumps=1; deaths=$deaths; wood_spent=0; stone_spent=0; gold_spent=0
        attributed_outcome_weight=1.0; low_confidence_outcomes=0
    }
}

try {
    $baseline = @(1..3 | ForEach-Object { Episode 'm99-t0-c1-build-x0-y0' 100 100 $true })
    $candidate = @(1..3 | ForEach-Object { Episode 'm99-t0-c1-build-x0-y0' 80 90 $true })
    @($baseline | ForEach-Object { $_ | ConvertTo-Json -Compress }) | Set-Content -LiteralPath $baselinePath -Encoding utf8
    @($candidate | ForEach-Object { $_ | ConvertTo-Json -Compress }) | Set-Content -LiteralPath $candidatePath -Encoding utf8
    $result = ((& $compare -BaselinePath $baselinePath -CandidatePath $candidatePath -RequireQualityGates -AsJson) -join "`n") | ConvertFrom-Json
    $row = @($result.comparisons)[0]
    if (!$result.quality_passed -or $row.delta_estimated_cost_v1 -ne -20 -or $row.delta_duration_ticks -ne -10) { throw 'Improved matched cohort was not accepted' }

    $worse = @(1..3 | ForEach-Object { Episode 'm99-t0-c1-build-x0-y0' 120 110 $false 1 })
    @($worse | ForEach-Object { $_ | ConvertTo-Json -Compress }) | Set-Content -LiteralPath $candidatePath -Encoding utf8
    $rejected = $false
    try { & $compare -BaselinePath $baselinePath -CandidatePath $candidatePath -RequireQualityGates -AsJson | Out-Null } catch {
        $rejected = $_.Exception.Message -match 'success_rate' -and $_.Exception.Message -match 'estimated_cost' -and $_.Exception.Message -match 'deaths'
    }
    if (!$rejected) { throw 'Worsened matched cohort was not rejected' }

    $lossy = @(1..3 | ForEach-Object { $row = Episode 'm99-t0-c1-build-x0-y0' 80 90 $true; $row | Add-Member -NotePropertyName boundary_records_dropped -NotePropertyValue 1; $row })
    @($lossy | ForEach-Object { $_ | ConvertTo-Json -Compress }) | Set-Content -LiteralPath $candidatePath -Encoding utf8
    $lossRejected = $false
    try { & $compare -BaselinePath $baselinePath -CandidatePath $candidatePath -AsJson | Out-Null } catch { $lossRejected = $_.Exception.Message -match 'incomplete telemetry' }
    if (!$lossRejected) { throw 'Boundary-loss cohort was not rejected' }

    @($candidate[0..1] | ForEach-Object { $_ | ConvertTo-Json -Compress }) | Set-Content -LiteralPath $candidatePath -Encoding utf8
    $underSampled = $false
    try { & $compare -BaselinePath $baselinePath -CandidatePath $candidatePath -AsJson | Out-Null } catch { $underSampled = $_.Exception.Message -match 'at least 3 episodes' }
    if (!$underSampled) { throw 'Under-sampled context was not rejected' }
    Write-Output 'AIB matched-context episode comparator passed'
}
finally {
    Remove-Item -LiteralPath $baselinePath,$candidatePath -Force -ErrorAction SilentlyContinue
}
