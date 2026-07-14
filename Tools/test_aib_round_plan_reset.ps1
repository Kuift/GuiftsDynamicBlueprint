$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$data = Get-Content -LiteralPath (Join-Path $root 'Scripts\BlueprintData.as') -Raw
$director = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBStrategicDirector.as') -Raw
$boundaries = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBActionBoundaryCommon.as') -Raw

$restart = [regex]::Match($director, 'void onRestart[\s\S]*?\n\}').Value
if (!$restart) { throw 'Production director restart hook is missing' }
foreach ($needle in @(
    'AIBS_StopAssignedBuilders(team);',
    'AIBP_ResetTeamPlanForRound(team);',
    'AIBS_ResetBootstrapForRound(this, team);',
    'AIBU_ResetSpeedLevel(this, team);'
)) {
    if (!$restart.Contains($needle)) { throw "Round restart lifecycle is missing: $needle" }
}
$stopAt = $restart.IndexOf('AIBS_StopAssignedBuilders(team);')
$planAt = $restart.IndexOf('AIBP_ResetTeamPlanForRound(team);')
$bootstrapAt = $restart.IndexOf('AIBS_ResetBootstrapForRound(this, team);')
if ($stopAt -lt 0 -or $planAt -le $stopAt -or $bootstrapAt -le $planAt) {
    throw 'Restart must stop worker intent before clearing plan/reservation state, then reopen the round bootstrap latch'
}

$reset = [regex]::Match($data, 'void AIBP_ResetTeamPlanForRound[\s\S]*?\n\}').Value
if (!$reset) { throw 'Authoritative team plan round reset is missing' }
foreach ($needle in @(
    'AIBP_ArchiveCurrentPlan(team, "round_reset");',
    'AIBP_ClearTeamLooseReservations(team);',
    'const u16 mapWidth = map is null ? 0 : map.tilemapwidth;',
    'for (u8 layer = AIBP_Layer::human; layer <= AIBP_Layer::ai_desired; layer++)',
    'rules.set(AIBP_TaskKey(team, "x"), emptyX);',
    'rules.set(AIBP_TaskKey(team, "state"), emptyStates);',
    'rules.set(AIBP_TaskKey(team, "until"), emptyUntils);',
    'rules.set_u16(AIBP_PlanKey(team, "id"), 0);',
    'rules.set_u8(AIBP_PlanKey(team, "status"), 0);',
    'rules.set_Vec2f(AIBP_PlanKey(team, "anchor"), Vec2f_zero);',
    'rules.set_u16(AIBP_PlanKey(team, "pending"), 0);',
    'rules.set_u16(AIBP_PlanKey(team, "completed"), 0);',
    'rules.set_u16(AIBP_PlanKey(team, "damaged"), 0);',
    'rules.get_u16(AIBP_PlanKey(team, "human version")) + 1',
    'AIBP_RebuildCompatibility(team, false);'
)) {
    if (!$reset.Contains($needle)) { throw "Authoritative round reset is incomplete: $needle" }
}
if ($reset -match 'set_u8\(AIBP_ModeKey' -or $reset -match 'set_u16\(AIBP_PlanKey\(team, "version"\)' -or
    $reset -match 'history ids team' -or $reset -match 'aib strategy next plan id') {
    throw 'Round reset must preserve administrator mode, monotonic plan version/id allocation, and archived history'
}
$archiveAt = $reset.IndexOf('AIBP_ArchiveCurrentPlan(team, "round_reset");')
$clearIdAt = $reset.IndexOf('rules.set_u16(AIBP_PlanKey(team, "id"), 0);')
$replaceAt = $reset.IndexOf('rules.set_u8(AIBP_PlanKey(team, "status"), 3);')
if ($replaceAt -lt 0 -or $archiveAt -le $replaceAt -or $clearIdAt -le $archiveAt) {
    throw 'Unfinished plan must be closed, archived, and only then cleared at the round boundary'
}
if (!$boundaries.Contains('if (reason == "round_reset") return 6;')) {
    throw 'Round-reset plan archives need a stable telemetry reason code'
}

$track = [regex]::Match($data, 'void AIBP_TrackLooseReservation[\s\S]*?\n\}').Value
$clear = [regex]::Match($data, 'void AIBP_ClearTeamLooseReservations[\s\S]*?\n\}').Value
$release = [regex]::Match($data, 'void AIBP_ReleaseLooseBuilderReservation[\s\S]*?\n\}').Value
$reserve = [regex]::Match($data, 'bool AIBP_ReserveLooseTask[\s\S]*?\n\}').Value
if (!$track -or !$clear -or !$release -or !$reserve) { throw 'Loose-reservation lifecycle helpers are incomplete' }
foreach ($needle in @(
    'aib blueprint loose reservation registry x team',
    'if (xs.length != ys.length)',
    'xs.push_back(x); ys.push_back(y);'
)) {
    if (!$track.Contains($needle)) { throw "Loose reservation registry is missing: $needle" }
}
foreach ($needle in @(
    'AIBP_ClearLooseReservationAt(team, xs[i], ys[i]);',
    'rules.set(xKey, emptyX); rules.set(yKey, emptyY);',
    'rules.set_bool(AIBP_BuilderLooseReservationKey(team, builder.getNetworkID(), "active"), false);'
)) {
    if (!$clear.Contains($needle)) { throw "Round reset does not drain loose reservations: $needle" }
}
if (!$reserve.Contains('AIBP_TrackLooseReservation(team, x, y);')) {
    throw 'New loose reservations are not registered for bounded round cleanup'
}
$ownerGuard = $release.IndexOf('if (rules.get_netid(ownerKey) == builderNetID)')
$untilClear = $release.IndexOf('rules.set_u32(AIBP_LooseReservationKey(team, x, y, "until"), 0);')
if ($ownerGuard -lt 0 -or $untilClear -le $ownerGuard) {
    throw 'A stale builder may clear another builder reservation expiry'
}

function Release-Loose([int]$Owner, [int]$Until, [int]$Builder) {
    if ($Owner -eq $Builder) { return [pscustomobject]@{ Owner = 0; Until = 0 } }
    return [pscustomobject]@{ Owner = $Owner; Until = $Until }
}
$foreign = Release-Loose 22 900 11
if ($foreign.Owner -ne 22 -or $foreign.Until -ne 900) { throw 'Stale release damaged the current owner lease' }
$owned = Release-Loose 22 900 22
if ($owned.Owner -ne 0 -or $owned.Until -ne 0) { throw 'Owner release did not clear its own lease' }

Write-Output 'AIB per-round plan and loose-reservation reset contract passed'
