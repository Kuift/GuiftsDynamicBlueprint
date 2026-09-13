$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$input = Join-Path $env:TEMP 'aib-player-episode-input.ndjson'
$output = Join-Path $env:TEMP 'aib-player-episode-output.ndjson'
$source = 'fixture.log'
$rows = @(
    [ordered]@{schema=2;episode=1;batch=1;tick=0;raw_log=$source;action='episode';map_hash=99},
    [ordered]@{schema=2;episode=1;batch=1;tick=0;raw_log=$source;action='spawn';player=1;blob=10;team=0;class_code=1;x=0;y=0},
    [ordered]@{schema=2;episode=1;batch=1;tick=1;raw_log=$source;action='delta';player=1;flags=9;buttons=2;x=0;y=0;vel_x10=1;vel_y10=0},
    [ordered]@{schema=2;episode=1;batch=1;tick=31;raw_log=$source;action='delta';player=1;flags=8;x=30;y=0;vel_x10=1;vel_y10=0},
    [ordered]@{schema=2;episode=1;batch=1;tick=32;raw_log=$source;action='inventory';player=1;mask=35;wood=100;stone=0;coins=0},
    [ordered]@{schema=3;episode=1;batch=1;tick=35;event_tick=34;raw_log=$source;action='boundary';boundary_opcode=1;boundary='human_blueprint_delta';actor_kind_code=1;actor_kind='player';actor=1;subject=2;team=0;x=4;y=5;detail=4;value=0},
    [ordered]@{schema=2;episode=1;batch=1;tick=40;raw_log=$source;action='tile';player=1;attribution=2;x=4;y=5;old_tile=0;new_tile=196},
    [ordered]@{schema=2;episode=1;batch=1;tick=41;raw_log=$source;action='inventory';player=1;mask=1;wood=90},
    [ordered]@{schema=3;episode=1;batch=1;tick=42;event_tick=42;raw_log=$source;action='boundary';boundary_opcode=11;boundary='purchase';actor_kind_code=1;actor_kind='player';actor=1;subject=50;team=0;x=4;y=5;detail=3;value=50},
    [ordered]@{schema=3;episode=1;batch=1;tick=43;raw_log=$source;action='boundary_loss';dropped=2},
    [ordered]@{schema=2;episode=1;batch=1;tick=50;raw_log=$source;action='death';victim_player=1;killer_player=2;blob=10;team=0;entity_class=1;name_hash=1;x=30;y=0}
)
@($rows | ForEach-Object { [pscustomobject]$_ | ConvertTo-Json -Compress }) | Set-Content -LiteralPath $input -Encoding utf8

& (Join-Path $root 'Tools\summarize_aib_player_episodes.ps1') -InputPath $input -OutputPath $output
$episodes = @(Get-Content -LiteralPath $output | ForEach-Object { $_ | ConvertFrom-Json })
$player = $episodes | Where-Object player -eq 1 | Select-Object -First 1
if ($null -eq $player) { throw 'Missing player-1 episode' }
if ($player.schema -ne 'aib_task_episode_v1' -or $player.task -ne 'build' -or !$player.success) { throw 'Episode classification failed' }
if ($player.duration_ticks -ne 49 -or $player.travel_px -ne 30 -or $player.tile_placed -ne 1) { throw 'Episode motion/outcome aggregation failed' }
if ($player.wood_gain -ne 100 -or $player.wood_spent -ne 10 -or $player.deaths -ne 1) { throw 'Episode resource/death aggregation failed' }
if ($player.attributed_outcome_weight -ne 0.667 -or $player.low_confidence_outcomes -ne 0 -or [string]::IsNullOrWhiteSpace($player.context_key_v1)) { throw 'Episode attribution/context aggregation failed' }
if ($player.authoritative_boundaries -ne 2 -or $player.blueprint_edits -ne 1 -or $player.overseer_orders -ne 0 -or $player.purchases -ne 1 -or $player.purchase_value -ne 50) { throw 'Authoritative boundary aggregation failed' }
if ($player.boundary_records_dropped -ne 2) { throw 'Boundary loss was not retained on the episode' }
if ($player.estimated_cost_v1 -le 0) { throw 'Episode cost was not produced' }
Write-Host 'AIB player episode summarizer tests passed'
