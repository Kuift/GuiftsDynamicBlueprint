param(
    [Parameter(Mandatory = $true)]
    [string]$LogPath
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
$expected = if ($boot -and $boot -match "scenarios=(\d+)") { [int]$Matches[1] } else { -1 }
$donePassed = if ($done -and $done -match "passed=(\d+)") { [int]$Matches[1] } else { -1 }
$doneFailed = if ($done -and $done -match "failed=(\d+)") { [int]$Matches[1] } else { -1 }
$countsMatch = $expected -ge 0 -and $starts.Count -eq $expected -and $passes.Count -eq $expected -and
    $donePassed -eq $expected -and $doneFailed -eq 0

if ($fails.Count -eq 0 -and $compileErrors.Count -eq 0 -and $done -and $countsMatch) {
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

if (!$done) {
    Write-Host "Missing [AIBTEST] DONE"
} elseif (!$countsMatch) {
    Write-Host "Scenario count mismatch: expected=$expected starts=$($starts.Count) passes=$($passes.Count) done_passed=$donePassed done_failed=$doneFailed"
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
