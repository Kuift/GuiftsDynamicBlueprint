$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$data = Get-Content -LiteralPath (Join-Path $root 'Scripts\BlueprintData.as') -Raw
$boundaries = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBActionBoundaryCommon.as') -Raw
$scenarios = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBTestScenarios.as') -Raw

$single = [regex]::Match($data, 'bool AIBP_SetHumanTile[\s\S]*?\n\}').Value
$prefab = [regex]::Match($data, 'bool AIBP_ApplyHumanPlacement[\s\S]*?\n\}').Value
$priority = [regex]::Match($data, 'bool AIBP_ApplyHumanPriorityAt[\s\S]*?\n\}').Value
if (!$single -or !$prefab -or !$priority) { throw 'Human blueprint mutation/priority helpers are missing' }

foreach ($needle in @(
    'if (value != 0) AIBP_ApplyHumanPriorityAt(team, x, y);',
    'rules.set_u16(versionKey, currentVersion + 1);'
)) {
    if (!$single.Contains($needle)) { throw "Single-tile human priority is incomplete: $needle" }
}
$versionAt = $single.IndexOf('rules.set_u16(versionKey, currentVersion + 1);')
$priorityAt = $single.IndexOf('AIBP_ApplyHumanPriorityAt(team, x, y);')
if ($versionAt -lt 0 -or $priorityAt -le $versionAt) {
    throw 'Human edit version must advance before priority cancellation can emit a replacement snapshot'
}
foreach ($needle in @(
    'array<u16> overrideXs; array<u16> overrideYs;',
    'if (value != 0) { overrideXs.push_back(u16(tx)); overrideYs.push_back(u16(ty)); }',
    'AIBP_ApplyHumanPriorityAt(team, overrideXs[i], overrideYs[i]);'
)) {
    if (!$prefab.Contains($needle)) { throw "Prefab human priority is incomplete: $needle" }
}

foreach ($needle in @(
    'AIBP_ClearLooseReservationAt(team, x, y);',
    'desired[index] = 0;',
    'work[index] = 0;',
    'states[i] = AIBP_TaskState::cancelled;',
    'reserved[i] = 0;',
    'untils[i] = 0;',
    'rules.set_u16(AIBP_PlanKey(team, "pending"), pending);',
    'rules.set_u16(AIBP_PlanKey(team, "completed"), completed);',
    'rules.set_u16(AIBP_PlanKey(team, "damaged"), damaged);',
    'rules.set_u32("aib strategy important event team " + int(team), getGameTime());',
    'if (pending == 0 && rules.get_u8(AIBP_PlanKey(team, "status")) == 1)',
    'AIBP_CancelCurrentPlan(team, "human_override");'
)) {
    if (!$priority.Contains($needle)) { throw "Human ownership does not durably retire conflicting AI work: $needle" }
}
if (!$boundaries.Contains('if (reason == "human_override") return 7;')) {
    throw 'Human-override plan closure needs a stable telemetry reason code'
}
foreach ($needle in @(
    'A player claim made after publication must permanently retire the',
    'desired[humanIndex] == 0 && desired[aiIndex] == AIBP_STONE_BLOCK',
    'states[0] == AIBP_TaskState::cancelled && states[1] == AIBP_TaskState::pending',
    'human_override_durable=true'
)) {
    if (!$scenarios.Contains($needle)) { throw "Dynamic human-priority engine fixture is missing: $needle" }
}

function Apply-HumanOverride {
    param([int[]]$States, [int[]]$Reserved, [int[]]$Untils, [int]$TaskIndex, [bool]$HumanValue)
    $nextStates = @($States)
    $nextReserved = @($Reserved)
    $nextUntils = @($Untils)
    if ($HumanValue -and $TaskIndex -ge 0 -and $TaskIndex -lt $nextStates.Count -and $nextStates[$TaskIndex] -ne 3) {
        $nextStates[$TaskIndex] = 3
        $nextReserved[$TaskIndex] = 0
        $nextUntils[$TaskIndex] = 0
    }
    $pending = @($nextStates | Where-Object { $_ -eq 0 -or $_ -eq 1 }).Count
    $completed = @($nextStates | Where-Object { $_ -eq 2 }).Count
    [pscustomobject]@{ States=$nextStates; Reserved=$nextReserved; Untils=$nextUntils; Pending=$pending; Completed=$completed }
}

$partial = Apply-HumanOverride @(1,0,2) @(41,0,0) @(900,0,0) 0 $true
if ($partial.States[0] -ne 3 -or $partial.Reserved[0] -ne 0 -or $partial.Untils[0] -ne 0 -or
    $partial.Pending -ne 1 -or $partial.Completed -ne 1) {
    throw 'Partial human override did not cancel only the claimed AI task and preserve remaining work'
}
$completed = Apply-HumanOverride @(2) @(0) @(0) 0 $true
if ($completed.States[0] -ne 3 -or $completed.Completed -ne 0) {
    throw 'Human ownership of completed AI coordinates must prevent later AI repair/revival'
}
$erase = Apply-HumanOverride @(0) @(52) @(950) 0 $false
if ($erase.States[0] -ne 0 -or $erase.Reserved[0] -ne 52 -or $erase.Untils[0] -ne 950) {
    throw 'Erasing a human blueprint cell must not cancel underlying AI ownership'
}

Write-Output 'AIB durable human-over-AI blueprint ownership contract passed'
