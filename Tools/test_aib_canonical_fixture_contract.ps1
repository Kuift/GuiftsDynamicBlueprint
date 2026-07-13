$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$scenarioPath = Join-Path $root 'Scripts\AIBTestScenarios.as'
$source = Get-Content -LiteralPath $scenarioPath -Raw

foreach ($needle in @(
    'u16[] AIBT_canonical_tiles',
    'u32 AIBT_MapTileHash',
    'u16 AIBT_CountLiveTagged',
    'void AIBT_CaptureOrValidateCanonicalMap',
    'u32 AIBT_RestoreCanonicalMap',
    'AIBT_CaptureOrValidateCanonicalMap();',
    'const u32 restoredCanonicalTiles = AIBT_RestoreCanonicalMap();',
    'canonical_fixture_reset_failed',
    'blob_leak fixtures=',
    'strategy_leak team='
)) {
    if (!$source.Contains($needle)) { throw "Canonical fixture reset contract is missing: $needle" }
}

$cleanup = [regex]::Match($source, 'void AIBT_CleanupScenario\(\)(?<body>[\s\S]*?)void AIBT_FreezeFinalFixture').Groups['body'].Value
if (!$cleanup.Contains('AIBT_RestoreCanonicalMap()')) { throw 'Scenario cleanup does not restore the canonical map' }
$setup = [regex]::Match($source, 'void AIBT_SetupScenario\(const int index\)(?<body>[\s\S]*?)CBlob@ bot;').Groups['body'].Value
if ($setup.IndexOf('AIBT_CleanupScenario();') -gt $setup.IndexOf('AIBT_CaptureOrValidateCanonicalMap();')) {
    throw 'Canonical validation runs before cleanup'
}

Write-Output 'AIB canonical fixture reset contract passed'
