$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$common = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBManualOrderCommon.as') -Raw
$blob = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilder.as') -Raw
$jobs = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBStrategicJobs.as') -Raw
$renderer = Get-Content -LiteralPath (Join-Path $root 'Scripts\CustomRenderer.as') -Raw
$chat = Get-Content -LiteralPath (Join-Path $root 'Rules\CommonScripts\ChatCommands.as') -Raw
$scenarios = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBTestScenarios.as') -Raw

foreach ($needle in @(
    'const string AIBM_MANUAL_CONTROL_KEY = "aib player manual order";',
    'void AIBM_ClearStrategyControl(CBlob@ builder)',
    'AIBP_ReleaseBuilderReservation(u8(team), builder.getNetworkID());',
    'builder.set_bool("aib strategy assigned", false);',
    'builder.set_bool("aib strategy role pending", false);',
    'builder.set_bool(AIBM_RETIRE_PENDING_KEY, false);',
    'builder.set_netid(AIBR_ASSIGNED_HOME_KEY, 0);',
    'void AIBM_TakeManualControl(CBlob@ builder)',
    'void AIBM_StopDirectorControl(CBlob@ builder)',
    'void AIBM_ReleaseTeamManualControl(const u8 team)'
)) {
    if (!$common.Contains($needle)) { throw "Manual ownership boundary is incomplete: $needle" }
}
if (([regex]::Matches($blob, 'AIBM_TakeManualControl\(this\);')).Count -ne 3) {
    throw 'All three proximity commands must release director ownership through the shared boundary'
}
foreach ($command in @('ai harvest wood', 'ai mine stone', 'ai build blueprint')) {
    if (!$blob.Contains("getCommandID(`"$command`")")) { throw "Missing proximity command: $command" }
}
if (!$renderer.Contains('AIBM_TakeManualControl(builder);') -or
    !$renderer.Contains('AIBM_StopDirectorControl(builder);') -or
    !$renderer.Contains('else AIBM_ReleaseTeamManualControl(team);')) {
    throw 'Overseer orders or director toggles bypass the shared ownership boundary'
}
$applyStart = $renderer.IndexOf('void AIB_ServerApplyOverseerOrder(')
$applyEnd = $renderer.IndexOf('bool UpdateTreeSelectionButton()', $applyStart)
if ($applyStart -lt 0 -or $applyEnd -le $applyStart) { throw 'Could not isolate the server overseer-order handler' }
$apply = $renderer.Substring($applyStart, $applyEnd - $applyStart)
$validateAt = $apply.IndexOf('if(!AIB_IsValidWorkerOverseerOrder(order)) return;')
$takeAt = $apply.IndexOf('AIBM_TakeManualControl(builder);')
if (!$renderer.Contains('bool AIB_IsValidWorkerOverseerOrder(const u8 order)') -or
    !$renderer.Contains('return order == AIB_OVERSEER_ORDER_WOOD || order == AIB_OVERSEER_ORDER_STONE ||') -or
    $validateAt -lt 0 -or $takeAt -lt 0 -or $validateAt -ge $takeAt) {
    throw 'Unknown overseer opcodes can still release worker ownership before a valid job is accepted'
}
if (!$jobs.Contains('if (AIBM_IsUnderManualControl(teamBuilders[i])) teamBuilders.removeAt(i);') -or
    !$jobs.Contains('if (AIBM_IsUnderManualControl(teamBuilders[i])) { teamBuilders.removeAt(i); continue; }')) {
    throw 'Automatic assignment can still reclaim a manual runner or Autobuilder'
}
$roster = [regex]::Match($jobs, 'void AIBS_GetTeamBuilders[\s\S]*?\n\}').Value
$bootstrap = [regex]::Match($jobs, 'bool AIBS_TryBootstrapBuilder[\s\S]*?\n\}').Value
if ($roster.Contains('AIBM_IsUnderManualControl') -or !$bootstrap.Contains('if (builders.length > 0) return false;')) {
    throw 'A live manual worker must still suppress the one-time free bootstrap spawn'
}
$autoBuilderAt = $jobs.IndexOf('hasAutoBuilder = true;')
$manualAutoAt = $jobs.IndexOf('if (AIBM_IsUnderManualControl(teamBuilders[i])) { teamBuilders.removeAt(i); continue; }')
if ($autoBuilderAt -lt 0 -or $manualAutoAt -le $autoBuilderAt) {
    throw 'A manual Autobuilder must still isolate ordinary runners from director construction roles'
}
foreach ($needle in @(
    'AIBM_ReleaseTeamManualControl(u8(team));',
    'if(mode == AIBP_StrategyMode::auto_mode) AIBM_ReleaseTeamManualControl(u8(team));',
    'if(withPlan) AIBM_ReleaseTeamManualControl(u8(team));'
)) {
    if (!$chat.Contains($needle)) { throw "Explicit automatic chat path does not reclaim manual workers: $needle" }
}
foreach ($needle in @(
    'AIBM_TakeManualControl(stockRunner);',
    'manual_order_preserved=true pending_role_cleared=true explicit_auto_reclaims=true',
    'stockRunner.get_netid(AIBR_ASSIGNED_HOME_KEY) == 0'
)) {
    if (!$scenarios.Contains($needle)) { throw "Runtime-ready manual ownership fixture is incomplete: $needle" }
}
if (($blob | Select-String -Pattern 'addCommandID\(' -AllMatches).Matches.Count -ne 4) {
    throw 'Manual ownership must not consume another limited blob command ID'
}

Write-Output 'AIB manual-order ownership transfer contract passed'
