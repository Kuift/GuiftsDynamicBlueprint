$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$brain = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as') -Raw
$scenarios = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBTestScenarios.as') -Raw

if ($brain -notmatch 'const u16 AIB_CRATE_WOOD_COST = 150;') {
    throw 'Overflow crate cost is no longer the asserted 150 wood'
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

Write-Output 'AIB overflow storage conservation contract passed'
