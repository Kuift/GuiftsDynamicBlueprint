$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path $env:TEMP 'aib-player-action-parser-fixture.log'
$output = Join-Path $env:TEMP 'aib-player-action-parser-output.ndjson'
$bytes = [Collections.Generic.List[byte]]::new()
function Add-U8($v) { $bytes.Add([byte]$v) }
function Add-U16($v) { $bytes.AddRange([BitConverter]::GetBytes([uint16]$v)) }
function Add-S16($v) { $bytes.AddRange([BitConverter]::GetBytes([int16]$v)) }
function Add-U32($v) { $bytes.AddRange([BitConverter]::GetBytes([uint32]$v)) }

Add-U8 0; Add-U16 0; Add-U32 10
Add-U8 1; Add-U16 7; Add-U16 40; Add-U8 0
Add-U8 3; Add-U16 11; Add-U16 40; Add-U16 41; Add-U8 0; Add-U8 1; Add-S16 220; Add-S16 396
Add-U8 4; Add-U16 0; Add-U16 40; Add-U8 15; Add-U8 18; Add-U8 4; Add-U8 255
Add-U8 0; Add-U8 255; Add-U16 0; Add-U16 0; Add-S16 220; Add-S16 396; Add-U8 1; Add-U8 0
$data = [Convert]::ToBase64String($bytes.ToArray())
$line1 = "[AIBACT] v=1 episode=3 batch=1 records=4 reason=interval data=$data"

$bytes2 = [Collections.Generic.List[byte]]::new()
function Add2-U8($v) { $bytes2.Add([byte]$v) }
function Add2-U16($v) { $bytes2.AddRange([BitConverter]::GetBytes([uint16]$v)) }
function Add2-S16($v) { $bytes2.AddRange([BitConverter]::GetBytes([int16]$v)) }
function Add2-U32($v) { $bytes2.AddRange([BitConverter]::GetBytes([uint32]$v)) }
Add2-U8 5; Add2-U16 3; Add2-U16 40; Add2-U8 2; Add2-U16 10; Add2-U16 20; Add2-U16 0; Add2-U16 48
Add2-U8 6; Add2-U16 1; Add2-U16 40; Add2-U8 3; Add2-U16 50; Add2-U8 0; Add2-U8 3; Add2-U32 123; Add2-S16 80; Add2-S16 160
Add2-U8 7; Add2-U16 2; Add2-U16 40; Add2-U16 41; Add2-U16 41; Add2-U8 0; Add2-U8 1; Add2-U32 456; Add2-S16 220; Add2-S16 396
Add2-U8 8; Add2-U16 1; Add2-U16 40; Add2-U8 35; Add2-U16 100; Add2-U16 50; Add2-U16 20
$line2 = "[AIBACT] v=2 episode=4 batch=1 records=4 reason=interval data=$([Convert]::ToBase64String($bytes2.ToArray()))"

$bytes3 = [Collections.Generic.List[byte]]::new()
function Add3-U8($v) { $bytes3.Add([byte]$v) }
function Add3-U16($v) { $bytes3.AddRange([BitConverter]::GetBytes([uint16]$v)) }
function Add3-U32($v) { $bytes3.AddRange([BitConverter]::GetBytes([uint32]$v)) }
Add3-U8 9; Add3-U16 4; Add3-U32 1234; Add3-U8 1; Add3-U8 1; Add3-U16 40; Add3-U16 9; Add3-U8 0; Add3-U16 12; Add3-U16 20; Add3-U16 4; Add3-U16 7
Add3-U8 9; Add3-U16 2; Add3-U32 1236; Add3-U8 9; Add3-U8 2; Add3-U16 88; Add3-U16 9; Add3-U8 0; Add3-U16 12; Add3-U16 20; Add3-U16 4; Add3-U16 10
Add3-U8 10; Add3-U16 1; Add3-U16 3
$line3 = "[AIBACT] v=3 episode=5 batch=1 records=3 reason=interval data=$([Convert]::ToBase64String($bytes3.ToArray()))"
@($line1, $line2, $line3) | Set-Content -LiteralPath $fixture -Encoding utf8

& (Join-Path $root 'Tools\parse_aib_player_actions.ps1') -LogPath $fixture -OutputPath $output
$rows = @(Get-Content -LiteralPath $output | ForEach-Object { $_ | ConvertFrom-Json })
if ($rows.Count -ne 11) { throw "Expected 11 records, got $($rows.Count)" }
if ($rows[2].action -ne 'spawn' -or $rows[2].x -ne 220 -or $rows[2].class_code -ne 1) { throw 'Spawn delta decode failed' }
if ($rows[3].buttons -ne 18 -or $rows[3].aim_x -ne 4 -or $rows[3].aim_y -ne -1 -or $rows[3].y -ne 396) { throw 'Combined delta decode failed' }
if ($rows[4].action -ne 'tile' -or $rows[4].new_tile -ne 48 -or $rows[4].attribution -ne 2) { throw 'Tile outcome decode failed' }
if ($rows[5].action -ne 'blob_create' -or $rows[5].name_hash -ne 123 -or $rows[5].entity_class -ne 3) { throw 'Blob creation decode failed' }
if ($rows[6].action -ne 'death' -or $rows[6].killer_player -ne 41 -or $rows[6].victim_player -ne 40) { throw 'Death outcome decode failed' }
if ($rows[7].action -ne 'inventory' -or $rows[7].wood -ne 100 -or $rows[7].stone -ne 50 -or $rows[7].coins -ne 20) { throw 'Inventory delta decode failed' }
if ($rows[8].action -ne 'boundary' -or $rows[8].boundary -ne 'human_blueprint_delta' -or $rows[8].actor_kind -ne 'player' -or $rows[8].event_tick -ne 1234 -or $rows[8].detail -ne 4) { throw 'Player boundary decode failed' }
if ($rows[9].boundary -ne 'task_complete' -or $rows[9].actor_kind -ne 'ai_builder' -or $rows[9].actor -ne 88 -or $rows[9].value -ne 10) { throw 'AI task boundary decode failed' }
if ($rows[10].action -ne 'boundary_loss' -or $rows[10].dropped -ne 3) { throw 'Boundary loss decode failed' }
Write-Host 'AIB compact player action parser tests passed'
