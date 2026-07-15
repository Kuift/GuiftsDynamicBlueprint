[CmdletBinding()]
param(
    [string]$KagRoot = "",
    [string]$OutputPath = "",
    [string]$ResearchToolRoot = "E:\Tools\KAGResearch"
)

$ErrorActionPreference = "Stop"
$researchRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$modRoot = Resolve-Path (Join-Path $researchRoot "..")
if ([string]::IsNullOrWhiteSpace($KagRoot)) {
    $KagRoot = [string](Resolve-Path (Join-Path $modRoot "..\.."))
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $researchRoot "generated\engine_fingerprint.json"
}

$exe = Join-Path $KagRoot "KAG.exe"
$brainManual = Join-Path $KagRoot "Manual\interface\Objects\CBrain.txt"
$manifest = Join-Path $KagRoot "App\version.txt"
if (!(Test-Path -LiteralPath $exe)) { throw "KAG.exe not found at $exe" }
if (!(Test-Path -LiteralPath $brainManual)) { throw "KAG manual not found at $brainManual" }

$llvmReadObj = (Get-Command llvm-readobj -ErrorAction Stop).Source
$llvmObjDump = (Get-Command llvm-objdump -ErrorAction Stop).Source
$header = & $llvmReadObj --file-headers $exe | Out-String
$debugDump = & $llvmObjDump -s -j .gnu_debuglink $exe | Out-String
$manualText = Get-Content -Raw -LiteralPath $brainManual
$manifestFirst = if (Test-Path -LiteralPath $manifest) {
    Get-Content -LiteralPath $manifest -TotalCount 1
} else { "" }

$buildMatch = [regex]::Match($manualText, 'SCRIPT INTERFACE FOR BUILD\s+(\d+)')
$formatMatch = [regex]::Match($header, '(?m)^Format:\s+(.+)$')
$archMatch = [regex]::Match($header, '(?m)^Arch:\s+(.+)$')
$stampMatch = [regex]::Match($header, 'TimeDateStamp:\s+([^\r\n]+)')
$debugName = if ($debugDump -match 'KAG\.exe\.debug') { 'KAG.exe.debug' } else { '' }
$debugCompanion = if ($debugName) { Join-Path $KagRoot $debugName } else { '' }

$toolNames = 'llvm-readobj','llvm-objdump','objdump','strings','ghidra','ghidraRun','analyzeHeadless','rizin','radare2','cutter','ida64'
$tools = @(
foreach ($name in $toolNames) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($command) {
        [ordered]@{ name = $name; path = $command.Source }
    }
}
)

# Ghidra and its JDK are intentionally installed off the space-constrained KAG
# drive. Discover the newest local copies without making that machine-local
# layout a prerequisite for running the fingerprint tool elsewhere.
$appsRoot = if ([string]::IsNullOrWhiteSpace($ResearchToolRoot)) {
    ''
} else {
    [System.IO.Path]::Combine($ResearchToolRoot, 'apps')
}
if ($appsRoot -and [System.IO.Directory]::Exists($appsRoot)) {
    $ghidraHome = Get-ChildItem -Directory -LiteralPath $appsRoot -Filter 'ghidra_*_PUBLIC' |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($null -ne $ghidraHome) {
        $ghidraRun = Join-Path $ghidraHome.FullName 'ghidraRun.bat'
        $analyzeHeadless = Join-Path $ghidraHome.FullName 'support\analyzeHeadless.bat'
        if (Test-Path -LiteralPath $ghidraRun) {
            $tools += [ordered]@{ name = 'ghidra'; path = $ghidraRun }
        }
        if (Test-Path -LiteralPath $analyzeHeadless) {
            $tools += [ordered]@{ name = 'analyzeHeadless'; path = $analyzeHeadless }
        }
    }
    $jdkHome = Get-ChildItem -Directory -LiteralPath $appsRoot -Filter 'jdk-*' |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($null -ne $jdkHome) {
        $java = Join-Path $jdkHome.FullName 'bin\java.exe'
        if (Test-Path -LiteralPath $java) {
            $tools += [ordered]@{ name = 'java'; path = $java }
        }
    }
}

$fingerprint = [ordered]@{
    schema = 1
    interface_build = if ($buildMatch.Success) { [int]$buildMatch.Groups[1].Value } else { $null }
    app_manifest_id = $manifestFirst
    executable = [ordered]@{
        name = 'KAG.exe'
        size = (Get-Item -LiteralPath $exe).Length
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $exe).Hash.ToLowerInvariant()
        format = if ($formatMatch.Success) { $formatMatch.Groups[1].Value.Trim() } else { '' }
        architecture = if ($archMatch.Success) { $archMatch.Groups[1].Value.Trim() } else { '' }
        pe_timestamp = if ($stampMatch.Success) { $stampMatch.Groups[1].Value.Trim() } else { '' }
        debuglink = $debugName
        debug_companion_installed = if ($debugCompanion) { Test-Path -LiteralPath $debugCompanion } else { $false }
    }
    linked_engine_evidence = [ordered]@{
        irrlicht = 'present; precise upstream version unresolved'
        box2d = 'present; precise upstream version unresolved'
    }
    available_static_tools = @($tools)
}

$parent = Split-Path -Parent $OutputPath
if (!(Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent | Out-Null
}
$fingerprint | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host "Wrote $OutputPath"
$fingerprint | ConvertTo-Json -Depth 8
