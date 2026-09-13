$ErrorActionPreference = "Stop"
$generator = Join-Path $PSScriptRoot "new_aib_wave_matrix.ps1"
$output = Join-Path $env:TEMP ("aib-wave-matrix-" + [guid]::NewGuid().ToString("N") + ".ndjson")

try {
    & $generator -FixtureId "flat_ctf" -OutputPath $output | Out-Null
    $records = @(Get-Content -LiteralPath $output | ForEach-Object { $_ | ConvertFrom-Json })
    if ($records.Count -ne 48) { throw "Default matrix did not contain 48 trials: $($records.Count)" }
    $pairs = @($records | Group-Object pair_id)
    if ($pairs.Count -ne 24) { throw "Default matrix did not contain 24 pairs: $($pairs.Count)" }
    foreach ($pair in $pairs) {
        $variants = @($pair.Group | Select-Object -ExpandProperty variant)
        if ($pair.Count -ne 2 -or $variants[0] -ne "control" -or $variants[1] -ne "plan") {
            throw "Pair '$($pair.Name)' is not an ordered control/plan pair"
        }
        if (@($pair.Group | Select-Object -ExpandProperty requires_fresh_canonical_reset -Unique).Count -ne 1 -or
            !$pair.Group[0].requires_fresh_canonical_reset) {
            throw "Pair '$($pair.Name)' does not require a canonical reset"
        }
    }
    if (@($records | Select-Object -ExpandProperty team_side -Unique | Sort-Object) -join "," -ne "left,right") {
        throw "Default matrix does not cover both sides"
    }
    foreach ($scenario in @("knight", "archer", "bomb", "mixed")) {
        $scenarioRecords = @($records | Where-Object scenario -eq $scenario)
        if (@($scenarioRecords | Select-Object -ExpandProperty seed -Unique).Count -ne 3) {
            throw "Scenario '$scenario' does not contain three seeds"
        }
    }

    $rejected = $false
    try { & $generator -FixtureId "flat_ctf" -Seeds @(1, 2) -OutputPath $output | Out-Null } catch {
        $rejected = $_.Exception.Message -match "At least three distinct seeds"
    }
    if (!$rejected) { throw "Under-sampled matrix was not rejected" }

    Write-Output "AIB 48-trial wave matrix generator passed"
}
finally {
    Remove-Item -LiteralPath $output -Force -ErrorAction SilentlyContinue
}
