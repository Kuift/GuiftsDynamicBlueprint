param(
    [Parameter(Mandatory = $true)] [string[]]$LogPath,
    [string]$OutputPath
)

function Read-U8([byte[]]$Bytes, [ref]$Offset) { $v = $Bytes[$Offset.Value]; $Offset.Value++; return [uint16]$v }
function Read-S8([byte[]]$Bytes, [ref]$Offset) { $v = Read-U8 $Bytes $Offset; return [int]($v -ge 128 ? $v - 256 : $v) }
function Read-U16([byte[]]$Bytes, [ref]$Offset) { $v = [BitConverter]::ToUInt16($Bytes, $Offset.Value); $Offset.Value += 2; return $v }
function Read-S16([byte[]]$Bytes, [ref]$Offset) { $v = [BitConverter]::ToInt16($Bytes, $Offset.Value); $Offset.Value += 2; return $v }
function Read-U32([byte[]]$Bytes, [ref]$Offset) { $v = [BitConverter]::ToUInt32($Bytes, $Offset.Value); $Offset.Value += 4; return $v }

$records = [System.Collections.Generic.List[object]]::new()
$episodeTicks = @{}
foreach ($path in $LogPath) {
    foreach ($line in Get-Content -LiteralPath $path) {
        if ($line -notmatch '\[AIBACT\]\s+v=(\d+)\s+episode=(\d+)\s+batch=(\d+)\s+records=(\d+)\s+reason=([^\s]+)\s+data=([^\s]+)') { continue }
        $schema = [int]$Matches[1]; $episode = [int]$Matches[2]; $batch = [int]$Matches[3]
        $expected = [int]$Matches[4]; $source = (Resolve-Path -LiteralPath $path).Path
        $tickKey = "$source|$episode"
        $bytes = [Convert]::FromBase64String($Matches[6]); $offset = 0
        $tick = if ($episodeTicks.ContainsKey($tickKey)) { [int64]$episodeTicks[$tickKey] } else { [int64]0 }
        $decoded = 0
        while ($offset -lt $bytes.Length) {
            $kind = Read-U8 $bytes ([ref]$offset); $tick += Read-U16 $bytes ([ref]$offset)
            $r = [ordered]@{ schema=$schema; episode=$episode; batch=$batch; tick=$tick; raw_log=$source }
            switch ($kind) {
                0 { $r.action='episode'; $r.map_hash=Read-U32 $bytes ([ref]$offset) }
                1 { $r.action='join'; $r.player=Read-U16 $bytes ([ref]$offset); $r.team=Read-U8 $bytes ([ref]$offset) }
                2 { $r.action='leave'; $r.player=Read-U16 $bytes ([ref]$offset); $r.team=Read-U8 $bytes ([ref]$offset) }
                3 {
                    $r.action='spawn'; $r.player=Read-U16 $bytes ([ref]$offset); $r.blob=Read-U16 $bytes ([ref]$offset)
                    $r.team=Read-U8 $bytes ([ref]$offset); $r.class_code=Read-U8 $bytes ([ref]$offset)
                    $r.x=Read-S16 $bytes ([ref]$offset); $r.y=Read-S16 $bytes ([ref]$offset)
                }
                4 {
                    $r.action='delta'; $r.player=Read-U16 $bytes ([ref]$offset); $flags=Read-U8 $bytes ([ref]$offset); $r.flags=$flags
                    if ($flags -band 1) { $r.buttons=Read-U8 $bytes ([ref]$offset) }
                    if ($flags -band 2) { $r.aim_x=Read-S8 $bytes ([ref]$offset); $r.aim_y=Read-S8 $bytes ([ref]$offset) }
                    if ($flags -band 4) {
                        $r.build_page=Read-U8 $bytes ([ref]$offset); $r.build_blob=Read-U8 $bytes ([ref]$offset)
                        $r.build_tile=Read-U16 $bytes ([ref]$offset); $r.carried=Read-U16 $bytes ([ref]$offset)
                    }
                    if ($flags -band 8) {
                        $r.x=Read-S16 $bytes ([ref]$offset); $r.y=Read-S16 $bytes ([ref]$offset)
                        $r.vel_x10=Read-S8 $bytes ([ref]$offset); $r.vel_y10=Read-S8 $bytes ([ref]$offset)
                    }
                }
                5 {
                    $r.action='tile'; $r.player=Read-U16 $bytes ([ref]$offset); $r.attribution=Read-U8 $bytes ([ref]$offset)
                    $r.x=Read-U16 $bytes ([ref]$offset); $r.y=Read-U16 $bytes ([ref]$offset)
                    $r.old_tile=Read-U16 $bytes ([ref]$offset); $r.new_tile=Read-U16 $bytes ([ref]$offset)
                }
                6 {
                    $r.action='blob_create'; $r.player=Read-U16 $bytes ([ref]$offset); $r.attribution=Read-U8 $bytes ([ref]$offset)
                    $r.blob=Read-U16 $bytes ([ref]$offset); $r.team=Read-U8 $bytes ([ref]$offset); $r.entity_class=Read-U8 $bytes ([ref]$offset)
                    $r.name_hash=Read-U32 $bytes ([ref]$offset); $r.x=Read-S16 $bytes ([ref]$offset); $r.y=Read-S16 $bytes ([ref]$offset)
                }
                7 {
                    $r.action='death'; $r.victim_player=Read-U16 $bytes ([ref]$offset); $r.killer_player=Read-U16 $bytes ([ref]$offset)
                    $r.blob=Read-U16 $bytes ([ref]$offset); $r.team=Read-U8 $bytes ([ref]$offset); $r.entity_class=Read-U8 $bytes ([ref]$offset)
                    $r.name_hash=Read-U32 $bytes ([ref]$offset); $r.x=Read-S16 $bytes ([ref]$offset); $r.y=Read-S16 $bytes ([ref]$offset)
                }
                8 {
                    $r.action='inventory'; $r.player=Read-U16 $bytes ([ref]$offset); $mask=Read-U8 $bytes ([ref]$offset); $r.mask=$mask
                    if ($mask -band 1) { $r.wood=Read-U16 $bytes ([ref]$offset) }
                    if ($mask -band 2) { $r.stone=Read-U16 $bytes ([ref]$offset) }
                    if ($mask -band 4) { $r.gold=Read-U16 $bytes ([ref]$offset) }
                    if ($mask -band 8) { $r.arrows=Read-U16 $bytes ([ref]$offset) }
                    if ($mask -band 16) { $r.explosives=Read-U16 $bytes ([ref]$offset) }
                    if ($mask -band 32) { $r.coins=Read-U16 $bytes ([ref]$offset) }
                }
                default { throw "Unknown AIB action record kind $kind in $path batch $batch" }
            }
            $records.Add([pscustomobject]$r); $decoded++
        }
        $episodeTicks[$tickKey] = $tick
        if ($decoded -ne $expected) { throw "Batch $batch expected $expected records but decoded $decoded" }
    }
}

if ($OutputPath) {
    $lines = foreach ($record in $records) { $record | ConvertTo-Json -Compress }
    [IO.File]::WriteAllLines($OutputPath, [string[]]$lines, [Text.UTF8Encoding]::new($false))
    Write-Host "AIB player actions exported: $($records.Count) records -> $OutputPath"
} else { $records }
