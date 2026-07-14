$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $root 'Rules\CommonScripts\AIBStrategyWeights.cfg'
$loaderPath = Join-Path $root 'Scripts\AIBStrategyWeights.as'
$plannerPath = Join-Path $root 'Scripts\AIBPlacementPlanner.as'
$simPath = Join-Path $root 'Tools\aib_strategy_abstract_sim.ps1'

$config = @{}
foreach ($line in Get-Content -LiteralPath $configPath) {
    if ($line -match '^\s*([A-Za-z0-9_]+)\s*=\s*([-+]?\d+(?:\.\d+)?)') { $config[$Matches[1]] = [double]$Matches[2] }
}
$loader = Get-Content -LiteralPath $loaderPath -Raw
$readKeys = [regex]::Matches($loader, 'read_(?:f32|s32)\("([A-Za-z0-9_]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
foreach ($key in $readKeys) { if (!$config.ContainsKey($key)) { throw "AngelScript loader key missing from config: $key" } }

$required = @(
    'config_version','base_defense','enemy_knight_pressure','enemy_archer_pressure','world_pressure',
    'access_route_gain','default_route_gain','height_measure_scale','tactical_height_bonus',
    'non_tactical_height_scale','chokepoint','sightline','emergency_urgency','gatehouse_knight_fit',
    'other_archer_fit','local_pressure_fit','continuity_max','continuity_distance','template_cooldown_ticks',
    'template_cooldown_penalty','wood_cost','stone_cost','wood_shortage','stone_shortage','travel','task_build_time','exposure_free_distance',
    'exposure_distance','exposure_pressure','friendly_route_penalty','near_best_fraction'
)
foreach ($key in $required) { if (!$config.ContainsKey($key)) { throw "Required production weight missing: $key" } }

$planner = Get-Content -LiteralPath $plannerPath -Raw
if ($planner -notmatch '#include "AIBStrategyWeights\.as"' -or $planner -notmatch 'AIBS_GetStrategyWeights\(\)') {
    throw 'Production planner does not consume shared strategy weights'
}
foreach ($needle in @(
    'const bool loaded = filename != "" && cfg.loadFile(filename);',
    'print("[AIBWEIGHTS] loaded=" + (loaded ? "true" : "false") +',
    '" version=" + AIBS_strategy_weights.version + " file=" + filename)'
)) {
    if (!$loader.Contains($needle)) { throw "Production weight loader lacks one-shot runtime evidence: $needle" }
}
$sim = Get-Content -LiteralPath $simPath -Raw
if ($sim -notmatch 'AIBStrategyWeights\.cfg' -or $sim -notmatch 'Get-W') {
    throw 'Offline simulator does not consume shared strategy weights'
}
Write-Host "AIB shared strategy weight contract passed ($($config.Count) keys)"
