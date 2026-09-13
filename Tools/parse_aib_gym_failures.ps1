param(
    [Parameter(Mandatory = $true)] [string[]]$LogPath,
    [Parameter(Mandatory = $true)] [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$required = @('v','t','b','tm','f','s','x','y','tx','ty','mv','j','rp','in','tg','out','inv')
$records = @()
foreach ($path in $LogPath) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Log not found: $path" }
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $path) {
        $lineNumber++
        # Resource benchmark lifecycle markers also use the [AIBGYM] prefix.
        # Only the compact numeric failure schema belongs in this parser.
        if ($line -notmatch '\[AIBGYM\]\s+v=') { continue }
        $fields = @{}
        foreach ($match in [regex]::Matches($line, '(?<key>[A-Za-z]+)=(?<value>-?\d+)')) {
            $fields[$match.Groups['key'].Value] = [int64]$match.Groups['value'].Value
        }
        foreach ($key in $required) { if (!$fields.ContainsKey($key)) { throw "Missing AIBGYM field '$key' at ${path}:$lineNumber" } }
        if ($fields.v -ne 1) { throw "Unsupported AIBGYM schema v=$($fields.v) at ${path}:$lineNumber" }
        $destinationX = if ($fields.ContainsKey('dx')) { $fields.dx } else { $null }
        $destinationY = if ($fields.ContainsKey('dy')) { $fields.dy } else { $null }
        $targetBlob = if ($fields.ContainsKey('tb')) { $fields.tb } else { $null }
        $targetBlobX = if ($fields.ContainsKey('bx')) { $fields.bx } else { $null }
        $targetBlobY = if ($fields.ContainsKey('by')) { $fields.by } else { $null }
        $records += [pscustomobject][ordered]@{
            schema='aib_gym_failure_v1'; raw_log=$path; line=$lineNumber; tick=$fields.t
            builder=$fields.b; team=$fields.tm; flags=$fields.f; state=$fields.s
            x=$fields.x; y=$fields.y; target_x=$fields.tx; target_y=$fields.ty
            max_displacement=$fields.mv; jumps=$fields.j; replans=$fields.rp
            interaction_ticks=$fields.in; target_changes=$fields.tg; outcome_changes=$fields.out
            invalid_build_attempts=$fields.inv; destination_x=$destinationX; destination_y=$destinationY
            target_blob=$targetBlob; target_blob_x=$targetBlobX; target_blob_y=$targetBlobY
        }
    }
}
$lines = @($records | ForEach-Object { $_ | ConvertTo-Json -Compress })
[IO.File]::WriteAllLines($OutputPath, [string[]]$lines, [Text.UTF8Encoding]::new($false))
Write-Output "AIB gym failures exported: $($records.Count) records -> $OutputPath"
