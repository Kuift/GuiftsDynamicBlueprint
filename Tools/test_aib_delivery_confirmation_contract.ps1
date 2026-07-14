$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$brain = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as') -Raw
$manual = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBManualOrderCommon.as') -Raw

$returnStart = $brain.IndexOf('void AIB_ReturnWood(')
$stoneStart = $brain.IndexOf('void AIB_FindStone(', $returnStart)
if ($returnStart -lt 0 -or $stoneStart -le $returnStart) {
    throw 'Resource return function could not be isolated'
}
$return = $brain.Substring($returnStart, $stoneStart - $returnStart)
$confirmRead = $return.IndexOf('blob.get_u32(AIB_DELIVERY_CONFIRM_UNTIL_KEY)')
$bounceCheck = $return.IndexOf('AIB_HasAnyResource(blob)', $confirmRead)
$retryLog = $return.IndexOf('AIB_LogEvent("ai", "store_resources_retry"', $bounceCheck)
$storeAttempt = $return.IndexOf('AIB_StoreResourcesInBaseCrates(blob, home)', $retryLog)
$armConfirm = $return.IndexOf('blob.set_u32(AIB_DELIVERY_CONFIRM_UNTIL_KEY, now + AIB_DELIVERY_CONFIRM_TICKS);', $storeAttempt)
$successLog = $return.IndexOf('AIB_LogEvent("ai", "store_resources"', $armConfirm)
$handoff = $return.IndexOf('blob.set_u32(AIBM_RESOURCE_HANDOFF_UNTIL_KEY', $successLog)
if ($confirmRead -lt 0 -or $bounceCheck -le $confirmRead -or $retryLog -le $bounceCheck -or
    $storeAttempt -le $retryLog -or $armConfirm -le $storeAttempt -or $successLog -le $armConfirm -or $handoff -le $successLog) {
    throw 'Delivery is not confirmed on a later tick before logging success and entering the role handoff'
}

foreach ($needle in @(
    'const u32 AIB_DELIVERY_CONFIRM_TICKS = 3;',
    'const string AIB_DELIVERY_CONFIRM_UNTIL_KEY = "ai builder delivery confirm until";',
    'AIB_ReportWaitingStatus(blob, "Confirming storage transfer");',
    '" wood=" + blob.get_u16("ai builder delivery pending wood")',
    '" stone=" + blob.get_u16("ai builder delivery pending stone")',
    '" gold=" + blob.get_u16("ai builder delivery pending gold")'
)) {
    if (!$brain.Contains($needle)) { throw "Queued delivery confirmation contract is missing: $needle" }
}

foreach ($needle in @(
    'builder.set_u32("ai builder delivery confirm until", 0);',
    'builder.set_u16("ai builder delivery pending wood", 0);',
    'builder.set_u16("ai builder delivery pending stone", 0);',
    'builder.set_u16("ai builder delivery pending gold", 0);'
)) {
    if (!$manual.Contains($needle)) { throw "Ownership/navigation reset leaves queued delivery state behind: $needle" }
}

Write-Output 'AIB queued resource-delivery confirmation contract passed'
