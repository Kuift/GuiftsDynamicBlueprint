[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$LogPath,
    [string]$BaselineVariant = 'control',
    [string]$CandidateVariant = 'candidate',
    [string]$Metric = 'resource_collection_180s',
    [int]$MinimumRunsPerVariant = 3,
    [switch]$RequireImprovement,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
if ($MinimumRunsPerVariant -lt 1) { throw 'MinimumRunsPerVariant must be positive.' }
if ([string]::IsNullOrWhiteSpace($BaselineVariant) -or [string]::IsNullOrWhiteSpace($CandidateVariant) -or
    $BaselineVariant -eq $CandidateVariant) { throw 'BaselineVariant and CandidateVariant must be distinct and non-blank.' }

$numericFields = @(
    'schema','fixture_version','team','map_hash','map_width','map_height','initial_terrain_hash',
    'builders','live_builders','duration','elapsed','collected_wood','collected_stone','collected_gold','collected_total','delivered_wood','delivered_stone','delivered_gold',
    'delivered_total','stock_delta_wood','stock_delta_stone','stock_delta_gold','deaths','failure_flags',
    'idle_ticks'
)

function Convert-AIBGymRecord([string]$line, [string]$source, [string]$expectedMetric) {
    # Explicit TCPR transcripts begin at the marker. Normal KAG console files
    # prepend a fixed [HH:MM:SS] timestamp. Accept precisely those two native
    # transports so archived console evidence remains comparable without
    # treating an arbitrary quoted/nested marker as a metric record.
    if ($line -notmatch '^(?:\[\d{2}:\d{2}:\d{2}\]\s+)?\[AIBGYMR\]\s+') { return $null }
    $values = [ordered]@{ source = $source }
    foreach ($match in [regex]::Matches($line, '(?<key>[a-z][a-z0-9_]*)=(?<value>[^\s]+)')) {
        $key = $match.Groups['key'].Value
        $value = $match.Groups['value'].Value
        $values[$key] = if ($numericFields -contains $key) { [int64]$value } else { $value }
    }
    foreach ($key in @('schema','status')) {
        if (!$values.Contains($key)) { throw "Malformed AIBGYMR record in ${source}: missing $key" }
    }
    # A long-lived console can contain abort diagnostics and older development
    # schemas before the comparable result. They are not cohort episodes. Once
    # a schema-4 result claims the requested metric, however, validate it fully.
    if ($values.status -ne 'result' -or $values.schema -ne 4) { return $null }
    if (!$values.Contains('metric')) { throw "Malformed AIBGYMR record in ${source}: missing metric" }
    if ($values.metric -ne $expectedMetric) { return $null }
    $required = @('schema','status','run','variant','metric','fixture_id','fixture_version','team','team_side',
        'map_hash','map_width','map_height','initial_terrain_hash','initial_fingerprint','builders','order',
        'duration','elapsed','collected_total','delivered_total','stock_delta_wood','stock_delta_stone',
        'stock_delta_gold','deaths','failure_flags','idle_ticks')
    foreach ($key in $required) {
        if (!$values.Contains($key)) { throw "Malformed AIBGYMR record in ${source}: missing $key" }
    }
    return [pscustomobject]$values
}

$records = @()
foreach ($pathPattern in $LogPath) {
    $resolved = @(Get-ChildItem -Path $pathPattern -File -ErrorAction Stop)
    foreach ($file in $resolved) {
        foreach ($line in Get-Content -LiteralPath $file.FullName) {
            $record = Convert-AIBGymRecord $line $file.FullName $Metric
            if ($null -ne $record) {
                $records += $record
            }
        }
    }
}
if ($records.Count -eq 0) { throw "No complete AIBGYMR schema-v4 '$Metric' records found." }

# A local run can be present in both the KAG console and an explicit TCPR
# transcript. Full TCPR forwarding can even carry the print() copy and the
# explicit tcpr() copy in the same transcript. Cohort size is episode count,
# never transport-record count: collapse byte-equivalent run ids and reject a
# reused id whose metric content conflicts.
$recordSignatureFields = @(
    'schema','status','run','variant','metric','fixture_id','fixture_version','team','team_side',
    'map_hash','map_width','map_height','initial_terrain_hash','initial_fingerprint','builders',
    'live_builders','order','duration','elapsed','collected_wood','collected_stone','collected_gold',
    'collected_total','delivered_wood','delivered_stone','delivered_gold','delivered_total',
    'stock_delta_wood','stock_delta_stone','stock_delta_gold','deaths','failure_flags','idle_ticks',
    'travel_px','reason'
)
function Get-AIBGymRecordSignature($record) {
    return @($recordSignatureFields | ForEach-Object { "$_=$($record.$_)" }) -join '|'
}
$uniqueRecords = @()
foreach ($runGroup in ($records | Group-Object run)) {
    if ([string]::IsNullOrWhiteSpace($runGroup.Name)) { throw 'AIBGYMR result has a blank run id.' }
    $signatures = @($runGroup.Group | ForEach-Object { Get-AIBGymRecordSignature $_ } | Sort-Object -Unique)
    if ($signatures.Count -ne 1) {
        $sources = @($runGroup.Group.source | Sort-Object -Unique) -join ', '
        throw "Conflicting AIBGYMR records reuse run id '$($runGroup.Name)' in: $sources"
    }
    $uniqueRecords += $runGroup.Group[0]
}
$records = @($uniqueRecords)

function Get-ContextKey($record) {
    # The user's optimization boundary is the named map, team side, worker
    # configuration, and duration. Initial fingerprints remain in every raw
    # record for audit/stratification, but KAG mutates transient terrain during
    # normal map startup; requiring byte-identical delayed manifests would make
    # repeated trials of the same official map impossible to compare.
    return @(
        $record.fixture_id, $record.fixture_version, $record.team, $record.team_side,
        $record.map_hash, $record.map_width, $record.map_height,
        $record.metric, $record.builders, $record.order, $record.duration
    ) -join '|'
}

$cohorts = @()
foreach ($contextGroup in ($records | Group-Object { Get-ContextKey $_ })) {
    $baseline = @($contextGroup.Group | Where-Object variant -CEQ $BaselineVariant)
    $candidate = @($contextGroup.Group | Where-Object variant -CEQ $CandidateVariant)
    if ($baseline.Count -lt $MinimumRunsPerVariant -or $candidate.Count -lt $MinimumRunsPerVariant) { continue }

    $first = $contextGroup.Group[0]
    $baselineCollected = [double](($baseline | Measure-Object collected_total -Average).Average)
    $candidateCollected = [double](($candidate | Measure-Object collected_total -Average).Average)
    $baselineDelivered = [double](($baseline | Measure-Object delivered_total -Average).Average)
    $candidateDelivered = [double](($candidate | Measure-Object delivered_total -Average).Average)
    $baselineStock = [double](($baseline | ForEach-Object {
        $_.stock_delta_wood + $_.stock_delta_stone + $_.stock_delta_gold
    } | Measure-Object -Average).Average)
    $candidateStock = [double](($candidate | ForEach-Object {
        $_.stock_delta_wood + $_.stock_delta_stone + $_.stock_delta_gold
    } | Measure-Object -Average).Average)
    $baselineDeaths = [double](($baseline | Measure-Object deaths -Average).Average)
    $candidateDeaths = [double](($candidate | Measure-Object deaths -Average).Average)
    $baselineFailureRuns = @($baseline | Where-Object failure_flags -ne 0).Count
    $candidateFailureRuns = @($candidate | Where-Object failure_flags -ne 0).Count
    $collectedDelta = $candidateCollected - $baselineCollected
    $deliveredDelta = $candidateDelivered - $baselineDelivered
    $acceptancePassed = $collectedDelta -gt 0 -and $candidateDeaths -le $baselineDeaths -and
        $candidateFailureRuns -le $baselineFailureRuns

    $cohorts += [pscustomobject]@{
        ContextKey = $contextGroup.Name
        FixtureId = $first.fixture_id
        FixtureVersion = $first.fixture_version
        Team = $first.team
        TeamSide = $first.team_side
        MapHash = $first.map_hash
        MapWidth = $first.map_width
        MapHeight = $first.map_height
        InitialTerrainHash = $first.initial_terrain_hash
        InitialFingerprint = $first.initial_fingerprint
        DistinctInitialTerrainHashes = @($contextGroup.Group.initial_terrain_hash | Sort-Object -Unique).Count
        DistinctInitialFingerprints = @($contextGroup.Group.initial_fingerprint | Sort-Object -Unique).Count
        Metric = $first.metric
        Builders = $first.builders
        Order = $first.order
        Duration = $first.duration
        BaselineRuns = $baseline.Count
        CandidateRuns = $candidate.Count
        BaselineMeanCollected = [Math]::Round($baselineCollected, 3)
        CandidateMeanCollected = [Math]::Round($candidateCollected, 3)
        CollectedDelta = [Math]::Round($collectedDelta, 3)
        BaselineMeanDelivered = [Math]::Round($baselineDelivered, 3)
        CandidateMeanDelivered = [Math]::Round($candidateDelivered, 3)
        DeliveredDelta = [Math]::Round($deliveredDelta, 3)
        BaselineMeanStockDelta = [Math]::Round($baselineStock, 3)
        CandidateMeanStockDelta = [Math]::Round($candidateStock, 3)
        StockDeltaChange = [Math]::Round($candidateStock - $baselineStock, 3)
        BaselineMeanDeaths = [Math]::Round($baselineDeaths, 3)
        CandidateMeanDeaths = [Math]::Round($candidateDeaths, 3)
        BaselineFailureRuns = $baselineFailureRuns
        CandidateFailureRuns = $candidateFailureRuns
        AcceptancePassed = $acceptancePassed
    }
}

if ($cohorts.Count -eq 0) {
    throw "No exact per-map control/candidate cohort met the $MinimumRunsPerVariant-run minimum."
}

$result = [pscustomobject]@{
    Schema = 1
    Metric = $Metric
    BaselineVariant = $BaselineVariant
    CandidateVariant = $CandidateVariant
    MinimumRunsPerVariant = $MinimumRunsPerVariant
    CohortCount = $cohorts.Count
    AcceptancePassed = @($cohorts | Where-Object { !$_.AcceptancePassed }).Count -eq 0
    Cohorts = $cohorts
}

if ($RequireImprovement -and !$result.AcceptancePassed) {
    $failed = @($cohorts | Where-Object { !$_.AcceptancePassed } | ForEach-Object {
        "$($_.FixtureId)/team$($_.Team)/$($_.TeamSide)/$($_.Builders)x$($_.Order):delta=$($_.CollectedDelta)"
    }) -join ', '
    throw "AIB gym improvement gate failed: $failed"
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8 -Compress
} else {
    Write-Output 'AIB gym exact per-map cohorts'
    $cohorts | Format-Table FixtureId,TeamSide,Builders,Order,BaselineRuns,CandidateRuns,BaselineMeanCollected,CandidateMeanCollected,CollectedDelta,AcceptancePassed -AutoSize
}
