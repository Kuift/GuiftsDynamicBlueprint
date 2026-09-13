$ErrorActionPreference = "Stop"
$sim = Join-Path $PSScriptRoot "aib_strategy_abstract_sim.ps1"
$rows = (& $sim -Trials 250 -Seed 20260620 -AsJson) | ConvertFrom-Json
$control = $rows | Where-Object Template -eq "control"
$gate = $rows | Where-Object Template -eq "flag_gatehouse"
$access = $rows | Where-Object Template -eq "access_route"
$repeatA = ((& $sim -Trials 25 -Seed 424242 -AsJson) | ConvertFrom-Json) | ConvertTo-Json -Depth 4 -Compress
$repeatB = ((& $sim -Trials 25 -Seed 424242 -AsJson) | ConvertFrom-Json) | ConvertTo-Json -Depth 4 -Compress

function Assert-Range {
    param([string]$Name, [double]$Value, [double]$Minimum, [double]$Maximum)
    if ([double]::IsNaN($Value) -or [double]::IsInfinity($Value) -or $Value -lt $Minimum -or $Value -gt $Maximum) {
        throw "$Name was outside [$Minimum, $Maximum]: $Value"
    }
}

$expectedCosts = @{
    control = 0
    flag_gatehouse = 306
    frontline_tower = 352
    emergency_barrier = 117
    archer_perch = 141
    access_route = 60
}

if ($rows.Count -ne $expectedCosts.Count -or !$control -or !$gate -or !$access) { throw "Missing simulator result rows" }
if ($repeatA -ne $repeatB) { throw "Seeded simulator results were not deterministic" }
foreach ($row in $rows) {
    if (!$expectedCosts.ContainsKey($row.Template)) { throw "Unexpected template row: $($row.Template)" }
    if ($row.Trials -ne 250) { throw "Wrong trial count for $($row.Template): $($row.Trials)" }
    if ($row.MaterialCost -ne $expectedCosts[$row.Template]) { throw "Wrong material cost for $($row.Template): $($row.MaterialCost)" }
    Assert-Range "$($row.Template).MeanBreachTicks" $row.MeanBreachTicks 0.01 10000.0
    Assert-Range "$($row.Template).MeanCompletion" $row.MeanCompletion 0.0 1.0
    Assert-Range "$($row.Template).MeanBuilderTravel" $row.MeanBuilderTravel 0.0 10000.0
    Assert-Range "$($row.Template).MeanBuilderIdle" $row.MeanBuilderIdle 0.0 4.0
    Assert-Range "$($row.Template).MeanBuilderDeaths" $row.MeanBuilderDeaths 0.0 4.0
    Assert-Range "$($row.Template).MeanStructureLifetime" $row.MeanStructureLifetime 0.0 10000.0
    Assert-Range "$($row.Template).MeanFriendlyRouteSlowdown" $row.MeanFriendlyRouteSlowdown -1.0 1.0
    Assert-Range "$($row.Template).MeanDamageAbsorbed" $row.MeanDamageAbsorbed 0.0 10000.0
    Assert-Range "$($row.Template).MeanReplans" $row.MeanReplans 0.0 1.0
}

if ($control.MeanCompletion -ne 1.0 -or $control.MeanBuilderTravel -ne 0.0 -or
    $control.MeanStructureLifetime -ne 0.0 -or $control.MeanDamageAbsorbed -ne 0.0 -or
    $control.MeanFriendlyRouteSlowdown -ne 0.0 -or $control.MeanReplans -ne 0.0) {
    throw "Control row accumulated structure or planning effects"
}
if ($gate.MeanBreachTicks -le $control.MeanBreachTicks) { throw "Gatehouse did not improve mean breach time" }
if ($gate.MeanFriendlyRouteSlowdown -gt 0.08) { throw "Gatehouse route penalty exceeded bound" }
if ($gate.MeanDamageAbsorbed -le 0) { throw "Gatehouse did not absorb modeled damage" }
if ($gate.MeanStructureLifetime -le $control.MeanStructureLifetime) { throw "Gatehouse did not improve structure lifetime" }
if ($gate.MeanCompletion -le 0 -or $gate.MeanBuilderTravel -le 0 -or $gate.MeanBuilderDeaths -le 0) { throw "Gatehouse work metrics were not exercised" }
if (($rows | Where-Object Template -ne "control" | Measure-Object MeanReplans -Maximum).Maximum -le 0) { throw "Threat shifts never exercised an emergency plan replacement" }
if ($access.MeanFriendlyRouteSlowdown -ge 0) { throw "Access route did not improve friendly traversal" }

Write-Output "AIB strategy abstract simulator passed"
