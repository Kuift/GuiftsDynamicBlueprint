[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ManifestPath,

    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$RunPrefix = 'wave_v4_cohort',

    [ValidateRange(1, 1000000)]
    [int]$StartOrdinal = 1,

    [ValidateRange(1, 1000000)]
    [int]$EndOrdinal = 1000000,

    [string]$TranscriptDirectory = 'Artifacts\aib_gym',

    [switch]$CompilerForwarding
)

$ErrorActionPreference = 'Stop'
if ($EndOrdinal -lt $StartOrdinal) { throw 'EndOrdinal must be greater than or equal to StartOrdinal.' }

$modRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runner = Join-Path $PSScriptRoot 'Invoke-AIBWaveRun.ps1'
if (!(Test-Path -LiteralPath $runner -PathType Leaf)) { throw "Wave runner not found: $runner" }

if (![IO.Path]::IsPathRooted($ManifestPath)) { $ManifestPath = Join-Path $modRoot $ManifestPath }
$ManifestPath = [IO.Path]::GetFullPath($ManifestPath)
if (!(Test-Path -LiteralPath $ManifestPath -PathType Leaf)) { throw "Wave manifest not found: $ManifestPath" }

if (![IO.Path]::IsPathRooted($TranscriptDirectory)) { $TranscriptDirectory = Join-Path $modRoot $TranscriptDirectory }
$TranscriptDirectory = [IO.Path]::GetFullPath($TranscriptDirectory)
$relativeTranscriptDirectory = [IO.Path]::GetRelativePath($modRoot, $TranscriptDirectory)
if ([IO.Path]::IsPathRooted($relativeTranscriptDirectory) -or $relativeTranscriptDirectory -eq '..' -or
    $relativeTranscriptDirectory.StartsWith('..' + [IO.Path]::DirectorySeparatorChar)) {
    throw 'TranscriptDirectory must remain inside the mod workspace.'
}
if (!(Test-Path -LiteralPath $TranscriptDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $TranscriptDirectory -Force | Out-Null
}

$records = @(
    Get-Content -LiteralPath $ManifestPath |
        Where-Object { ![string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_ | ConvertFrom-Json }
)
if ($records.Count -eq 0) { throw 'Wave manifest contains no trials.' }

$ordinals = @{}
foreach ($trial in $records) {
    if ($trial.schema -ne 'aib_wave_matrix_v1') { throw "Unsupported wave manifest schema '$($trial.schema)'." }
    if ($trial.ordinal -lt 1 -or $ordinals.ContainsKey([int]$trial.ordinal)) { throw "Invalid or duplicate trial ordinal '$($trial.ordinal)'." }
    $ordinals[[int]$trial.ordinal] = $true
    if ($trial.fixture_version -ne 4) { throw "Trial $($trial.ordinal) does not use fixture version 4." }
    if ($trial.team -notin @(0, 1) -or $trial.team_side -notin @('left', 'right') -or
        ($trial.team -eq 0 -and $trial.team_side -ne 'left') -or ($trial.team -eq 1 -and $trial.team_side -ne 'right')) {
        throw "Trial $($trial.ordinal) has an invalid team/side mapping."
    }
    if ($trial.scenario -notin @('knight', 'archer', 'bomb', 'mixed') -or $trial.variant -notin @('control', 'plan')) {
        throw "Trial $($trial.ordinal) has an unsupported scenario or variant."
    }
    if (!$trial.requires_fresh_canonical_reset) { throw "Trial $($trial.ordinal) does not require a fresh canonical reset." }
}

$selected = @($records | Where-Object { $_.ordinal -ge $StartOrdinal -and $_.ordinal -le $EndOrdinal } | Sort-Object ordinal)
if ($selected.Count -eq 0) { throw "No wave trials fall within ordinal range $StartOrdinal..$EndOrdinal." }

function Get-ResultLine([string]$path, [string]$runId) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    $pattern = '^\[AIBEVT\](?=.*\bsource=strategy\b)(?=.*\baction=wave_result\b)(?=.*\brun_id=' + [regex]::Escape($runId) + '\b)'
    $matches = @(Select-String -LiteralPath $path -Pattern $pattern)
    $unique = @($matches.Line | Select-Object -Unique)
    if ($unique.Count -ne 1) {
        throw "Existing transcript '$path' must contain one unique result for run '$runId'; found raw=$($matches.Count) unique=$($unique.Count)."
    }
    return $unique[0]
}

$completed = 0
$skipped = 0
foreach ($trial in $selected) {
    $runId = '{0}_t{1}_{2}_{3}_s{4}_{5}' -f $RunPrefix, $trial.team, $trial.team_side, $trial.scenario, $trial.seed, $trial.variant
    if ($runId -notmatch '^[A-Za-z0-9._-]+$') { throw "Generated invalid run id '$runId'." }
    $transcript = Join-Path $TranscriptDirectory "$runId.tcpr.txt"
    $existing = Get-ResultLine $transcript $runId
    if ($null -ne $existing) {
        $skipped++
        Write-Host "AIB_WAVE_MATRIX_SKIP ordinal=$($trial.ordinal) run=$runId"
        continue
    }

    Write-Host "AIB_WAVE_MATRIX_START ordinal=$($trial.ordinal)/$($records.Count) run=$runId"
    $parameters = @{
        RunId = $runId
        Variant = [string]$trial.variant
        Team = [int]$trial.team
        Scenario = [string]$trial.scenario
        Seed = [uint64]$trial.seed
        TranscriptPath = $transcript
    }
    if ($CompilerForwarding) { $parameters.CompilerForwarding = $true }
    & $runner @parameters
    Get-ResultLine $transcript $runId | Out-Null
    if (@(Get-Process -Name KAG -ErrorAction SilentlyContinue).Count -ne 0) {
        throw "Trial $($trial.ordinal) returned while a KAG process was still live."
    }
    $completed++
    Write-Host "AIB_WAVE_MATRIX_PASS ordinal=$($trial.ordinal)/$($records.Count) run=$runId"
}

Write-Host "AIB_WAVE_MATRIX_DONE selected=$($selected.Count) completed=$completed skipped=$skipped range=$StartOrdinal..$EndOrdinal"
