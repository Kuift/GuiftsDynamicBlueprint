$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $root 'Scripts\AIBGymCommon.as'
$monitorPath = Join-Path $root 'Scripts\AIBGymMonitor.as'
$brainPath = Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as'
$assertionsPath = Join-Path $root 'Scripts\AIBTestAssertions.as'
$scenariosPath = Join-Path $root 'Scripts\AIBTestScenarios.as'
$common = Get-Content -LiteralPath $commonPath -Raw
$monitor = Get-Content -LiteralPath $monitorPath -Raw
$monitorContract = $common + $monitor
$brain = Get-Content -LiteralPath $brainPath -Raw
$consumers = (Get-Content -LiteralPath $assertionsPath -Raw) + (Get-Content -LiteralPath $scenariosPath -Raw)

$flags = [ordered]@{
    AIBG_FAILURE_MOTION_STALL = 1
    AIBG_FAILURE_JUMP_LOOP = 2
    AIBG_FAILURE_PATH_THRASH = 4
    AIBG_FAILURE_NO_INTENT = 8
    AIBG_FAILURE_TARGET_THRASH = 16
    AIBG_FAILURE_STATE_STALL = 32
    AIBG_FAILURE_RESOURCE_DEADLOCK = 64
    AIBG_FAILURE_RESERVATION_DEADLOCK = 128
    AIBG_FAILURE_INVALID_BUILD = 256
}
foreach ($entry in $flags.GetEnumerator()) {
    if ($monitorContract -notmatch ('const u16\s+' + $entry.Key + '\s*=\s*' + $entry.Value + ';')) {
        throw "Missing 16-bit gym failure flag $($entry.Key)=$($entry.Value)"
    }
}
foreach ($needle in @(
    'AIBG_FAILURE_NO_INTENT', 'AIBG_FAILURE_TARGET_THRASH', 'AIBG_FAILURE_STATE_STALL',
    'AIBG_FAILURE_RESOURCE_DEADLOCK', 'AIBG_FAILURE_RESERVATION_DEADLOCK', 'AIBG_FAILURE_INVALID_BUILD',
    'bool AIBG_HasStaleReservation', 'bool AIBG_HasAccessibleBlueprintResource',
    'void AIBG_RecordInvalidBuild', 'targetChanges >= AIBG_TARGET_THRASH_CHANGES',
    'invalidAttempts >= AIBG_INVALID_BUILD_ATTEMPTS', 'maxMove < AIBG_STALL_DISPLACEMENT',
    'AIBG_OUTCOME_SAMPLE_TICKS',
    'AIBG_PRE_SAMPLES', 'AIBG_POST_SAMPLES', 'AIBG_POST_TICKS',
    'void AIBG_SampleDiagnostic', 'void AIBG_EmitDiagnosticWindow', '[AIBGYMW] data=',
    '[AIBGYM] v=1 t='
)) {
    if (!$monitorContract.Contains($needle)) { throw "Gym monitor contract is missing: $needle" }
}
if (!$monitor.Contains('#include "AIBGymCommon.as";')) { throw 'Brain-side gym monitor does not import the shared schema' }
if ((Get-Content -LiteralPath $assertionsPath -Raw) -notmatch '#include\s+"AIBGymCommon\.as"' -or
    (Get-Content -LiteralPath $assertionsPath -Raw) -match '#include\s+"AIBGymMonitor\.as"') {
    throw 'Rules-side test assertions must import only the context-independent gym schema'
}
foreach ($forbidden in @('setKeyPressed(', 'server_Hit(', 'AIB_SetState(', '.SetPath(', 'server_SetTile(')) {
    if ($monitor.Contains($forbidden)) { throw "Passive gym monitor contains behavior mutation: $forbidden" }
}
foreach ($reason in @('placement_invalid','workshop_revalidation','missing_blob_catalog','blob_creation_failed')) {
    if ($brain -notmatch ('AIBG_RecordInvalidBuild\(blob,\s*"' + $reason + '"\)')) { throw "Build retry instrumentation missing: $reason" }
}
if ($brain -notmatch 'state != AIBuilderState::idle \|\| blob\.get_bool\("ai builder job active"\)') {
    throw 'Active jobs that fall idle are not monitorable'
}
if ($consumers -match 'get_u8\("aib gym failure flags"\)') { throw 'A gym failure consumer still truncates 16-bit flags' }
if ($consumers -notmatch 'get_u16\("aib gym failure flags"\)') { throw 'No test consumer reads 16-bit gym flags' }

Write-Output 'AIB advanced passive gym monitor contract passed'
