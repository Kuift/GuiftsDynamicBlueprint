param(
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$modRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$kagRoot = Resolve-Path (Join-Path $modRoot "..\..")
$logsDir = Join-Path $kagRoot "Logs"
$kagExe = Join-Path $kagRoot "KAG.exe"
$parser = Join-Path $PSScriptRoot "parse_aib_test_log.ps1"
$autostart = "../Mods/GuiftsDynamicBlueprint_vDev/Scripts/aib_test_autostart.as"
$ctfGamemode = Join-Path $modRoot "Rules\CTF\gamemode.cfg"
$ctfGamemodeDisabled = Join-Path $modRoot "Rules\CTF\gamemode.cfg.aibtest-disabled"

if (!(Test-Path $kagExe)) {
    throw "KAG.exe not found at $kagExe"
}

function Restore-AIBTestFiles {
    if ((Test-Path $ctfGamemodeDisabled) -and !(Test-Path $ctfGamemode)) {
        Move-Item -LiteralPath $ctfGamemodeDisabled -Destination $ctfGamemode
    }
}

try {
    if ((Test-Path $ctfGamemode) -and !(Test-Path $ctfGamemodeDisabled)) {
        Move-Item -LiteralPath $ctfGamemode -Destination $ctfGamemodeDisabled
    }

    $before = @{}
    if (Test-Path $logsDir) {
        Get-ChildItem $logsDir -Filter "console-*.txt" | ForEach-Object { $before[$_.FullName] = $true }
    }

    $startedAt = Get-Date
    $process = Start-Process -FilePath $kagExe -WorkingDirectory $kagRoot -ArgumentList @(
        "noautoupdate",
        "nolauncher",
        "autostart",
        $autostart
    ) -PassThru

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $log = $null
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        $candidates = Get-ChildItem $logsDir -Filter "console-*.txt" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $startedAt.AddSeconds(-2) } |
            Sort-Object LastWriteTime -Descending

        foreach ($candidate in $candidates) {
            if (!$before.ContainsKey($candidate.FullName)) {
                $text = Get-Content $candidate.FullName -Raw -ErrorAction SilentlyContinue
                if ($text -match "\[AIBTEST\]") {
                    $log = $candidate.FullName
                    if ($text -match "\[AIBTEST\] DONE") {
                        if (!$process.HasExited) {
                            Stop-Process -Id $process.Id -Force
                        }
                        Restore-AIBTestFiles
                        & $parser -LogPath $log
                        exit $LASTEXITCODE
                    }
                }
            }
        }

        if ($process.HasExited -and !$log) {
            $latest = $candidates | Select-Object -First 1
            if ($latest) {
                Write-Error "KAG exited before producing [AIBTEST] output. Latest log: $($latest.FullName)"
            } else {
                Write-Error "KAG exited before producing a console log."
            }
            exit 2
        }
    }

    if (!$process.HasExited) {
        Stop-Process -Id $process.Id -Force
    }

    if ($log) {
        & $parser -LogPath $log
        Write-Error "Timed out waiting for [AIBTEST] DONE. Latest test log: $log"
    } else {
        Write-Error "Timed out waiting for an AIB test log."
    }
    exit 2
}
finally {
    Restore-AIBTestFiles
}
