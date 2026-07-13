param(
    [Parameter(Mandatory = $true)] [string[]]$InputPath,
    [Parameter(Mandatory = $true)] [string]$OutputPath,
    [int]$IdleGapTicks = 150
)

$ErrorActionPreference = 'Stop'
$rows = foreach ($path in $InputPath) {
    Get-Content -LiteralPath $path | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json }
}

$profiles = @{}
$active = @{}
$episodeCounters = @{}
$mapHashes = @{}
$boundaryLosses = @{}
$results = [Collections.Generic.List[object]]::new()

function Context-Key($row) { return "$($row.raw_log)|$($row.episode)" }
function Player-Key($row, [int]$player) { return "$(Context-Key $row)|$player" }

foreach ($row in $rows) {
    if ($row.action -ne 'boundary_loss') { continue }
    $key = Context-Key $row
    $currentLoss = if ($boundaryLosses.ContainsKey($key)) { [int]$boundaryLosses[$key] } else { 0 }
    $boundaryLosses[$key] = $currentLoss + [int]$row.dropped
}

function Get-Profile($row, [int]$player) {
    $key = Player-Key $row $player
    if (!$profiles.ContainsKey($key)) {
        $profiles[$key] = @{
            team = -1; class_code = 0; x = $null; y = $null; buttons = 0
            wood = 0; stone = 0; gold = 0; arrows = 0; explosives = 0; coins = 0
        }
    }
    return $profiles[$key]
}

function Start-Episode($row, [int]$player, [string]$cause) {
    $key = Player-Key $row $player
    $profile = Get-Profile $row $player
    $counter = if ($episodeCounters.ContainsKey($key)) { [int]$episodeCounters[$key] + 1 } else { 1 }
    $episodeCounters[$key] = $counter
    $active[$key] = @{
        player = $player; task_episode = $counter; source_episode = [int]$row.episode
        raw_log = [string]$row.raw_log; map_hash = $mapHashes[(Context-Key $row)]
        boundary_records_dropped = $(if ($boundaryLosses.ContainsKey((Context-Key $row))) { [int]$boundaryLosses[(Context-Key $row)] } else { 0 })
        team = [int]$profile.team; class_code = [int]$profile.class_code
        start_tick = [int64]$row.tick; last_tick = [int64]$row.tick; last_activity_tick = [int64]$row.tick
        start_x = $profile.x; start_y = $profile.y; end_x = $profile.x; end_y = $profile.y
        travel_px = 0.0; idle_ticks = 0; jumps = 0; previous_buttons = [int]$profile.buttons
        tile_placed = 0; tile_destroyed = 0; blobs_created = 0; kills = 0; deaths = 0
        authoritative_boundaries = 0; blueprint_edits = 0; overseer_orders = 0; director_mode_changes = 0
        purchases = 0; purchase_value = 0
        attributed_outcome_weight = 0.0; low_confidence_outcomes = 0; explicit_outcomes = 0
        wood_gain = 0; wood_spent = 0; stone_gain = 0; stone_spent = 0
        gold_gain = 0; gold_spent = 0; coin_gain = 0; coin_spent = 0
        first_cause = $cause
    }
    return $active[$key]
}

function Finish-Episode([string]$key, [string]$reason) {
    if (!$active.ContainsKey($key)) { return }
    $s = $active[$key]
    $duration = [Math]::Max(0, [int64]$s.last_tick - [int64]$s.start_tick)
    $resourceGain = $s.wood_gain + $s.stone_gain + $s.gold_gain
    $task = if ($s.tile_placed -gt 0 -or $s.blobs_created -gt 0) { 'build' }
        elseif ($s.tile_destroyed -gt 0 -or $s.stone_gain -gt 0 -or $s.gold_gain -gt 0) { 'mine' }
        elseif ($s.wood_gain -gt 0) { 'harvest' }
        elseif ($s.kills -gt 0 -or $s.deaths -gt 0) { 'combat' }
        elseif ($s.blueprint_edits -gt 0) { 'plan_blueprint' }
        elseif ($s.overseer_orders -gt 0 -or $s.director_mode_changes -gt 0) { 'direct_ai' }
        elseif ($s.purchases -gt 0) { 'purchase' }
        else { 'traverse' }
    $success = $s.tile_placed -gt 0 -or $s.blobs_created -gt 0 -or $resourceGain -gt 0 -or $s.kills -gt 0 -or $s.purchases -gt 0
    $cost = [double]$duration + $s.travel_px * 0.10 + $s.idle_ticks * 1.50 + $s.jumps * 12.0 +
        $s.deaths * 900.0 + $s.wood_spent * 0.25 + $s.stone_spent * 0.35 + $s.gold_spent * 0.50 -
        $s.attributed_outcome_weight * 105.0 - $resourceGain * 0.10 - $s.kills * 300.0
    $startCellX = if ($null -eq $s.start_x) { 'na' } else { [Math]::Floor([double]$s.start_x / 64.0) }
    $startCellY = if ($null -eq $s.start_y) { 'na' } else { [Math]::Floor([double]$s.start_y / 64.0) }
    $contextKey = "m$($s.map_hash)-t$($s.team)-c$($s.class_code)-$task-x$startCellX-y$startCellY"
    $results.Add([pscustomobject][ordered]@{
        schema = 'aib_task_episode_v1'; raw_log = $s.raw_log; source_episode = $s.source_episode
        task_episode = $s.task_episode; map_hash = $s.map_hash; player = $s.player; team = $s.team
        class_code = $s.class_code; task = $task; start_tick = $s.start_tick; end_tick = $s.last_tick
        context_key_v1 = $contextKey
        boundary_records_dropped = $s.boundary_records_dropped
        duration_ticks = $duration; end_reason = $reason; success = $success
        start_x = $s.start_x; start_y = $s.start_y; end_x = $s.end_x; end_y = $s.end_y
        travel_px = [Math]::Round($s.travel_px, 2); idle_ticks_estimate = $s.idle_ticks; jumps = $s.jumps
        tile_placed = $s.tile_placed; tile_destroyed = $s.tile_destroyed; blobs_created = $s.blobs_created
        authoritative_boundaries = $s.authoritative_boundaries; blueprint_edits = $s.blueprint_edits
        overseer_orders = $s.overseer_orders; director_mode_changes = $s.director_mode_changes
        purchases = $s.purchases; purchase_value = $s.purchase_value
        attributed_outcome_weight = [Math]::Round($s.attributed_outcome_weight, 3)
        low_confidence_outcomes = $s.low_confidence_outcomes; explicit_outcomes = $s.explicit_outcomes
        kills = $s.kills; deaths = $s.deaths; wood_gain = $s.wood_gain; wood_spent = $s.wood_spent
        stone_gain = $s.stone_gain; stone_spent = $s.stone_spent; gold_gain = $s.gold_gain
        gold_spent = $s.gold_spent; coin_gain = $s.coin_gain; coin_spent = $s.coin_spent
        estimated_cost_v1 = [Math]::Round([Math]::Max(0.0, $cost), 2)
    })
    $active.Remove($key)
}

function Get-Activity($row, [int]$player, [string]$cause) {
    $key = Player-Key $row $player
    if ($active.ContainsKey($key) -and [int64]$row.tick - [int64]$active[$key].last_activity_tick -gt $IdleGapTicks) {
        Finish-Episode $key 'idle_gap'
    }
    $s = if ($active.ContainsKey($key)) { $active[$key] } else { Start-Episode $row $player $cause }
    $gap = [Math]::Max(0, [int64]$row.tick - [int64]$s.last_activity_tick - 30)
    $s.idle_ticks += $gap
    $s.last_tick = [int64]$row.tick
    $s.last_activity_tick = [int64]$row.tick
    return $s
}

function Update-Position($s, $profile, $row) {
    if ($null -eq $row.x -or $null -eq $row.y) { return }
    if ($null -ne $profile.x -and $null -ne $profile.y) {
        $dx = [double]$row.x - [double]$profile.x; $dy = [double]$row.y - [double]$profile.y
        $s.travel_px += [Math]::Sqrt($dx * $dx + $dy * $dy)
    }
    $profile.x = [int]$row.x; $profile.y = [int]$row.y; $s.end_x = $profile.x; $s.end_y = $profile.y
}

function Apply-Quantity($s, $profile, $row, [string]$field, [string]$gainField, [string]$spentField) {
    if ($null -eq $row.$field) { return }
    $old = [int]$profile[$field]; $new = [int]$row.$field; $delta = $new - $old
    if ($delta -gt 0) { $s[$gainField] += $delta } elseif ($delta -lt 0) { $s[$spentField] += -$delta }
    $profile[$field] = $new
}

foreach ($row in $rows) {
    $context = Context-Key $row
    if ($row.action -eq 'episode') { $mapHashes[$context] = $row.map_hash; continue }
    if ($row.action -eq 'spawn') {
        $key = Player-Key $row ([int]$row.player); Finish-Episode $key 'spawn_or_class_change'
        $p = Get-Profile $row ([int]$row.player); $p.team = [int]$row.team; $p.class_code = [int]$row.class_code
        $p.x = [int]$row.x; $p.y = [int]$row.y; $p.buttons = 0; continue
    }
    if ($row.action -eq 'leave') { Finish-Episode (Player-Key $row ([int]$row.player)) 'leave'; continue }

    if ($row.action -eq 'delta') {
        $player = [int]$row.player; $p = Get-Profile $row $player
        $buttons = if ($null -ne $row.buttons) { [int]$row.buttons } else { [int]$p.buttons }
        $moving = $null -ne $row.x -and ($null -eq $p.x -or [int]$row.x -ne [int]$p.x -or [int]$row.y -ne [int]$p.y)
        $activeInput = ($buttons -band 0x7f) -ne 0 -or $moving -or $null -ne $row.build_tile
        if ($activeInput) {
            $s = Get-Activity $row $player 'input_or_motion'; Update-Position $s $p $row
            if (($buttons -band 4) -ne 0 -and ([int]$p.buttons -band 4) -eq 0) { $s.jumps++ }
        }
        $p.buttons = $buttons; continue
    }
    if ($row.action -eq 'inventory') {
        $player = [int]$row.player; $p = Get-Profile $row $player; $s = Get-Activity $row $player 'inventory'
        Apply-Quantity $s $p $row 'wood' 'wood_gain' 'wood_spent'; Apply-Quantity $s $p $row 'stone' 'stone_gain' 'stone_spent'
        Apply-Quantity $s $p $row 'gold' 'gold_gain' 'gold_spent'; Apply-Quantity $s $p $row 'coins' 'coin_gain' 'coin_spent'; continue
    }
    if ($row.action -eq 'boundary' -and $row.actor_kind -eq 'player' -and [int]$row.actor -gt 0) {
        $s = Get-Activity $row ([int]$row.actor) 'authoritative_boundary'; $s.authoritative_boundaries++
        if ($row.boundary -eq 'human_blueprint_delta' -or $row.boundary -eq 'human_blueprint_prefab' -or $row.boundary -eq 'human_blueprint_clear') { $s.blueprint_edits++ }
        elseif ($row.boundary -eq 'overseer_order') { $s.overseer_orders++ }
        elseif ($row.boundary -eq 'director_mode') { $s.director_mode_changes++ }
        elseif ($row.boundary -eq 'purchase') { $s.purchases++; $s.purchase_value += [int]$row.value }
        continue
    }
    if ($row.action -eq 'tile' -and [int]$row.player -gt 0) {
        $s = Get-Activity $row ([int]$row.player) 'tile_outcome'
        $confidence = [Math]::Max(0, [Math]::Min(3, [int]$row.attribution))
        $s.attributed_outcome_weight += [double]$confidence / 3.0
        if ($confidence -eq 3) { $s.explicit_outcomes++ } elseif ($confidence -lt 2) { $s.low_confidence_outcomes++ }
        if ([int]$row.new_tile -eq 0 -and [int]$row.old_tile -ne 0) { $s.tile_destroyed++ } else { $s.tile_placed++ }; continue
    }
    if ($row.action -eq 'blob_create' -and [int]$row.player -gt 0) {
        $s = Get-Activity $row ([int]$row.player) 'blob_create'
        $confidence = [Math]::Max(0, [Math]::Min(3, [int]$row.attribution))
        $s.attributed_outcome_weight += [double]$confidence / 3.0
        if ($confidence -eq 3) { $s.explicit_outcomes++ } elseif ($confidence -lt 2) { $s.low_confidence_outcomes++ }
        $s.blobs_created++; continue
    }
    if ($row.action -eq 'death') {
        if ([int]$row.killer_player -gt 0) { $s = Get-Activity $row ([int]$row.killer_player) 'kill'; $s.kills++ }
        if ([int]$row.victim_player -gt 0) {
            $key = Player-Key $row ([int]$row.victim_player)
            $s = if ($active.ContainsKey($key)) { $active[$key] } else { Start-Episode $row ([int]$row.victim_player) 'death' }
            $s.deaths++; $s.last_tick = [int64]$row.tick; Finish-Episode $key 'death'
        }
    }
}

foreach ($key in @($active.Keys)) { Finish-Episode $key 'end_of_input' }
$lines = foreach ($result in $results) { $result | ConvertTo-Json -Compress }
[IO.File]::WriteAllLines($OutputPath, [string[]]$lines, [Text.UTF8Encoding]::new($false))
Write-Host "AIB player episodes summarized: $($results.Count) episodes -> $OutputPath"
