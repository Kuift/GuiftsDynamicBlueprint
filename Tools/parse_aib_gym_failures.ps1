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
        if ($line -notmatch '\[AIBGYM\]') { continue }
        $fields = @{}
        foreach ($match in [regex]::Matches($line, '(?<key>[A-Za-z]+)=(?<value>-?\d+)')) {
            $fields[$match.Groups['key'].Value] = [int64]$match.Groups['value'].Value
        }
        foreach ($key in $required) { if (!$fields.ContainsKey($key)) { throw "Missing AIBGYM field '$key' at ${path}:$lineNumber" } }
        if ($fields.v -ne 1) { throw "Unsupported AIBGYM schema v=$($fields.v) at ${path}:$lineNumber" }
        $records += [pscustomobject][ordered]@{
            schema='aib_gym_failure_v1'; raw_log=$path; line=$lineNumber; tick=$fields.t
            builder=$fields.b; team=$fields.tm; flags=$fields.f; state=$fields.s
            x=$fields.x; y=$fields.y; target_x=$fields.tx; target_y=$fields.ty
            max_displacement=$fields.mv; jumps=$fields.j; replans=$fields.rp
            interaction_ticks=$fields.in; target_changes=$fields.tg; outcome_changes=$fields.out
            invalid_build_attempts=$fields.inv
        }
    }
}
$lines = @($records | ForEach-Object { $_ | ConvertTo-Json -Compress })
[IO.File]::WriteAllLines($OutputPath, [string[]]$lines, [Text.UTF8Encoding]::new($false))
Write-Output "AIB gym failures exported: $($records.Count) records -> $OutputPath"
