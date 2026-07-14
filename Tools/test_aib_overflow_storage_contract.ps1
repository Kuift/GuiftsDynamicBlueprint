$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$brain = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as') -Raw
$scenarios = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBTestScenarios.as') -Raw

if ($brain -notmatch 'const u16 AIB_CRATE_WOOD_COST = 150;') {
    throw 'Overflow crate cost is no longer the asserted 150 wood'
}
if ($brain -notmatch 'const u8 AIB_BASE_WORKSHOP_EXISTING_RADIUS_TILES = 28;') {
    throw 'Existing storage workshops no longer use the bounded 28-tile base envelope'
}

$shopSelectStart = $brain.IndexOf('CBlob@ AIB_GetBestBaseBuilderShop(')
$shopSelectEnd = $brain.IndexOf('CBlob@ AIB_BuildBaseBuilderShop(', $shopSelectStart)
if ($shopSelectStart -lt 0 -or $shopSelectEnd -le $shopSelectStart) {
    throw 'Bounded existing storage-workshop selection could not be isolated'
}
$shopSelect = $brain.Substring($shopSelectStart, $shopSelectEnd - $shopSelectStart)
foreach ($needle in @(
    'shop.getTeamNum() != home.getTeamNum()',
    'AIBR_IsOnSameBarrierSide(home, shopPosition)',
    '(shopPosition - homePosition).Length() > maxHomeDistance',
    '(shopPosition - storage).Length() + (shopPosition - reference).Length() * 0.05f',
    'id < bestID'
)) {
    if (!$shopSelect.Contains($needle)) { throw "Existing base-shop selection is incomplete: $needle" }
}
if ($brain.Contains('CBlob@ shop = AIB_GetNearestTeamBlob(blob, "buildershop");')) {
    throw 'Storage delivery can still adopt an arbitrary runner-nearest team workshop'
}
if (!$brain.Contains('CBlob@ shop = AIB_GetBestBaseBuilderShop(home, blob.getPosition());') -or
    !$brain.Contains('CBlob@ best = AIB_GetBestBaseBuilderShop(home, storage);')) {
    throw 'Storage delivery and stone-supply waiting do not share bounded base-shop identity'
}
if (!$brain.Contains('blob.set_netid("ai builder base storage shop", shop is null ? 0 : shop.getNetworkID());')) {
    throw 'Storage delivery does not expose the actually selected production shop for runtime verification'
}

$fundStart = $brain.IndexOf('bool AIB_CanFundBaseCrate(')
$payStart = $brain.IndexOf('bool AIB_PayForBaseCrate(', $fundStart)
$payEnd = $brain.IndexOf('u8 AIB_CountBaseResourceCrates(', $payStart)
if ($fundStart -lt 0 -or $payStart -le $fundStart -or $payEnd -le $payStart) {
    throw 'Overflow crate funding/payment functions could not be isolated'
}
$fund = $brain.Substring($fundStart, $payStart - $fundStart)
$pay = $brain.Substring($payStart, $payEnd - $payStart)
if (!$fund.Contains('inventory.getCount("mat_wood")') -or $fund.Contains('AIB_CountWood(blob)')) {
    throw 'Crate affordability still counts carried wood that inventory payment cannot spend'
}
$builderPay = $pay.IndexOf('AIB_TakeMaterial(blob, "mat_wood", fromBuilder)')
$homePay = $pay.IndexOf('AIB_TakeHomeMaterial(home, "mat_wood", fromHome)')
if ($builderPay -lt 0 -or $homePay -le $builderPay) {
    throw 'Mixed crate payment can consume home wood before confirming the builder leg'
}
if (!$pay.Contains('Material::createFor(blob, refundName, refund);')) {
    throw 'Mixed crate payment does not refund builder wood if the home leg fails'
}
$homeTakeStart = $brain.IndexOf('bool AIB_TakeHomeMaterial(')
$homeTakeEnd = $brain.IndexOf('CBlob@ AIB_GetHomeMaterial(', $homeTakeStart)
if ($homeTakeStart -lt 0 -or $homeTakeEnd -le $homeTakeStart) {
    throw 'Home material withdrawal could not be isolated'
}
$homeTake = $brain.Substring($homeTakeStart, $homeTakeEnd - $homeTakeStart)
$homePreflight = $homeTake.IndexOf('AIB_CountHomeMaterial(home, name) < amount')
$firstMutation = $homeTake.IndexOf('mat.server_Die()')
if ($homePreflight -lt 0 -or $firstMutation -le $homePreflight) {
    throw 'Home material withdrawal can still partially consume an underfunded request'
}

$shopCreate = $brain.IndexOf('CBlob@ shop = server_CreateBlob("buildershop"')
$shopPay = $brain.LastIndexOf('AIB_TakeMaterial(blob, "mat_wood", AIB_BUILDER_SHOP_WOOD_COST)', $shopCreate)
if ($shopCreate -lt 0 -or $shopPay -lt 0 -or $shopPay -gt $shopCreate) {
    throw 'Storage workshop funding is not consumed after site revalidation and before creation'
}
$shopFailure = $brain.Substring($shopCreate, [Math]::Min(600, $brain.Length - $shopCreate))
if ($shopFailure -notmatch 'Material::createFor\(blob, refundName, refund\)') {
    throw 'A failed storage-workshop spawn does not refund its exact wood cost'
}

$crateCreate = $brain.IndexOf('CBlob@ crate = server_CreateBlob("crate"')
$cratePay = $brain.IndexOf('AIB_PayForBaseCrate(blob, home)', $crateCreate)
if ($crateCreate -lt 0 -or $cratePay -lt 0 -or $crateCreate -gt $cratePay) {
    throw 'Overflow crate must be created before its wood is consumed'
}
$crateFailure = $brain.Substring($cratePay, [Math]::Min(350, $brain.Length - $cratePay))
if ($crateFailure -notmatch 'crate\.server_Die\(\)') {
    throw 'An unpaid overflow crate is not removed after payment failure'
}

if ($brain -notmatch 'stored\.getQuantity\(\) < stored\.maxQuantity') {
    throw 'Full-crate merge capacity does not reject already-full material stacks'
}
if ($brain -notmatch 'candidate - Vec2f\(0\.0f, map\.tilesize\).*"no build"') {
    throw 'Overflow placement does not protect the crate head cell from no-build sectors'
}

$fillerMatch = [regex]::Match($scenarios, 'string\[\] fillers = \{(?<items>[^}]+)\};')
if (-not $fillerMatch.Success) {
    throw 'Overflow fixture filler list is missing'
}
$fillers = [regex]::Matches($fillerMatch.Groups['items'].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
if ($fillers.Count -ne 8 -or ($fillers | Select-Object -Unique).Count -ne 8) {
    throw 'Overflow fixture must use eight distinct filler blob types'
}
if ($scenarios -notmatch 'wood\.server_SetQuantity\(250\)') {
    throw 'Overflow fixture no longer funds the crate from one full wood stack'
}
if ($scenarios -notmatch 'storedStone == 100' -or $scenarios -notmatch 'storedWood == initialWood - 150') {
    throw 'Overflow verdict does not prove exact stone delivery and retained stored wood'
}
if ($scenarios -notmatch 'liveWood == initialWood - 150' -or $scenarios -notmatch 'liveStone == 100') {
    throw 'Overflow verdict does not prove whole-world material conservation'
}
foreach ($needle in @(
    'remoteShop.Tag("aibt remote storage shop")',
    'AIBT_SetBlob("aibt_remote_storage_shop", remoteShop);',
    'CBlob@ selectedShop = getBlobByNetworkID(bot.get_netid("ai builder base storage shop"));',
    'const bool remoteRejected = remoteShop !is null && !remoteShop.hasTag("dead") && selectedShop is shop;',
    'remote_same_team_shop_rejected=true'
)) {
    if (!$scenarios.Contains($needle)) { throw "Runtime-ready remote storage-shop rejection is missing: $needle" }
}
if ($scenarios.Contains('AIB_GetBestBaseBuilderShop(')) {
    throw 'Rules-side scenarios still call the brain-private storage-shop selector'
}

Write-Output 'AIB overflow storage conservation contract passed'
