$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$data = Get-Content -LiteralPath (Join-Path $root 'Scripts\BlueprintData.as') -Raw
$network = Get-Content -LiteralPath (Join-Path $root 'Scripts\BlueprintNetwork.as') -Raw
$renderer = Get-Content -LiteralPath (Join-Path $root 'Scripts\CustomRenderer.as') -Raw

$recipientStart = $data.IndexOf('bool AIBP_PlayerCanReceiveDisplay(')
$recipientEnd = $data.IndexOf('void AIBP_SendDisplayTileToPlayer(', $recipientStart)
if ($recipientStart -lt 0 -or $recipientEnd -le $recipientStart) {
    throw 'Blueprint display recipient policy could not be isolated'
}
$recipient = $data.Substring($recipientStart, $recipientEnd - $recipientStart)
foreach ($needle in @(
    'targetNetID != 0 && player.getNetworkID() != targetNetID',
    'playerTeam == team || playerTeam >= 100'
)) {
    if (!$recipient.Contains($needle)) { throw "Blueprint display recipient policy is incomplete: $needle" }
}
$tileSendStart = $recipientEnd
$tileSendEnd = $data.IndexOf('void AIBP_NotifyDisplayTile(', $tileSendStart)
if ($tileSendEnd -le $tileSendStart) { throw 'Targeted blueprint tile sender could not be isolated' }
$tileSend = $data.Substring($tileSendStart, $tileSendEnd - $tileSendStart)
if (!$tileSend.Contains('rules.SendCommand(rules.getCommandID("syncBlueprintBlock"), sync, player);')) {
    throw 'Single-tile blueprint payload is not sent through the targeted rules-command overload'
}

$tileStart = $data.IndexOf('void AIBP_NotifyDisplayTile(')
$tileEnd = $data.IndexOf('u16 AIBP_GetDisplayTile(', $tileStart)
$snapshotStart = $data.IndexOf('void AIBP_SendDisplaySnapshot(')
$snapshotEnd = $data.IndexOf('bool AIBP_SetHumanTile(', $snapshotStart)
if ($tileStart -lt 0 -or $tileEnd -le $tileStart -or $snapshotStart -lt 0 -or $snapshotEnd -le $snapshotStart) {
    throw 'Blueprint tile/snapshot publication paths could not be isolated'
}
$tile = $data.Substring($tileStart, $tileEnd - $tileStart)
$snapshot = $data.Substring($snapshotStart, $snapshotEnd - $snapshotStart)
foreach ($needle in @(
    'AIBP_PlayerCanReceiveDisplay(player, team)',
    'AIBP_SendDisplayTileToPlayer(rules, player, team, x, y, value, humanVersion)'
)) {
    if (!$tile.Contains($needle)) { throw "Single-tile blueprint delivery is not team-scoped: $needle" }
}
foreach ($needle in @(
    'AIBP_PlayerCanReceiveDisplay(player, team, targetNetID)',
    'rules.SendCommand(rules.getCommandID("giveAllBlocks"), snapshot, player)',
    'if (targetNetID != 0) return;'
)) {
    if (!$snapshot.Contains($needle)) { throw "Blueprint snapshot delivery is not target/team-scoped: $needle" }
}
if ($data.Contains('rules.SendCommand(rules.getCommandID("syncBlueprintBlock"), sync);') -or
    $data.Contains('rules.SendCommand(rules.getCommandID("giveAllBlocks"), snapshot);')) {
    throw 'Blueprint contents can still be broadcast to enemy clients'
}

$setStart = $data.IndexOf('bool AIBP_SetHumanTile(')
$setEnd = $data.IndexOf('bool AIBP_ApplyHumanPlacement(', $setStart)
if ($setStart -lt 0 -or $setEnd -le $setStart) { throw 'Single-tile human mutation could not be isolated' }
$setTile = $data.Substring($setStart, $setEnd - $setStart)
$noOp = $setTile.IndexOf('if (human[index] == value) return false;')
$write = $setTile.IndexOf('human[index] = value;')
$version = $setTile.IndexOf('rules.set_u16(versionKey, currentVersion + 1);')
if ($noOp -lt 0 -or $write -le $noOp -or $version -le $write) {
    throw 'Same-value editor deltas can still mutate state, advance version, or emit telemetry'
}

foreach ($needle in @(
    'sender is null || sender.getNetworkID() != netID',
    'AIBP_ServerApplyHumanDelta(netID, positionx, positiony, receivedBlockIndex, expectedVersion)',
    'AIBP_ServerApplyHumanDelta(netID, positionx, positiony, 0, expectedVersion)'
)) {
    if (!$renderer.Contains($needle)) { throw "Editor command authority is incomplete: $needle" }
}
foreach ($needle in @(
    'player.getTeamNum() != team',
    'AIB_ServerCanUseBlueprintControls(playerNetID)',
    'AIBP_EDIT_RATE_TICKS'
)) {
    if (!$network.Contains($needle)) { throw "Server editor permission/rate boundary is incomplete: $needle" }
}
if (!$renderer.Contains('if(!AIB_LocalCanSeeBlueprintTeam(team)')) {
    throw 'Client display filtering is missing as defense in depth'
}

function Can-ReceiveDisplay {
    param([int]$PlayerTeam, [int]$PlayerNetID, [int]$BlueprintTeam, [int]$TargetNetID = 0)
    if ($TargetNetID -ne 0 -and $PlayerNetID -ne $TargetNetID) { return $false }
    return $PlayerTeam -eq $BlueprintTeam -or $PlayerTeam -ge 100
}
if (!(Can-ReceiveDisplay 0 10 0) -or (Can-ReceiveDisplay 1 11 0) -or
    !(Can-ReceiveDisplay 255 12 0) -or (Can-ReceiveDisplay 0 10 0 11) -or
    !(Can-ReceiveDisplay 0 10 0 10)) {
    throw 'Offline blueprint recipient mirror failed same-team/enemy/spectator/target cases'
}

Write-Output 'AIB authoritative team-scoped editor delta contract passed'
