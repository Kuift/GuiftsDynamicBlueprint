$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $root 'Rules\CommonScripts\AIBDirectorPolicy.cfg'
$policyPath = Join-Path $root 'Scripts\AIBDirectorPolicy.as'
$jobsPath = Join-Path $root 'Scripts\AIBStrategicJobs.as'
$chatPath = Join-Path $root 'Rules\CommonScripts\ChatCommands.as'

$config = @{}
foreach ($line in Get-Content -LiteralPath $configPath) {
    if ($line -match '^\s*([A-Za-z0-9_]+)\s*=\s*([^#\r\n]+)') {
        $config[$Matches[1]] = $Matches[2].Trim()
    }
}
foreach ($key in @('config_version', 'ctf_default_mode', 'ctf_bootstrap_enabled')) {
    if (!$config.ContainsKey($key)) { throw "Director policy config is missing $key" }
}
if ($config.config_version -ne '1' -or $config.ctf_default_mode -ne 'auto' -or $config.ctf_bootstrap_enabled -ne 'true') {
    throw 'Public CTF policy defaults no longer preserve automatic planning plus one guarded bootstrap worker'
}

$policy = Get-Content -LiteralPath $policyPath -Raw
foreach ($needle in @(
    'CFileMatcher("AIBDirectorPolicy.cfg").getFirst()',
    'cfg.read_s32("config_version", 1)',
    'cfg.read_string("ctf_default_mode", "auto")',
    'cfg.read_bool("ctf_bootstrap_enabled", true)',
    'if (value == "off") return AIBD_POLICY_MODE_OFF;',
    'if (value == "suggest") return AIBD_POLICY_MODE_SUGGEST;',
    'return AIBD_POLICY_MODE_AUTO;',
    'if (gamemode == "AIBTest") return AIBD_POLICY_MODE_OFF;',
    'return gamemode == "CTF" && policy.ctfBootstrapEnabled;'
)) {
    if (!$policy.Contains($needle)) { throw "Shared director policy loader is missing: $needle" }
}

$jobs = Get-Content -LiteralPath $jobsPath -Raw
if (!$jobs.Contains('#include "AIBDirectorPolicy.as";')) {
    throw 'Production strategic jobs do not consume the shared director policy'
}
if (!$jobs.Contains('if (!rules.exists(enabledKey)) rules.set_bool(enabledKey, AIBS_DefaultBootstrapForGamemode(rules.gamemode_name));')) {
    throw 'Bootstrap initialization no longer preserves an existing administrator runtime override'
}
$reset = [regex]::Match($jobs, 'void AIBS_ResetBootstrapForRound[\s\S]*?\n\}').Value
if (!$reset -or $reset -match 'set_bool\(AIBS_BootstrapKey\(team, "enabled"\)') {
    throw 'Round reset must preserve the configured/runtime bootstrap enabled policy'
}

$chat = Get-Content -LiteralPath $chatPath -Raw
$command = [regex]::Match($chat, 'if\(tokens\.length > 0 && tokens\[0\] == "!aib_bootstrap"\)[\s\S]*?(?=\n\tif\(tokens\.length > 0 && tokens\[0\] == "!aib_strategy"\))').Value
if (!$command) { throw 'Moderator !aib_bootstrap command is missing' }
foreach ($needle in @(
    '!player.isMod()',
    'tokens[1] != "on" && tokens[1] != "off" && tokens[1] != "status"',
    'this.set_bool(enabledKey, tokens[1] == "on");',
    'this.Sync(enabledKey, true);',
    'if(tokens[1] == "on") this.set_u32("aib strategy important event team " + team, getGameTime());',
    '"; round grant " + (provisioned ? "used" : "available")',
    '"; retry in " + retryTicks + " ticks"'
)) {
    if (!$command.Contains($needle)) { throw "Moderator bootstrap control is missing: $needle" }
}
if ($command -match 'set_bool\(AIBS_BootstrapKey\([^\)]*"provisioned"' -or
    $command -match 'set_u32\(AIBS_BootstrapKey\([^\)]*"next retry"') {
    throw 'Runtime policy changes must not reset the one-per-round latch or retry deadline'
}

Write-Output 'AIB director startup/bootstrap policy contract passed'
