[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$LogPath,

    [ValidateRange(1,1000)]
    [int]$MinimumRunsPerCohort = 3,

    [switch]$RequireAllPassed,

    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'

function ConvertTo-InfrastructureRecord([string]$line, [string]$source) {
    if ($line -notmatch '^(?:\[\d{2}:\d{2}:\d{2}\]\s+)?\[AIBGYMI\]\s+') { return $null }
    $fields = @{}
    foreach ($token in ($line -split '\s+')) {
        if ($token -notmatch '^([^=]+)=(.*)$') { continue }
        $fields[$Matches[1]] = $Matches[2]
    }
    foreach ($key in @('schema','status','run')) {
        if (!$fields.ContainsKey($key)) { throw "Malformed AIBGYMI record in ${source}: missing $key" }
    }
    if ($fields.schema -ne '1' -or $fields.status -ne 'result') { return $null }
    foreach ($key in @('variant','metric','fixture_id','fixture_version','team','team_side','map_hash','map_width','map_height',
        'template','tasks','physical_matches','completed','pending','reservations','work_tiles','archived_complete',
        'rear_gate','front_gate','ally_rear_entered','ally_front_exited','ally_traversal_ticks','completion_tick',
        'elapsed','passed','reason')) {
        if (!$fields.ContainsKey($key)) { throw "Malformed AIBGYMI schema-1 result in ${source}: missing $key" }
    }
    foreach ($key in @('archived_complete','rear_gate','front_gate','ally_rear_entered','ally_front_exited','passed')) {
        if ($fields[$key] -notin @('true','false')) { throw "Invalid boolean $key=$($fields[$key]) in $source" }
    }
    $numbers = @{}
    foreach ($key in @('fixture_version','team','map_hash','map_width','map_height','tasks','physical_matches','completed',
        'pending','reservations','work_tiles','ally_traversal_ticks','completion_tick','elapsed')) {
        [double]$value = 0
        if (![double]::TryParse($fields[$key], [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture, [ref]$value)) {
            throw "Invalid numeric $key=$($fields[$key]) in $source"
        }
        $numbers[$key] = $value
    }
    [pscustomobject]@{
        Run = $fields.run
        Variant = $fields.variant
        Metric = $fields.metric
        FixtureId = $fields.fixture_id
        FixtureVersion = [int]$numbers.fixture_version
        Team = [int]$numbers.team
        TeamSide = $fields.team_side
        MapHash = [uint32]$numbers.map_hash
        MapWidth = [int]$numbers.map_width
        MapHeight = [int]$numbers.map_height
        Template = $fields.template
        Tasks = [int]$numbers.tasks
        PhysicalMatches = [int]$numbers.physical_matches
        Completed = [int]$numbers.completed
        Pending = [int]$numbers.pending
        Reservations = [int]$numbers.reservations
        WorkTiles = [int]$numbers.work_tiles
        ArchivedComplete = $fields.archived_complete -eq 'true'
        RearGate = $fields.rear_gate -eq 'true'
        FrontGate = $fields.front_gate -eq 'true'
        AllyRearEntered = $fields.ally_rear_entered -eq 'true'
        AllyFrontExited = $fields.ally_front_exited -eq 'true'
        AllyTraversalTicks = [int]$numbers.ally_traversal_ticks
        CompletionTick = [int]$numbers.completion_tick
        Elapsed = [int]$numbers.elapsed
        Passed = $fields.passed -eq 'true'
        Reason = $fields.reason
        Source = $source
        Canonical = (($fields.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ' ')
    }
}

$records = @()
foreach ($path in $LogPath) {
    $resolved = Resolve-Path -LiteralPath $path
    $lineNumber = 0
    foreach ($line in [IO.File]::ReadLines($resolved.Path)) {
        $lineNumber++
        $record = ConvertTo-InfrastructureRecord $line "${resolved}:$lineNumber"
        if ($null -ne $record) { $records += $record }
    }
}
if ($records.Count -eq 0) { throw 'No complete AIBGYMI schema-1 result records found.' }

$unique = @()
foreach ($runGroup in ($records | Group-Object Run)) {
    if ([string]::IsNullOrWhiteSpace($runGroup.Name)) { throw 'AIBGYMI result has a blank run id.' }
    $canonical = @($runGroup.Group | Select-Object -ExpandProperty Canonical -Unique)
    if ($canonical.Count -ne 1) {
        $sources = ($runGroup.Group.Source -join ', ')
        throw "Conflicting AIBGYMI records reuse run id '$($runGroup.Name)' in: $sources"
    }
    $unique += $runGroup.Group[0]
}

$summaries = @()
$groups = $unique | Group-Object {
    "$($_.FixtureId)|$($_.FixtureVersion)|$($_.Team)|$($_.TeamSide)|$($_.MapHash)|$($_.MapWidth)x$($_.MapHeight)|$($_.Metric)|$($_.Template)"
}
foreach ($group in $groups) {
    $runs = @($group.Group)
    if ($runs.Count -lt $MinimumRunsPerCohort) {
        throw "Infrastructure cohort '$($group.Name)' has $($runs.Count) unique run(s); requires $MinimumRunsPerCohort."
    }
    $passed = @($runs | Where-Object Passed)
    $fullPhysical = @($runs | Where-Object {
        $_.PhysicalMatches -eq $_.Tasks -and $_.Completed -eq $_.Tasks -and $_.Pending -eq 0 -and
        $_.Reservations -eq 0 -and $_.WorkTiles -eq 0 -and $_.ArchivedComplete -and $_.RearGate -and
        $_.FrontGate -and $_.AllyRearEntered -and $_.AllyFrontExited
    })
    $summary = [pscustomobject]@{
        CohortKey = $group.Name
        Runs = $runs.Count
        PassedRuns = $passed.Count
        FullPhysicalRuns = $fullPhysical.Count
        PassRate = [Math]::Round($passed.Count / [double]$runs.Count, 4)
        MeanCompletionTick = [Math]::Round(($runs | Measure-Object CompletionTick -Average).Average, 3)
        MeanAllyTraversalTicks = [Math]::Round(($runs | Measure-Object AllyTraversalTicks -Average).Average, 3)
        MinAllyTraversalTicks = ($runs | Measure-Object AllyTraversalTicks -Minimum).Minimum
        MaxAllyTraversalTicks = ($runs | Measure-Object AllyTraversalTicks -Maximum).Maximum
        RunIds = @($runs.Run | Sort-Object)
        Reasons = @($runs.Reason | Sort-Object -Unique)
        AcceptancePassed = $passed.Count -eq $runs.Count -and $fullPhysical.Count -eq $runs.Count
    }
    $summaries += $summary
}

if ($RequireAllPassed) {
    $failed = @($summaries | Where-Object { !$_.AcceptancePassed })
    if ($failed.Count -ne 0) {
        throw "Infrastructure acceptance failed for cohort(s): $(($failed.CohortKey) -join ', ')"
    }
}

if ($AsJson) { $summaries | ConvertTo-Json -Depth 6 }
else { $summaries | Format-Table CohortKey,Runs,PassedRuns,FullPhysicalRuns,PassRate,MeanCompletionTick,MeanAllyTraversalTicks,AcceptancePassed -AutoSize }
