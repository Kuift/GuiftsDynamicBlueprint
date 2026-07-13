$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$jobs = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBStrategicJobs.as') -Raw
$scenarios = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBTestScenarios.as') -Raw

foreach ($needle in @(
    'class AIBBootstrapReachability',
    'const u8 AIBS_BOOTSTRAP_HOME_SEED_RADIUS = 4;',
    'AIBS_IsBootstrapRouteCell',
    'AIBS_BuildBootstrapReachability',
    'Use one deterministic terrain seed nearest to the home',
    'homeX - int(AIBS_BOOTSTRAP_HOME_SEED_RADIUS)',
    'for (int stepY = -1; stepY <= 1; stepY++)',
    'AIBS_BootstrapReachable(reachability, center)',
    'AIBS_IsBootstrapSpawnEnvelopeSafe(world, center, blockerMins, blockerMaxs)',
    'AIBBootstrapReachability@ reachability = AIBS_BuildBootstrapReachability(world);'
)) {
    if (!$jobs.Contains($needle)) { throw "Bootstrap connectivity contract is missing: $needle" }
}
if (!$scenarios.Contains('strategic_bootstrap_rejects_sealed_cave_spawn') -or
    !$scenarios.Contains('mirrored_sealed_rejected=true') -or
    !$scenarios.Contains('open_surface_accepted=true')) {
    throw 'The mirrored sealed-pocket production fixture is missing'
}

$solid = [Collections.Generic.HashSet[string]]::new()
function Cell-Key([int]$X, [int]$Y) { return "$X,$Y" }
function Set-Solid([int]$X, [int]$Y) { [void]$solid.Add((Cell-Key $X $Y)) }
function Test-Solid([int]$X, [int]$Y) { return $solid.Contains((Cell-Key $X $Y)) }
function Test-RouteCell([int]$X, [int]$Y) {
    return !(Test-Solid $X $Y) -and !(Test-Solid $X ($Y - 1)) -and (Test-Solid $X ($Y + 1))
}
function Test-Envelope([int]$X, [int]$Y) {
    foreach ($dx in -1..1) {
        if ((Test-Solid ($X + $dx) $Y) -or (Test-Solid ($X + $dx) ($Y - 1))) { return $false }
    }
    return Test-Solid $X ($Y + 1)
}

$homeX = 220
$homeY = 70
$groundY = 72
$leftPocketX = 208
$rightPocketX = 232
$pocketTop = 65
$pocketFloor = 68
foreach ($x in 190..250) { Set-Solid $x $groundY }
foreach ($centerX in @($leftPocketX, $rightPocketX)) {
    foreach ($x in ($centerX - 2)..($centerX + 2)) {
        Set-Solid $x $pocketTop
        Set-Solid $x $pocketFloor
    }
    foreach ($y in $pocketTop..$pocketFloor) {
        Set-Solid ($centerX - 2) $y
        Set-Solid ($centerX + 2) $y
    }
}

$minX = $homeX - 26
$maxX = $homeX + 26
$minY = $homeY - 16
$maxY = $homeY + 16
$seedRadius = 4
$seed = $null
$seedScore = [int]::MaxValue
foreach ($y in ($homeY - $seedRadius)..($homeY + $seedRadius)) {
    foreach ($x in ($homeX - $seedRadius)..($homeX + $seedRadius)) {
        if (!(Test-RouteCell $x $y)) { continue }
        $score = ($x - $homeX) * ($x - $homeX) + ($y - $homeY) * ($y - $homeY)
        if ($score -ge $seedScore) { continue }
        $seedScore = $score
        $seed = [int[]]@($x, $y)
    }
}
if ($null -eq $seed) { throw 'Synthetic home surface did not produce a reachability seed' }

$visited = [Collections.Generic.HashSet[string]]::new()
$queue = [Collections.Generic.Queue[object]]::new()
[void]$visited.Add((Cell-Key $seed[0] $seed[1]))
$queue.Enqueue($seed)
while ($queue.Count -gt 0) {
    $point = $queue.Dequeue()
    foreach ($stepX in @(-1, 1)) {
        foreach ($stepY in -1..1) {
            $nx = $point[0] + $stepX
            $ny = $point[1] + $stepY
            if ($nx -lt $minX -or $nx -gt $maxX -or $ny -lt $minY -or $ny -gt $maxY) { continue }
            $key = Cell-Key $nx $ny
            if ($visited.Contains($key) -or !(Test-RouteCell $nx $ny)) { continue }
            [void]$visited.Add($key)
            $queue.Enqueue([int[]]@($nx, $ny))
        }
    }
}

$pocketBodyY = $pocketFloor - 1
$openX = $homeX - 6
if (!(Test-Envelope $leftPocketX $pocketBodyY) -or !(Test-Envelope $rightPocketX $pocketBodyY)) {
    throw 'Synthetic sealed pockets must remain locally clear and grounded'
}
if ($visited.Contains((Cell-Key $leftPocketX $pocketBodyY)) -or $visited.Contains((Cell-Key $rightPocketX $pocketBodyY))) {
    throw 'Sealed pocket was incorrectly terrain-connected to the home surface'
}
if (!(Test-Envelope $openX ($groundY - 1)) -or !$visited.Contains((Cell-Key $openX ($groundY - 1)))) {
    throw 'Open home surface must remain an accepted bootstrap route'
}

$selected = $null
$bestScore = [double]::PositiveInfinity
foreach ($distance in 6..24) {
    foreach ($side in @(-1, 1)) {
        $x = $homeX + $side * $distance
        foreach ($yOffset in -12..12) {
            $y = $homeY + $yOffset
            if (!(Test-Envelope $x $y) -or !$visited.Contains((Cell-Key $x $y))) { continue }
            $score = [double]$distance + [Math]::Abs($yOffset) * 2.0 + $(if ($side -eq -1) { 0.0 } else { 0.25 })
            if ($score -ge $bestScore) { continue }
            $bestScore = $score
            $selected = [int[]]@($x, $y)
        }
    }
}
if ($null -eq $selected -or $selected[0] -ne $openX -or $selected[1] -ne ($groundY - 1)) {
    throw "Expected reachable rear surface at $openX,$($groundY - 1); selected $($selected -join ',')"
}

Write-Output 'AIB bootstrap surface-connectivity contract passed'
