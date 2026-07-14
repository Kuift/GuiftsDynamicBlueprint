$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$catalog = Get-Content -LiteralPath (Join-Path $root 'Scripts\BlueprintCatalog.as') -Raw
$data = Get-Content -LiteralPath (Join-Path $root 'Scripts\BlueprintData.as') -Raw
$planner = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBPlacementPlanner.as') -Raw
$brain = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as') -Raw

foreach ($needle in @(
    'const string AIBP_BLUEPRINT_OWNER_TEAM_KEY = "aibuilder blueprint owner team";',
    'bool AIBP_UsesNeutralBlobTeam(const u16 encoded)',
    'return AIBP_BlockId(encoded) == AIBP_PLATFORM;',
    'bool AIBP_BlobTeamMatchesBlock(const u16 encoded, const s16 actualTeam, const s16 expectedTeam)',
    'if (AIBP_UsesNeutralBlobTeam(encoded)) return true;',
    'return actualTeam == expectedTeam;',
    'bool AIBP_IsDirectorBlobForTeam(CBlob@ blob, const u8 team)',
    'blob.get_u8(AIBP_BLUEPRINT_OWNER_TEAM_KEY) == team'
)) {
    if (!$catalog.Contains($needle)) { throw "Neutral blob catalog/ownership contract is missing: $needle" }
}

$matchStart = $data.IndexOf('CBlob@ AIBP_GetMatchingPlanBlob(')
$mapMatchStart = $data.IndexOf('bool AIBP_MapMatchesBlock(', $matchStart)
if ($matchStart -lt 0 -or $mapMatchStart -le $matchStart) {
    throw 'Exact plan-blob matcher could not be isolated'
}
$matcher = $data.Substring($matchStart, $mapMatchStart - $matchStart)
if (!$matcher.Contains('AIBP_BlobTeamMatchesBlock(block, placed.getTeamNum(), expectedTeam)')) {
    throw 'Exact plan-blob matching still rejects engine-neutral platform teams'
}
if ($matcher.Contains('placed.getTeamNum() != expectedTeam')) {
    throw 'Legacy strict blob-team comparison remains in the exact matcher'
}
if ($catalog.Contains('AIBP_UsesNeutralBlobTeam(encoded) && actualTeam == -1')) {
    throw 'Neutral platform identity still depends on KAG exposing a signed team sentinel'
}

$protectedStart = $planner.IndexOf('bool AIBS_OverlapsProtectedBlob(')
$costStart = $planner.IndexOf('void AIBS_CandidateCosts(', $protectedStart)
if ($protectedStart -lt 0 -or $costStart -le $protectedStart) {
    throw 'Planner protected-blob function could not be isolated'
}
$protected = $planner.Substring($protectedStart, $costStart - $protectedStart)
if (!$protected.Contains('AIBP_IsDirectorBlobForTeam(blob, team)')) {
    throw 'Planner cannot recognize a neutralized director platform as its originating team structure'
}
if ($protected.Contains('blob.hasTag("aibuilder blueprint structure") && blob.getTeamNum() == team')) {
    throw 'Planner still relies only on mutable engine team identity for director blobs'
}

$placeStart = $brain.IndexOf('bool AIB_PlaceBlueprintBlob(')
$clearStart = $brain.IndexOf('void AIB_ClearBlueprintTargetForTile(', $placeStart)
if ($placeStart -lt 0 -or $clearStart -le $placeStart) {
    throw 'Blueprint blob placement function could not be isolated'
}
$placement = $brain.Substring($placeStart, $clearStart - $placeStart)
$ownerAt = $placement.IndexOf('placed.set_u8(AIBP_BLUEPRINT_OWNER_TEAM_KEY, u8(blob.getTeamNum()));')
$syncAt = $placement.IndexOf('placed.Sync(AIBP_BLUEPRINT_OWNER_TEAM_KEY, true);', $ownerAt)
$tagAt = $placement.IndexOf('placed.Tag("aibuilder blueprint structure");', $syncAt)
if ($ownerAt -lt 0 -or $syncAt -le $ownerAt -or $tagAt -le $syncAt) {
    throw 'Blueprint placement does not preserve and publish the originating team before tagging the structure'
}

Write-Output 'AIB neutral blob identity contract passed'
