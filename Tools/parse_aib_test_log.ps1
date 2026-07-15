param(
    [Parameter(Mandatory = $true)]
    [string]$LogPath,
    [string[]]$ExpectedScenarios = @()
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $LogPath)) {
    Write-Error "Log not found: $LogPath"
    exit 2
}

$lines = Get-Content $LogPath
$starts = $lines | Where-Object { $_ -match "\[AIBTEST\] START " }
$passes = $lines | Where-Object { $_ -match "\[AIBTEST\] PASS " }
$fails = $lines | Where-Object { $_ -match "\[AIBTEST\] FAIL " }
$done = $lines | Where-Object { $_ -match "\[AIBTEST\] DONE " } | Select-Object -Last 1
$boot = $lines | Where-Object { $_ -match "\[AIBTEST\] BOOT scenarios=(\d+)" } | Select-Object -Last 1
$compileErrors = $lines | Where-Object { $_ -match "ERROR .*GuiftsDynamicBlueprint_vDev|Null pointer access.*GuiftsDynamicBlueprint_vDev|Exception.*GuiftsDynamicBlueprint_vDev" }
$configurationErrors = $lines | Where-Object { $_ -match "\[AIBTEST\] CONFIG_ERROR" }
$expected = if ($boot -and $boot -match "scenarios=(\d+)") { [int]$Matches[1] } else { -1 }
$requestedExpected = if ($ExpectedScenarios.Count -gt 0) { $ExpectedScenarios.Count } else { $expected }
$donePassed = if ($done -and $done -match "passed=(\d+)") { [int]$Matches[1] } else { -1 }
$doneFailed = if ($done -and $done -match "failed=(\d+)") { [int]$Matches[1] } else { -1 }
$startedScenarioNames = @($starts | ForEach-Object {
    if ($_ -match "\[AIBTEST\] START ([^\s]+)") { $Matches[1] }
})
$passedScenarioNames = @($passes | ForEach-Object {
    if ($_ -match "\[AIBTEST\] PASS ([^\s]+)") { $Matches[1] }
})
$bootMatchesRequest = $expected -ge 0 -and $expected -eq $requestedExpected
$sequenceMatchesRequest = $true
if ($ExpectedScenarios.Count -gt 0) {
    $sequenceMatchesRequest = $startedScenarioNames.Count -eq $ExpectedScenarios.Count -and
        $passedScenarioNames.Count -eq $ExpectedScenarios.Count
    for ($i = 0; $sequenceMatchesRequest -and $i -lt $ExpectedScenarios.Count; $i++) {
        $sequenceMatchesRequest =
            $startedScenarioNames[$i] -ceq $ExpectedScenarios[$i] -and
            $passedScenarioNames[$i] -ceq $ExpectedScenarios[$i]
    }
}
$doneCountsMatch = $bootMatchesRequest -and $starts.Count -eq $requestedExpected -and $passes.Count -eq $requestedExpected -and
    $donePassed -eq $requestedExpected -and $doneFailed -eq 0 -and $sequenceMatchesRequest
$allScenarioPasses = $bootMatchesRequest -and $starts.Count -eq $requestedExpected -and
    $passes.Count -eq $requestedExpected -and $sequenceMatchesRequest

if ($fails.Count -eq 0 -and $compileErrors.Count -eq 0 -and $configurationErrors.Count -eq 0 -and
    $done -and $doneCountsMatch) {
    Write-Host "AIB tests passed: $($passes.Count) passed, 0 failed"
    Write-Host "Fresh log: $LogPath"
    exit 0
}

Write-Host "AIB tests failed: $($fails.Count) failed, $($passes.Count) passed"
foreach ($fail in $fails) {
    Write-Host "- $fail"
}

if ($compileErrors.Count -gt 0) {
    Write-Host "Compile/runtime errors:"
    $compileErrors | Select-Object -First 20 | ForEach-Object { Write-Host "- $_" }
}

if ($configurationErrors.Count -gt 0) {
    Write-Host "Selection errors:"
    $configurationErrors | ForEach-Object { Write-Host "- $_" }
}

if (!$done) {
    Write-Host "Missing [AIBTEST] DONE"
} elseif (!$doneCountsMatch) {
    Write-Host "Scenario count mismatch: requested=$requestedExpected boot=$expected starts=$($starts.Count) passes=$($passes.Count) done_passed=$donePassed done_failed=$doneFailed"
}

if (!$sequenceMatchesRequest) {
    Write-Host "Scenario selection mismatch: requested=$($ExpectedScenarios -join ',') started=$($startedScenarioNames -join ',') passed=$($passedScenarioNames -join ',')"
}

$events = $lines | Where-Object { $_ -match "\[AIBEVT\]" } | Select-Object -Last 40
if ($events.Count -gt 0) {
    Write-Host "Recent event timeline:"
    foreach ($event in $events) {
        Write-Host "  $event"
    }
}

Write-Host "Fresh log: $LogPath"
exit 1
