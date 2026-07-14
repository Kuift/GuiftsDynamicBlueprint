$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$jobs = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBStrategicJobs.as') -Raw

foreach ($needle in @(
    'const u16 AIBS_COLLECTOR_LOAD = 250;',
    'void AIBS_ComputeRoleDemand',
    'if (collectors == 1)',
    'woodShort > 0 && (stoneShort == 0 || woodShort >= stoneShort)',
    'void AIBS_AssignStableRoles',
    '!builder.get_bool("aib strategy assigned")',
    'if (roles[i] != 255) continue;',
    'AIBS_ComputeRoleDemand(teamBuilders.length, world.planPending, woodShort, stoneShort',
    'AIBS_AssignStableRoles(teamBuilders, woodCollectors, stoneCollectors, builders);'
)) {
    if (!$jobs.Contains($needle)) { throw "Production role allocation is missing: $needle" }
}
if ($jobs.Contains('if (woodShort > 0 && woodCollectors == 0 && collectors > 0) woodCollectors = 1;')) {
    throw 'The single-slot wood-first bias has returned'
}

function Get-RoleDemand {
    param([int]$BuilderCount, [int]$PlanPending, [int]$WoodShort, [int]$StoneShort)
    $wood = 0
    $stone = 0
    $build = $BuilderCount
    if ($BuilderCount -eq 0 -or ($WoodShort + $StoneShort) -eq 0) {
        return [pscustomobject]@{ Wood = $wood; Stone = $stone; Build = $build }
    }
    $maxCollectors = if ($BuilderCount -gt 1 -and $PlanPending -gt 0) { $BuilderCount - 1 } else { $BuilderCount }
    $collectors = [Math]::Ceiling(($WoodShort + $StoneShort) / 250.0)
    $materialKinds = [int]($WoodShort -gt 0) + [int]($StoneShort -gt 0)
    $collectors = [Math]::Min($maxCollectors, [Math]::Max($collectors, $materialKinds))
    if ($collectors -eq 1) {
        $wood = if ($WoodShort -gt 0 -and ($StoneShort -eq 0 -or $WoodShort -ge $StoneShort)) { 1 } else { 0 }
        $stone = 1 - $wood
    } elseif ($collectors -gt 1) {
        $wood = [Math]::Floor(($collectors * $WoodShort / [double]($WoodShort + $StoneShort)) + 0.5)
        if ($WoodShort -gt 0 -and $wood -eq 0) { $wood = 1 }
        if ($StoneShort -gt 0 -and $wood -ge $collectors) { $wood = $collectors - 1 }
        $stone = $collectors - $wood
    }
    $build = $BuilderCount - $collectors
    [pscustomobject]@{ Wood = $wood; Stone = $stone; Build = $build }
}

$cases = @(
    @{ Name = 'single slot follows dominant stone'; Args = @(2, 1, 1, 1000); Expected = @(0, 1, 1) },
    @{ Name = 'single slot follows dominant wood'; Args = @(2, 1, 1000, 1); Expected = @(1, 0, 1) },
    @{ Name = 'single slot tie is deterministic'; Args = @(2, 1, 250, 250); Expected = @(1, 0, 1) },
    @{ Name = 'three workers cover both materials and build'; Args = @(3, 1, 250, 250); Expected = @(1, 1, 1) },
    @{ Name = 'four workers allocate proportionally'; Args = @(4, 1, 750, 250); Expected = @(2, 1, 1) },
    @{ Name = 'no active plan allows all collectors'; Args = @(2, 0, 0, 500); Expected = @(0, 2, 0) },
    @{ Name = 'funded plan sends everyone to build'; Args = @(4, 8, 0, 0); Expected = @(0, 0, 4) }
)
foreach ($case in $cases) {
    $caseArgs = $case.Args
    $demand = Get-RoleDemand @caseArgs
    $actual = @($demand.Wood, $demand.Stone, $demand.Build)
    if (($actual -join ',') -ne ($case.Expected -join ',')) {
        throw "$($case.Name): expected $($case.Expected -join ',') got $($actual -join ',')"
    }
    if (($actual | Measure-Object -Sum).Sum -ne $case.Args[0]) {
        throw "$($case.Name): allocation did not conserve the builder roster"
    }
}

function Get-StableRoles {
    param([string[]]$Current, [bool[]]$Assigned, [int]$Wood, [int]$Stone, [int]$Build)
    $roles = @('') * $Current.Count
    $left = @{ wood = $Wood; stone = $Stone; build = $Build }
    for ($i = 0; $i -lt $Current.Count; $i++) {
        $job = $Current[$i]
        if ($Assigned[$i] -and $left.ContainsKey($job) -and $left[$job] -gt 0) {
            $roles[$i] = $job
            $left[$job]--
        }
    }
    for ($i = 0; $i -lt $roles.Count; $i++) {
        if ($roles[$i]) { continue }
        foreach ($job in @('wood', 'stone', 'build')) {
            if ($left[$job] -gt 0) {
                $roles[$i] = $job
                $left[$job]--
                break
            }
        }
    }
    return ,$roles
}

$stable = Get-StableRoles -Current @('build', 'stone', 'wood') -Assigned @($true, $true, $true) -Wood 1 -Stone 1 -Build 1
if (($stable -join ',') -ne 'build,stone,wood') { throw 'Already-correct roles were not preserved' }
$minimal = Get-StableRoles -Current @('stone', 'build', 'wood') -Assigned @($true, $true, $true) -Wood 1 -Stone 0 -Build 2
if (($minimal -join ',') -ne 'build,build,wood') { throw 'Role reduction changed more builders than necessary' }
$manual = Get-StableRoles -Current @('stone', 'stone', 'build') -Assigned @($false, $true, $true) -Wood 1 -Stone 1 -Build 1
if (($manual -join ',') -ne 'wood,stone,build') { throw 'Unassigned low-netid worker did not fill the remaining deterministic slot' }

Write-Output 'AIB demand-aware stable role allocation contract passed'
