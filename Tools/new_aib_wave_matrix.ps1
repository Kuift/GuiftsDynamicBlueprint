param(
    [Parameter(Mandatory = $true)]
    [string]$FixtureId,
    [ValidateRange(1, 65535)]
    [int]$FixtureVersion = 4,
    [string[]]$TeamSides = @("0:left", "1:right"),
    [string[]]$Scenarios = @("knight", "archer", "bomb", "mixed"),
    [uint64[]]$Seeds = @(101, 211, 307),
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
if ($FixtureId -notmatch '^[A-Za-z0-9_.-]+$') {
    throw "FixtureId may contain only letters, digits, dot, underscore, and hyphen"
}
if ($Scenarios.Count -eq 0) { throw "At least one scenario is required" }
if ($Seeds.Count -lt 3) { throw "At least three distinct seeds are required" }
if (@($Seeds | Select-Object -Unique).Count -ne $Seeds.Count) { throw "Seeds must be distinct" }

$allowedScenarios = @("knight", "archer", "bomb", "mixed")
foreach ($scenario in $Scenarios) {
    if ($scenario -notin $allowedScenarios) { throw "Unsupported wave scenario: $scenario" }
}
if (@($Scenarios | Select-Object -Unique).Count -ne $Scenarios.Count) { throw "Scenarios must be distinct" }

$sides = @()
foreach ($entry in $TeamSides) {
    if ($entry -notmatch '^(?<team>\d+):(?<side>left|right)$') {
        throw "Invalid TeamSides entry '$entry'; expected TEAM:left or TEAM:right"
    }
    $sides += [pscustomobject]@{ Team = [int]$Matches.team; Side = $Matches.side }
}
if ($sides.Count -eq 0) { throw "At least one team side is required" }
$sideKeys = @($sides | ForEach-Object { "$($_.Team):$($_.Side)" })
if (@($sideKeys | Select-Object -Unique).Count -ne $sideKeys.Count) { throw "TeamSides entries must be distinct" }

$records = @()
$ordinal = 0
foreach ($side in $sides) {
    foreach ($scenario in $Scenarios) {
        foreach ($seed in $Seeds) {
            $pairId = "$FixtureId-v$FixtureVersion-t$($side.Team)-$($side.Side)-$scenario-s$seed"
            foreach ($variant in @("control", "plan")) {
                $ordinal++
                $records += [pscustomobject][ordered]@{
                    schema = "aib_wave_matrix_v1"
                    ordinal = $ordinal
                    pair_id = $pairId
                    fixture_id = $FixtureId
                    fixture_version = $FixtureVersion
                    team = $side.Team
                    team_side = $side.Side
                    scenario = $scenario
                    seed = $seed
                    variant = $variant
                    command = "!aib_wave $seed $variant $scenario"
                    requires_fresh_canonical_reset = $true
                    status = "pending"
                }
            }
        }
    }
}

$parent = Split-Path -Parent $OutputPath
if ($parent -and !(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
$lines = @($records | ForEach-Object { $_ | ConvertTo-Json -Compress })
Set-Content -LiteralPath $OutputPath -Value $lines -Encoding UTF8
Write-Output "AIB wave matrix written: $($records.Count) trials / $($records.Count / 2) pairs -> $OutputPath"
