$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$brain = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as') -Raw
$manual = Get-Content -LiteralPath (Join-Path $root 'Scripts\AIBManualOrderCommon.as') -Raw
$blob = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilder.as') -Raw
$orb = Get-Content -LiteralPath (Join-Path $root 'Base\Entities\Characters\AutoBuilder\AutoBuilder.as') -Raw
$renderer = Get-Content -LiteralPath (Join-Path $root 'Scripts\CustomRenderer.as') -Raw

if (!$brain.Contains('#define SERVER_ONLY')) {
    throw 'Public AI state heartbeat is no longer server-authoritative'
}
if (!$brain.Contains('const u32 AIB_PUBLIC_STATE_SYNC_RATE = 5 * 30;')) {
    throw 'Public AI state no longer has a bounded five-second resync rate'
}

$syncStart = $brain.IndexOf('void AIB_SyncPublicState(')
$syncEnd = $brain.IndexOf('void AIB_Debug(', $syncStart)
if ($syncStart -lt 0 -or $syncEnd -le $syncStart) {
    throw 'Public AI state sync helper could not be isolated'
}
$sync = $brain.Substring($syncStart, $syncEnd - $syncStart)
foreach ($needle in @(
    '(now + u32(blob.getNetworkID())) % AIB_PUBLIC_STATE_SYNC_RATE',
    'blob.Sync("ai builder state", true);',
    'blob.Sync("ai builder job", true);',
    'blob.Sync("ai builder job active", true);'
)) {
    if (!$sync.Contains($needle)) { throw "Public AI state heartbeat is incomplete: $needle" }
}

$initStart = $brain.IndexOf('void onInit(CBrain@ this)')
$tickStart = $brain.IndexOf('void onTick(CBrain@ this)', $initStart)
$autoTickStart = $brain.IndexOf('void AIB_TickAutoBuilder(', $tickStart)
if ($initStart -lt 0 -or $tickStart -le $initStart -or $autoTickStart -le $tickStart) {
    throw 'AI brain initialization/tick blocks could not be isolated'
}
$init = $brain.Substring($initStart, $tickStart - $initStart)
$tick = $brain.Substring($tickStart, $autoTickStart - $tickStart)
if (!$init.Contains('AIB_SyncPublicState(blob, true);')) {
    throw 'AI builder creation does not publish its authoritative initial job/state'
}
$heartbeat = $tick.IndexOf('AIB_SyncPublicState(blob, false);')
$attachedExit = $tick.IndexOf('if (blob.isAttached())')
if ($heartbeat -lt 0 -or $attachedExit -le $heartbeat) {
    throw 'Public AI state heartbeat can be skipped indefinitely while a builder is attached'
}

foreach ($source in @($manual, $blob, $orb, $renderer)) {
    if ($source.Contains('set_u8("ai builder state"') -and
        (!$source.Contains('Sync("ai builder state", true)') -or
         !$source.Contains('Sync("ai builder job", true)') -or
         !$source.Contains('Sync("ai builder job active", true)'))) {
        throw 'A production AI order path mutates public job/state without immediate trio sync'
    }
}

$knownWriters = @(
    (Join-Path $root 'Scripts\AIBManualOrderCommon.as'),
    (Join-Path $root 'Scripts\CustomRenderer.as'),
    (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilder.as'),
    (Join-Path $root 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as'),
    (Join-Path $root 'Base\Entities\Characters\AutoBuilder\AutoBuilder.as')
)
$productionFiles = Get-ChildItem -LiteralPath (Join-Path $root 'Base'), (Join-Path $root 'Scripts') -Recurse -Filter '*.as'
foreach ($file in $productionFiles) {
    if ($file.Name -eq 'AIBTestScenarios.as') { continue }
    $source = Get-Content -LiteralPath $file.FullName -Raw
    if (($source.Contains('set_u8("ai builder state"') -or $source.Contains('set_u8("ai builder job"') -or
         $source.Contains('set_bool("ai builder job active"')) -and $knownWriters -notcontains $file.FullName) {
        throw "A new public AI state writer bypasses the audited sync paths: $($file.FullName)"
    }
}
if (!$brain.Contains('blob.Sync("ai builder state", true);') -or
    !$brain.Contains('blob.Sync("ai builder job", true);')) {
    throw 'Brain transitions no longer immediately publish public AI state'
}

$hudStart = $renderer.IndexOf('void RenderAIBuilderResourceCounters()')
if ($hudStart -lt 0) { throw 'Advanced HUD builder-role summary could not be located' }
$hud = $renderer.Substring($hudStart)
if (!$hud.Contains('if(builder.get_u8("ai builder state") == AIB_RENDERER_STATE_IDLE) continue;') -or
    !$hud.Contains('const u8 job = builder.get_u8("ai builder job");')) {
    throw 'Advanced HUD no longer derives active resource roles from synced state/job'
}
if ($brain.Contains('"ai builder resource role"') -or $renderer.Contains('"ai builder resource role"')) {
    throw 'A redundant resource-role property was introduced instead of using the canonical job enum'
}

Write-Output 'AIB public job/state synchronization contract passed'
