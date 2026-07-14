$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $root 'Rules\CommonScripts\AIBTelemetryPolicy.cfg'
$policyPath = Join-Path $root 'Scripts\AIBTelemetryPolicy.as'
$logPath = Join-Path $root 'Scripts\AIBPlayerActionLog.as'
$chatPath = Join-Path $root 'Rules\CommonScripts\ChatCommands.as'
$operationsPath = Join-Path $root 'PUBLIC_SERVER_OPERATIONS.md'

$config = @{}
foreach ($line in Get-Content -LiteralPath $configPath) {
    if ($line -match '^\s*([A-Za-z0-9_]+)\s*=\s*([^#\r\n]+)') {
        $config[$Matches[1]] = $Matches[2].Trim()
    }
}
foreach ($key in @('config_version', 'ctf_enabled', 'player_notice_enabled', 'player_notice')) {
    if (!$config.ContainsKey($key)) { throw "Telemetry policy config is missing $key" }
}
if ($config.config_version -ne '1' -or $config.ctf_enabled -ne 'true' -or $config.player_notice_enabled -ne 'true') {
    throw 'Public CTF telemetry/notice defaults are no longer explicit and enabled'
}
if ($config.player_notice -notmatch 'AI evaluation' -or $config.player_notice -notmatch 'excludes usernames, IP addresses, and chat') {
    throw 'Default player notice no longer states purpose and privacy exclusions'
}

$policy = Get-Content -LiteralPath $policyPath -Raw
foreach ($needle in @(
    'CFileMatcher("AIBTelemetryPolicy.cfg").getFirst()',
    'cfg.read_bool("ctf_enabled", true)',
    'cfg.read_bool("player_notice_enabled", true)',
    'cfg.read_string("player_notice"',
	'sourceLoaded = loaded',
	'sourceFile = filename',
    'return gamemode == "CTF" && policy.ctfEnabled;'
)) {
    if (!$policy.Contains($needle)) { throw "Shared telemetry policy loader is missing: $needle" }
}

$log = Get-Content -LiteralPath $logPath -Raw
foreach ($needle in @(
    '#include "AIBTelemetryPolicy.as";',
	'const bool policyInitialized = this.get_bool("aib telemetry policy initialized");',
	'if (!policyInitialized)',
	'this.set_bool("aib telemetry policy initialized", true);',
	'const bool defaultEnabled = AIB_DefaultTelemetryForGamemode(this.gamemode_name);',
    'this.Sync("aib player action log enabled", true);',
	'print("[AIBTELEMETRY] init gamemode=" + this.gamemode_name +',
	'AIB_ActionMaybeNotifyLocalPlayer(this);',
	'player.isMyPlayer()',
	'this.set_bool(AIB_ActionNoticeKey(player), false);',
    'AIB_ActionObserveEnabledTransition(this);',
    'AIB_ActionFlush(rules, "disabled");',
    'AIB_ActionClearBoundaryQueue(rules);',
    'AIB_ActionBeginEpisode(rules);',
	'client_AddToChat("[AIB] " + policy.playerNotice'
)) {
    if (!$log.Contains($needle)) { throw "Telemetry lifecycle/notice contract is missing: $needle" }
}
if ($log.Contains('rules.set_bool("aib player action log enabled", rules.gamemode_name == "CTF")')) {
    throw 'Round episode reset must not overwrite the administrator runtime telemetry override'
}
$noticeFunction = [regex]::Match($log, 'void AIB_ActionMaybeNotifyLocalPlayer[\s\S]*?\n\}').Value
if (!$noticeFunction -or $noticeFunction -match 'getUsername|getCharacterName') {
    throw 'Player notice must be targeted without inserting player identity'
}
if ($log.Contains('addCommandID(AIB_ACTION_NOTICE_COMMAND)') -or $log.Contains('SendCommand(rules.getCommandID(AIB_ACTION_NOTICE_COMMAND)')) {
    throw 'Telemetry notice must not consume a rules command ID'
}

$chat = Get-Content -LiteralPath $chatPath -Raw
$command = [regex]::Match($chat, 'bool AIB_HandleTelemetryCommand[\s\S]*?\n\}').Value
foreach ($needle in @(
    '!player.isMod()',
    'rules.Sync("aib player action log enabled", true);',
    '"; CTF startup " + (telemetryPolicy.ctfEnabled ? "on" : "off")',
    '"; player notice " + (telemetryPolicy.playerNoticeEnabled ? "on" : "off")'
)) {
    if (!$command.Contains($needle)) { throw "Moderator telemetry status/control is missing: $needle" }
}
$handlerCall = $chat.IndexOf('if (AIB_HandleTelemetryCommand(this, text_in, player)) return false;')
$blobGuard = $chat.IndexOf('CBlob@ blob = player.getBlob();')
if ($handlerCall -lt 0 -or $blobGuard -lt 0 -or $handlerCall -gt $blobGuard) {
    throw 'Global telemetry control must remain available to dead/spectating moderators before gameplay blob guards'
}

$operations = Get-Content -LiteralPath $operationsPath -Raw
foreach ($needle in @(
    '## Before opening a public test',
    '## Rotation and retention',
    'Tools/parse_aib_player_actions.ps1',
    'Tools/summarize_aib_player_episodes.ps1',
    'non-`[AIBACT]` lines may carry ordinary server identity or chat data',
    'schema-v3 loss records as incomplete evidence'
)) {
    if (!$operations.Contains($needle)) { throw "Public telemetry operations runbook is missing: $needle" }
}

Write-Output 'AIB public telemetry policy, notice, and retention contract passed'
