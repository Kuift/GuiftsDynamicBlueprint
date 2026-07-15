[CmdletBinding()]
param(
    [int]$TimeoutSeconds = 30,
    [int]$StaleSeconds = 12,
    [switch]$CaptureNativeStacks,
    [ValidateSet('Localhost','Server')]
    [string]$Mode = 'Localhost'
)

$ErrorActionPreference = 'Stop'
$researchRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$modRoot = Resolve-Path (Join-Path $researchRoot '..')
$kagRoot = Resolve-Path (Join-Path $modRoot '..\..')
$kagExe = Join-Path $kagRoot 'KAG.exe'
$rootConfig = Join-Path $kagRoot 'autoconfig.cfg'
$logsDir = Join-Path $kagRoot 'Logs'
$autostart = if ($Mode -eq 'Server') {
    '../Mods/GuiftsDynamicBlueprint_vDev/research/runtime/minimal_server_autostart.as'
} else {
    '../Mods/GuiftsDynamicBlueprint_vDev/research/runtime/minimal_localhost_autostart.as'
}
$privateRoot = Join-Path $researchRoot 'private\native'
$rootOriginal = Get-Content -Raw -LiteralPath $rootConfig

function Set-ConfigValue([string]$text, [string]$key, [string]$value) {
    $pattern = '(?m)^([ \t]*' + [regex]::Escape($key) + '[ \t]*=[ \t]*).*$'
    if (![regex]::IsMatch($text, $pattern)) { throw "Missing $key in $rootConfig" }
    return [regex]::Replace($text, $pattern, ('$' + '{1}' + $value), 1)
}

function Restore-Handoff {
    $text = $rootOriginal
    $text = Set-ConfigValue $text 'sv_gamemode' 'CTF'
    $text = Set-ConfigValue $text 'sv_mapcycle' ''
    $text = Set-ConfigValue $text 'sv_mapcycle_shuffle' 'true'
    [IO.File]::WriteAllText($rootConfig, $text, [Text.UTF8Encoding]::new($false))
}

function Capture-NativeStacks($targetProcess, [string]$targetLog) {
    if (!(Test-Path -LiteralPath $privateRoot)) {
        New-Item -ItemType Directory -Path $privateRoot | Out-Null
    }
    $gdb = (Get-Command gdb -ErrorAction Stop).Source
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $outputPath = Join-Path $privateRoot ("minimal-freeze-{0}-pid{1}.gdb.txt" -f $stamp, $targetProcess.Id)
    $gdbOutput = & $gdb --batch --nx $kagExe `
        -ex 'set pagination off' `
        -ex 'set confirm off' `
        -ex ("attach {0}" -f $targetProcess.Id) `
        -ex 'info threads' `
        -ex 'info sharedlibrary' `
        -ex 'thread apply all bt full' `
        -ex 'detach' 2>&1 | Out-String
    [IO.File]::WriteAllText($outputPath, $gdbOutput, [Text.UTF8Encoding]::new($false))
    Write-Host "Captured native thread stacks to $outputPath"
    if ($targetLog) { Write-Host "Frozen runtime log: $targetLog" }
}

$existing = @(Get-Process -Name KAG -ErrorAction SilentlyContinue)
if ($existing.Count -gt 0) { throw 'KAG is already running; refusing to launch an ambiguous probe.' }
$before = @(Get-ChildItem -LiteralPath $logsDir -Filter 'console-*.txt' | ForEach-Object { $_.FullName })
$started = Get-Date
$process = $null
$log = $null
$lastProgress = $started
$sawInit = $false
try {
    $process = Start-Process -FilePath $kagExe -WorkingDirectory $kagRoot -ArgumentList @(
        'noautoupdate','nolauncher','autostart',$autostart
    ) -PassThru
    Write-Host "Started visible minimal $Mode probe PID $($process.Id)."
    $deadline = $started.AddSeconds($TimeoutSeconds)
    $seenLength = [int64]0
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 100
        if ($process.HasExited) { throw "KAG exited early with code $($process.ExitCode)." }
        if (!$log) {
            $candidate = Get-ChildItem -LiteralPath $logsDir -Filter 'console-*.txt' |
                Where-Object { $before -notcontains $_.FullName -and $_.LastWriteTime -ge $started.AddSeconds(-2) } |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($candidate) { $log = $candidate.FullName; Write-Host "Following $log" }
            else { continue }
        }
        $item = Get-Item -LiteralPath $log
        if ($item.Length -ne $seenLength) {
            $seenLength = $item.Length
            $lastProgress = Get-Date
            $text = Get-Content -Raw -LiteralPath $log
            if ($text -match 'ERROR .*GuiftsDynamicBlueprint_vDev|Rules partially failed initialization|Script .* has errors') {
                throw 'Minimal probe encountered a script/rules error.'
            }
            if ($text -match '\[AIBMIN\] INIT') { $sawInit = $true }
            if ($text -match '\[AIBMIN\] DONE gametime=90') {
                $elapsed = [math]::Round(((Get-Date) - $started).TotalMilliseconds, 1)
                Write-Host "AIBMIN PASS wall_ms=$elapsed log=$(Split-Path -Leaf $log)"
                exit 0
            }
        }
        if ($sawInit -and ((Get-Date) - $lastProgress).TotalSeconds -ge $StaleSeconds) {
            if ($CaptureNativeStacks) { Capture-NativeStacks $process $log }
            throw "Minimal localhost simulation/log stalled for $StaleSeconds seconds after INIT."
        }
    }
    throw "Minimal localhost probe timed out after $TimeoutSeconds seconds."
} finally {
    if ($process -and !$process.HasExited) {
        Stop-Process -Id $process.Id -Force
        $process.WaitForExit(10000) | Out-Null
    }
    if ($process -and (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) {
        throw "Probe-owned KAG PID $($process.Id) did not exit."
    }
    Restore-Handoff
}
