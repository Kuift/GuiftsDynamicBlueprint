[CmdletBinding()]
param(
    [string[]]$Scenario = @(),
    [string[]]$RunId = @(),
    [switch]$IncludeCold,
    [switch]$Aggregate,
    [string]$Path
)

$ErrorActionPreference = 'Stop'
$researchRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
if ([string]::IsNullOrWhiteSpace($Path)) {
    $Path = Join-Path $researchRoot 'private\fast_loop\runs.ndjson'
}
if (!(Test-Path -LiteralPath $Path)) { throw "Missing path-run record file: $Path" }

$records = foreach ($line in Get-Content -LiteralPath $Path) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try { $record = $line | ConvertFrom-Json -ErrorAction Stop } catch { continue }
    if ([int]$record.schema -lt 4 -or $null -eq $record.path_metrics) { continue }
    if (!$IncludeCold -and $record.mode -ne 'hot') { continue }
    if ($Scenario.Count -gt 0 -and $Scenario -cnotcontains [string]$record.scenario) { continue }
    if ($RunId.Count -gt 0 -and $RunId -cnotcontains [string]$record.run_id) { continue }
    if ([int]$record.path_metrics.valid -ne 1) { continue }

    $firstPath = $record.path_events.first_path_set_tick
    $firstObserved = $record.path_metrics.first_dest_t
    $fixtureTicks = $null
    $fixtureTickSource = $null
    if ($null -ne $record.PSObject.Properties['scenario_ticks'] -and $null -ne $record.scenario_ticks) {
        $fixtureTicks = [int]$record.scenario_ticks
        $fixtureTickSource = [string]$record.scenario_ticks_source
    } elseif ($null -ne $record.fixture_verdict -and $null -ne $record.fixture_verdict.ticks) {
        $fixtureTicks = [int]$record.fixture_verdict.ticks
        $fixtureTickSource = 'fixture_verdict'
    } elseif ($null -ne $record.path_metrics.PSObject.Properties['start_t'] -and
        $null -ne $record.path_metrics.PSObject.Properties['end_t'] -and
        [int]$record.path_metrics.end_t -ge [int]$record.path_metrics.start_t) {
        $fixtureTicks = [int]$record.path_metrics.end_t - [int]$record.path_metrics.start_t
        $fixtureTickSource = 'path_metrics_interval'
    }
    $horizontalMovementTicks = if ($null -ne $record.path_metrics.PSObject.Properties['x_move_ticks']) {
        [int]$record.path_metrics.x_move_ticks
    } else { $null }
    $firstHorizontalMovementTick = if ($null -ne $record.path_metrics.PSObject.Properties['first_x_move_t']) {
        [int]$record.path_metrics.first_x_move_t
    } else { $null }
    [PSCustomObject]@{
        scenario = [string]$record.scenario
        run_id = [string]$record.run_id
        mode = [string]$record.mode
        outcome = [string]$record.outcome
        fixture_ticks = $fixtureTicks
        fixture_ticks_source = $fixtureTickSource
        samples = [int]$record.path_metrics.samples
        net_x_px = [math]::Round([int]$record.path_metrics.net_x10 / 10.0, 1)
        net_y_px = [math]::Round([int]$record.path_metrics.net_y10 / 10.0, 1)
        total_distance_px = [math]::Round([int]$record.path_metrics.total_d10 / 10.0, 1)
        intent_ticks = [int]$record.path_metrics.intent_ticks
        movement_ticks = [int]$record.path_metrics.move_ticks
        horizontal_movement_ticks = $horizontalMovementTicks
        stalled_intent_ticks = [int]$record.path_metrics.stall_ticks
        longest_stall = [int]$record.path_metrics.longest_stall
        destination_changes = [int]$record.path_metrics.dest_changes
        state_changes = [int]$record.path_metrics.state_changes
        obstruction_changes = [int]$record.path_metrics.obstruction_changes
        repaths = [int]$record.path_metrics.repaths
        max_obstruction = [int]$record.path_metrics.max_obstruction
        path_set_events = [int]$record.path_events.path_set_count
        path_replan_events = [int]$record.path_events.path_replan_event_count
        first_path_set_tick = $firstPath
        first_observed_destination_tick = [int]$firstObserved
        first_observed_input_tick = [int]$record.path_metrics.first_intent_t
        first_horizontal_movement_tick = $firstHorizontalMovementTick
        path_to_observer_ticks = if ($null -eq $firstPath -or [int]$firstObserved -eq 0) { $null } else { [int]$firstObserved - [int]$firstPath }
        brain_idle_ticks = [int]$record.path_metrics.brain_idle
        brain_non_idle_ticks = [int]$record.path_metrics.brain_searching + [int]$record.path_metrics.brain_wrong +
            [int]$record.path_metrics.brain_has + [int]$record.path_metrics.brain_stuck + [int]$record.path_metrics.brain_other
        failure = $record.fixture_verdict.failure
    }
}

if (!$Aggregate) {
    $records | Sort-Object scenario, run_id
    return
}

$records | Group-Object scenario | ForEach-Object {
    $group = @($_.Group)
    $ticks = @($group | Where-Object { $null -ne $_.fixture_ticks } | ForEach-Object { [int]$_.fixture_ticks })
    $observerDeltas = @($group | Where-Object { $null -ne $_.path_to_observer_ticks } | ForEach-Object { [int]$_.path_to_observer_ticks })
    [PSCustomObject]@{
        scenario = $_.Name
        runs = $group.Count
        run_ids = (($group.run_id | Sort-Object) -join ',')
        passed = @($group | Where-Object outcome -eq 'pass').Count
        failed = @($group | Where-Object outcome -eq 'fail').Count
        fixture_ticks = (($ticks | Sort-Object -Unique) -join ',')
        fixture_ticks_source = (($group.fixture_ticks_source | Where-Object { $_ } | Sort-Object -Unique) -join ',')
        net_x_px = (($group.net_x_px | Sort-Object -Unique) -join ',')
        total_distance_px = (($group.total_distance_px | Sort-Object -Unique) -join ',')
        stall_ticks = (($group.stalled_intent_ticks | Sort-Object -Unique) -join ',')
        longest_stall = (($group.longest_stall | Sort-Object -Unique) -join ',')
        destination_changes = (($group.destination_changes | Sort-Object -Unique) -join ',')
        state_changes = (($group.state_changes | Sort-Object -Unique) -join ',')
        obstruction_changes = (($group.obstruction_changes | Sort-Object -Unique) -join ',')
        repaths = (($group.repaths | Sort-Object -Unique) -join ',')
        max_obstruction = (($group.max_obstruction | Sort-Object -Unique) -join ',')
        path_sets = (($group.path_set_events | Sort-Object -Unique) -join ',')
        path_to_observer_ticks = (($observerDeltas | Sort-Object -Unique) -join ',')
        brain_non_idle_ticks = (($group.brain_non_idle_ticks | Sort-Object -Unique) -join ',')
    }
} | Sort-Object scenario
