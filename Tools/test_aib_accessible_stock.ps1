$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$common = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBHomeResourceCommon.as') -Raw
$world = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBWorldModel.as') -Raw
$director = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBStrategicDirector.as') -Raw
$brain = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as') -Raw
$renderer = Get-Content -LiteralPath (Join-Path $root 'Scripts\CustomRenderer.as') -Raw
$scenarios = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBTestScenarios.as') -Raw

foreach ($needle in @(
	's8 AIBR_GetBarrierZone(const f32 x, const u16 x1, const u16 x2)',
	'bool AIBR_IsOnSameBarrierSide(CBlob@ reference, Vec2f position)',
    'bool AIBR_IsLooseHomeMaterial(CBlob@ home, CBlob@ material)',
    'Vec2f AIBR_FindBaseStoragePoint(CBlob@ home)',
    'bool AIBR_IsBaseResourceCrate(CBlob@ crate, CBlob@ home, Vec2f storage)',
    'u16 AIBR_CountAccessibleHomeMaterial(CBlob@ home, const string &in material)',
    'AIBR_LOOSE_HOME_RADIUS',
    'AIBR_CRATE_STORAGE_RADIUS'
)) {
    if (!$common.Contains($needle)) { throw "Shared accessible-stock contract is missing: $needle" }
}
if ($common.Contains('AIB_GetBarrierZone(')) {
	throw 'Shared stock must not depend on the AI-brain-local barrier zone helper'
}
$barrierSide = [regex]::Match($common, 'bool AIBR_IsOnSameBarrierSide[\s\S]*?\n\}').Value
foreach ($needle in @(
	'AIBR_GetBarrierZone(reference.getPosition().x, x1, x2)',
	'AIBR_GetBarrierZone(position.x, x1, x2)',
	'referenceZone != 0 && referenceZone == resourceZone'
)) {
	if (!$barrierSide.Contains($needle)) { throw "Home-side barrier comparison is incomplete: $needle" }
}
$looseEligibility = [regex]::Match($common, 'bool AIBR_IsLooseHomeMaterial[\s\S]*?\n\}').Value
if (!$looseEligibility.Contains('AIBR_IsOnSameBarrierSide(home, material.getPosition())')) {
	throw 'Loose stock across the active barrier can still be credited'
}
$storageSearch = [regex]::Match($common, 'Vec2f AIBR_FindBaseStoragePoint[\s\S]*?\n\}').Value
if (!$common.Contains('bool AIBR_IsGroundedStoragePoint(CBlob@ home, Vec2f candidate)') -or
	!$storageSearch.Contains('AIBR_IsGroundedStoragePoint(home, candidate)')) {
	throw 'Grounded storage search can still select the opposite side of the active barrier'
}
$crateEligibility = [regex]::Match($common, 'bool AIBR_IsBaseResourceCrate[\s\S]*?\n\}').Value
if (!$crateEligibility.Contains('AIBR_IsOnSameBarrierSide(home, crate.getPosition())')) {
	throw 'A base crate across the active barrier can still be credited'
}
$count = [regex]::Match($common, 'u16 AIBR_CountAccessibleHomeMaterial[\s\S]*?\n\}').Value
foreach ($needle in @(
    'AIBR_IsLooseHomeMaterial(home, item)',
    'AIBR_FindBaseStoragePoint(home)',
    'AIBR_IsBaseResourceCrate(crate, home, storage)',
    'inventory.getCount(material)'
)) {
    if (!$count.Contains($needle)) { throw "Accessible stock does not cover the executor sources: $needle" }
}

$worldCount = [regex]::Match($world, 'u16 AIBS_CountStored[\s\S]*?\n\}').Value
if (!$world.Contains('#include "AIBHomeResourceCommon.as";') -or
    !$worldCount.Contains('AIBR_CountAccessibleHomeMaterial(resourceHome, material)')) {
    throw 'Director world observation must consume the same accessible-stock helper as the executor'
}
if ($worldCount -match 'buildershop|aibuilder|"tent"|"hall"') {
    throw 'Director must not restore broad global inventory counting'
}
foreach ($needle in @(
    'world.storedWood = AIBS_CountStored(resourceHome, "mat_wood");',
    'world.storedStone = AIBS_CountStored(resourceHome, "mat_stone");',
    'AIBS_PublishAccessibleStock(rules, team, "mat_wood", world.storedWood);',
	'void AIBS_RefreshAccessibleStock(CRules@ rules, const u8 team)',
    'if (rules.exists(key) && rules.get_u16(key) == amount) return;'
)) {
    if (!$world.Contains($needle)) { throw "Director accessible-stock publication is incomplete: $needle" }
}
if (!$director.Contains('AIBS_RefreshAccessibleStock(rules, team);')) {
    throw 'Manual blueprint stock publication goes stale while the director is off'
}

if (!$brain.Contains('#include "AIBHomeResourceCommon.as";')) { throw 'Production executor does not include the shared stock contract' }
if (!$brain.Contains('return AIBR_IsInsideCurrentBarrierZoneAt(position);') -or
	!$brain.Contains('return AIBR_IsOnSameBarrierSide(blob, position);') -or
	$brain.Contains('s8 AIB_GetBarrierZone(')) {
	throw 'Executor barrier filtering must consume the shared normalized zone contract'
}
$brainCount = [regex]::Match($brain, 'u16 AIB_CountHomeMaterial[\s\S]*?\n\}').Value
if (!$brainCount.Contains('return AIBR_CountAccessibleHomeMaterial(home, name);')) {
    throw 'Production executor and director can still disagree on home stock totals'
}
foreach ($needle in @(
    'if (!AIBR_IsLooseHomeMaterial(home, mat)) continue;',
    'Vec2f storage = AIBR_FindBaseStoragePoint(home);',
    'return AIBR_IsBaseResourceCrate(crate, home, storage);'
)) {
    if (!$brain.Contains($needle)) { throw "Executor source eligibility is not shared: $needle" }
}

$uiCount = [regex]::Match($renderer, 'u16 AIB_CountTeamStoredMaterial[\s\S]*?\n\}').Value
if (!$uiCount.Contains('aib strategy accessible ') -or $uiCount -match 'getBlobsByName|buildershop|aibuilder') {
    throw 'Client material summary must display authoritative accessible stock, not rescan broad inventories'
}
if (!$renderer.Contains('"Wood: " + wood + "  accessible " + storedWood') -or
    !$renderer.Contains('"Stone: " + stone + "  accessible " + storedStone')) {
    throw 'Advanced UI does not label the narrowed stock metric accurately'
}

foreach ($needle in @(
    'CBlob@ stockHome = AIBT_SpawnTentTeam(410, 5);',
    'AIBT_GiveMaterial(nearCrate, "mat_wood", 100);',
    'AIBT_GiveMaterial(farCrate, "mat_wood", 500);',
    'nearLoose.server_SetQuantity(30);',
    'farLoose.server_SetQuantity(70);',
    'stockWorld.storedWood == 130',
    'accessible_stock_exact=true remote_stock_excluded=true loose_home_stock_included=true'
)) {
    if (!$scenarios.Contains($needle)) { throw "Runtime-ready accessible-stock fixture is incomplete: $needle" }
}

function Measure-AccessibleStock {
    param([object[]]$Loose, [object[]]$Crates, [double]$LooseRadius = 88, [double]$CrateRadius = 128)
    $total = 0
    foreach ($item in $Loose) {
		if (!$item.Attached -and !$item.InInventory -and !$item.Dead -and $item.Distance -le $LooseRadius -and $item.Zone -eq $item.HomeZone -and $item.HomeZone -ne 0) { $total += $item.Quantity }
    }
    foreach ($crate in $Crates) {
		if (!$crate.Dead -and !$crate.Attached -and !$crate.Packed -and $crate.TeamMatch -and $crate.Distance -le $CrateRadius -and $crate.Zone -eq $crate.HomeZone -and $crate.HomeZone -ne 0) { $total += $crate.Quantity }
    }
    return $total
}

$loose = @(
	[pscustomobject]@{ Quantity=30; Distance=0; Attached=$false; InInventory=$false; Dead=$false; HomeZone=-1; Zone=-1 },
	[pscustomobject]@{ Quantity=70; Distance=900; Attached=$false; InInventory=$false; Dead=$false; HomeZone=-1; Zone=-1 },
	[pscustomobject]@{ Quantity=40; Distance=10; Attached=$false; InInventory=$true; Dead=$false; HomeZone=-1; Zone=-1 },
	[pscustomobject]@{ Quantity=700; Distance=40; Attached=$false; InInventory=$false; Dead=$false; HomeZone=-1; Zone=1 }
)
$crates = @(
	[pscustomobject]@{ Quantity=100; Distance=0; Dead=$false; Attached=$false; Packed=$false; TeamMatch=$true; HomeZone=-1; Zone=-1 },
	[pscustomobject]@{ Quantity=500; Distance=900; Dead=$false; Attached=$false; Packed=$false; TeamMatch=$true; HomeZone=-1; Zone=-1 },
	[pscustomobject]@{ Quantity=60; Distance=20; Dead=$false; Attached=$false; Packed=$false; TeamMatch=$false; HomeZone=-1; Zone=-1 },
	[pscustomobject]@{ Quantity=800; Distance=30; Dead=$false; Attached=$false; Packed=$false; TeamMatch=$true; HomeZone=-1; Zone=1 }
)
if ((Measure-AccessibleStock $loose $crates) -ne 130) {
	throw 'Accessible-stock mirror credited remote, carried, wrong-team, or cross-barrier resources'
}

Write-Output 'AIB executor-aligned accessible home stock contract passed'
