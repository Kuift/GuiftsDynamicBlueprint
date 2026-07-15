$ErrorActionPreference = 'Stop'
$parser = Join-Path $PSScriptRoot 'parse_aib_gym_failures.ps1'
$input = Join-Path $env:TEMP ('aib-gym-input-' + [guid]::NewGuid().ToString('N') + '.log')
$output = Join-Path $env:TEMP ('aib-gym-output-' + [guid]::NewGuid().ToString('N') + '.ndjson')
try {
    @(
        'noise'
        '[AIBGYM] AIBGYM|START|run=smoke|metric=resource_collection_smoke'
        '[AIBGYM] v=1 t=900 b=42 tm=0 f=320 s=13 x=100 y=200 tx=120 ty=208 mv=3 j=0 rp=1 in=0 tg=2 out=0 inv=5 dx=144 dy=216 tb=77 bx=152 by=224'
    ) | Set-Content -LiteralPath $input -Encoding utf8
    & $parser -LogPath $input -OutputPath $output | Out-Null
    $rows = @(Get-Content -LiteralPath $output | ForEach-Object { $_ | ConvertFrom-Json })
    if ($rows.Count -ne 1) { throw "Expected one parsed failure, found $($rows.Count)" }
    $row = $rows[0]
    if ($row.schema -ne 'aib_gym_failure_v1' -or $row.flags -ne 320 -or $row.builder -ne 42 -or
        $row.invalid_build_attempts -ne 5 -or $row.target_x -ne 120 -or $row.destination_x -ne 144 -or
        $row.target_blob -ne 77 -or $row.target_blob_y -ne 224) { throw 'Parsed AIBGYM fields are incorrect' }

    '[AIBGYM] v=1 t=1 b=2 tm=0 f=1 s=1 x=0 y=0' | Set-Content -LiteralPath $input -Encoding utf8
    $missingRejected = $false
    try { & $parser -LogPath $input -OutputPath $output | Out-Null } catch { $missingRejected = $_.Exception.Message -match "Missing AIBGYM field" }
    if (!$missingRejected) { throw 'Truncated AIBGYM record was not rejected' }

    '[AIBGYM] v=2 t=1 b=2 tm=0 f=1 s=1 x=0 y=0 tx=0 ty=0 mv=0 j=0 rp=0 in=0 tg=0 out=0 inv=0' | Set-Content -LiteralPath $input -Encoding utf8
    $versionRejected = $false
    try { & $parser -LogPath $input -OutputPath $output | Out-Null } catch { $versionRejected = $_.Exception.Message -match 'Unsupported AIBGYM schema' }
    if (!$versionRejected) { throw 'Unknown AIBGYM schema was not rejected' }
    Write-Output 'AIB compact gym failure parser passed'
}
finally {
    Remove-Item -LiteralPath $input,$output -Force -ErrorAction SilentlyContinue
}
