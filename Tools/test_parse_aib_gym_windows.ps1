$ErrorActionPreference = 'Stop'
$parser = Join-Path $PSScriptRoot 'parse_aib_gym_windows.ps1'
$input = Join-Path $env:TEMP ('aib-gym-window-input-' + [guid]::NewGuid().ToString('N') + '.log')
$output = Join-Path $env:TEMP ('aib-gym-window-output-' + [guid]::NewGuid().ToString('N') + '.ndjson')

function New-WindowBytes {
    $stream = [IO.MemoryStream]::new(); $writer = [IO.BinaryWriter]::new($stream)
    $writer.Write([byte]1); $writer.Write([uint16]42); $writer.Write([byte]0); $writer.Write([uint32]900); $writer.Write([uint16]320); $writer.Write([byte]2)
    foreach ($sample in @(
        @(-5,100,200,120,208,13,18,77),
        @(5,104,200,120,208,13,2,77)
    )) {
        for ($i=0; $i -lt 5; $i++) { $writer.Write([int16]$sample[$i]) }
        $writer.Write([byte]$sample[5]); $writer.Write([byte]$sample[6]); $writer.Write([uint16]$sample[7])
    }
    $writer.Flush(); $bytes=$stream.ToArray(); $writer.Dispose(); $stream.Dispose(); return $bytes
}

try {
    $data = [Convert]::ToBase64String((New-WindowBytes))
    "[AIBGYMW] data=$data" | Set-Content -LiteralPath $input -Encoding utf8
    & $parser -LogPath $input -OutputPath $output | Out-Null
    $rows = @(Get-Content -LiteralPath $output | ForEach-Object { $_ | ConvertFrom-Json })
    if ($rows.Count -ne 1 -or $rows[0].sample_count -ne 2 -or $rows[0].flags -ne 320) { throw "Window header decode failed: $($rows | ConvertTo-Json -Depth 5 -Compress)" }
    if ($rows[0].samples[0].tick -ne 895 -or $rows[0].samples[1].tick -ne 905 -or $rows[0].samples[0].buttons -ne 18) { throw 'Window sample decode failed' }

    $bad = [byte[]](New-WindowBytes)[0..20]
    "[AIBGYMW] data=$([Convert]::ToBase64String($bad))" | Set-Content -LiteralPath $input -Encoding utf8
    $rejected = $false
    try { & $parser -LogPath $input -OutputPath $output | Out-Null } catch { $rejected = $_.Exception.Message -match 'length mismatch' }
    if (!$rejected) { throw 'Truncated diagnostic window was not rejected' }
    Write-Output 'AIB compact diagnostic window parser passed'
}
finally {
    Remove-Item -LiteralPath $input,$output -Force -ErrorAction SilentlyContinue
}
