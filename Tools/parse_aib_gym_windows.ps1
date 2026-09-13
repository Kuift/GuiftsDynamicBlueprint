param(
    [Parameter(Mandatory = $true)] [string[]]$LogPath,
    [Parameter(Mandatory = $true)] [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
function Read-U16([byte[]]$bytes, [ref]$at) {
    if ($at.Value + 2 -gt $bytes.Length) { throw 'Truncated AIBGYMW u16' }
    $value = [uint16](([uint16]$bytes[$at.Value]) -bor (([uint16]$bytes[$at.Value + 1]) -shl 8)); $at.Value += 2; return $value
}
function Read-S16([byte[]]$bytes, [ref]$at) { return [BitConverter]::ToInt16($bytes, (($at.Value += 2) - 2)) }
function Read-U32([byte[]]$bytes, [ref]$at) {
    if ($at.Value + 4 -gt $bytes.Length) { throw 'Truncated AIBGYMW u32' }
    $value = [BitConverter]::ToUInt32($bytes, $at.Value); $at.Value += 4; return $value
}

$records = @()
foreach ($path in $LogPath) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Log not found: $path" }
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $path) {
        $lineNumber++
        if ($line -notmatch '\[AIBGYMW\]\s+data=(?<data>[A-Za-z0-9+/=]+)') { continue }
        try { [byte[]]$bytes = [Convert]::FromBase64String($Matches.data) } catch { throw "Invalid AIBGYMW base64 at ${path}:$lineNumber" }
        if ($bytes.Length -lt 11) { throw "Truncated AIBGYMW header at ${path}:$lineNumber" }
        $at = 0
        $version = $bytes[$at]; $at++
        if ($version -ne 1) { throw "Unsupported AIBGYMW schema v=$version at ${path}:$lineNumber" }
        $builder = Read-U16 $bytes ([ref]$at); $team = $bytes[$at]; $at++
        $failureTick = Read-U32 $bytes ([ref]$at); $flags = Read-U16 $bytes ([ref]$at); $count = $bytes[$at]; $at++
        $expected = 11 + [int]$count * 14
        if ($bytes.Length -ne $expected) { throw "AIBGYMW length mismatch at ${path}:$lineNumber expected=$expected actual=$($bytes.Length)" }
        $samples = @()
        for ($i = 0; $i -lt $count; $i++) {
            $offset = Read-S16 $bytes ([ref]$at); $x = Read-S16 $bytes ([ref]$at); $y = Read-S16 $bytes ([ref]$at)
            $tx = Read-S16 $bytes ([ref]$at); $ty = Read-S16 $bytes ([ref]$at)
            $state = $bytes[$at]; $at++; $buttons = $bytes[$at]; $at++; $target = Read-U16 $bytes ([ref]$at)
            $samples += [pscustomobject][ordered]@{ tick=[int64]$failureTick + $offset; offset=$offset; x=$x; y=$y; target_x=$tx; target_y=$ty; state=$state; buttons=$buttons; target=$target }
        }
        $records += [pscustomobject][ordered]@{
            schema='aib_gym_window_v1'; raw_log=$path; line=$lineNumber; builder=$builder; team=$team
            failure_tick=$failureTick; flags=$flags; sample_count=$count; samples=$samples
        }
    }
}
$lines = @($records | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 5 })
[IO.File]::WriteAllLines($OutputPath, [string[]]$lines, [Text.UTF8Encoding]::new($false))
Write-Output "AIB gym windows exported: $($records.Count) records -> $OutputPath"
