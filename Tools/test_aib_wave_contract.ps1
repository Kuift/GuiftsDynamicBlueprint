$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$chatPath = Join-Path $root "Rules\CommonScripts\ChatCommands.as"
$harnessPath = Join-Path $root "Scripts\AIBStrategyWaveHarness.as"
$comparePath = Join-Path $PSScriptRoot "compare_aib_wave_results.ps1"

$chat = Get-Content -LiteralPath $chatPath -Raw
$harness = Get-Content -LiteralPath $harnessPath -Raw
$compare = Get-Content -LiteralPath $comparePath -Raw

foreach ($needle in @(
    'set_string("aib wave fixture id"',
    'set_u16("aib wave fixture version"',
    'set_string("aib wave team side"',
    'set_string("aib wave measurement fingerprint", "")'
)) {
    if (!$chat.Contains($needle)) { throw "Wave arm state is missing contract source: $needle" }
}

foreach ($needle in @(
    'bool AIBW_CaptureMeasurementState',
    'if (!AIBW_CaptureMeasurementState(rules, team))',
	'AIBWF_CaptureWorldManifest(rules, map, terrainHash, solidTiles, noBuildHash, noBuildTiles,',
    '" fixture_id="',
    '" fixture_version="',
    '" team_side="',
    '" measurement_fingerprint="',
    'spawnInterval = 40 + (this.get_u32("aib wave seed") % 11)',
    'formation = (seed *'
)) {
    if (!$harness.Contains($needle)) { throw "Wave harness is missing contract source: $needle" }
}

foreach ($field in @('fixture_id', 'fixture_version', 'team', 'team_side', 'initial_fingerprint', 'measurement_fingerprint')) {
    if ($compare -notmatch ('"' + [regex]::Escape($field) + '"')) {
        throw "Wave comparator does not require identity field: $field"
    }
}
if ($compare -notmatch '\[int\]\$MinimumSeedsPerCohort\s*=\s*3') {
    throw "Wave comparator default minimum is not three seeds per cohort"
}
if ($compare -notmatch 'Group-Object FixtureId, FixtureVersion, Team, TeamSide') {
    throw "Wave comparator does not group pairs by complete fixture/team identity"
}

Write-Output "AIB wave identity and seed-variation contract passed"
