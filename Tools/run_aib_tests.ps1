param(
    [int]$TimeoutSeconds = 180,
    [int]$StaleSeconds = 25,
    [string]$Scenario = "",
    [string]$StartScenario = "",
    [string]$EndScenario = "",
    [switch]$StopAfterRun
)

$ErrorActionPreference = "Stop"

if ($TimeoutSeconds -le 0) {
    throw "TimeoutSeconds must be greater than zero."
}
if ($StaleSeconds -le 0) {
    throw "StaleSeconds must be greater than zero."
}

$modRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$kagRoot = Resolve-Path (Join-Path $modRoot "..\..")
$logsDir = Join-Path $kagRoot "Logs"
$kagExe = Join-Path $kagRoot "KAG.exe"
$parser = Join-Path $PSScriptRoot "parse_aib_test_log.ps1"
$scenarioSource = Join-Path $modRoot "Scripts\AIBTestScenarios.as"
$autostart = "../Mods/GuiftsDynamicBlueprint_vDev/Scripts/aib_test_autostart.as"
$kagAutoconfig = Join-Path $kagRoot "autoconfig.cfg"
$kagAutoconfigOriginal = if (Test-Path $kagAutoconfig) { Get-Content -LiteralPath $kagAutoconfig -Raw } else { $null }
$aibTestGamemode = Join-Path $modRoot "Rules\AIBTest\gamemode.cfg"
$aibTestGamemodeOriginal = if (Test-Path $aibTestGamemode) { Get-Content -LiteralPath $aibTestGamemode -Raw } else { $null }
$ctfGamemode = Join-Path $modRoot "Rules\CTF\gamemode.cfg"
$ctfGamemodeDisabled = Join-Path $modRoot "Rules\CTF\gamemode.cfg.aibtest-disabled"

if (!(Test-Path $kagExe)) {
    throw "KAG.exe not found at $kagExe"
}
if ($null -eq $aibTestGamemodeOriginal) {
    throw "AIBTest gamemode config not found at $aibTestGamemode"
}

function Get-AIBScenarioNames {
    $source = Get-Content -LiteralPath $scenarioSource -Raw
    $arrayMatch = [regex]::Match(
        $source,
        '(?s)string\[\]\s+AIBT_SCENARIOS\s*=\s*\{(?<body>.*?)\};'
    )
    if (!$arrayMatch.Success) {
        throw "Could not read AIBT_SCENARIOS from $scenarioSource"
    }

    $names = @(
        [regex]::Matches($arrayMatch.Groups['body'].Value, '"(?<name>[^"]+)"') |
            ForEach-Object { $_.Groups['name'].Value }
    )
    if ($names.Count -eq 0) {
        throw "AIBT_SCENARIOS is empty in $scenarioSource"
    }
    return $names
}

function Get-AIBScenarioIndex {
    param(
        [string[]]$Names,
        [string]$Name
    )

    for ($i = 0; $i -lt $Names.Count; $i++) {
        if ([string]::Equals($Names[$i], $Name, [System.StringComparison]::Ordinal)) {
            return $i
        }
    }
    return -1
}

function Set-AIBConfigValue {
    param(
        [string]$Text,
        [string]$Key,
        [string]$Value
    )

    $pattern = '(?m)^([ \t]*' + [regex]::Escape($Key) + '[ \t]*=[ \t]*).*$'
    if (![regex]::IsMatch($Text, $pattern)) {
        throw "Missing $Key in $aibTestGamemode"
    }
    return [regex]::Replace($Text, $pattern, ('${1}' + $Value))
}

function Set-AIBTestSelection {
    param(
        [string]$Exact,
        [string]$First,
        [string]$Last
    )

    $config = $aibTestGamemodeOriginal
    $config = Set-AIBConfigValue $config "aibtest_scenario" $Exact
    $config = Set-AIBConfigValue $config "aibtest_start_scenario" $First
    $config = Set-AIBConfigValue $config "aibtest_end_scenario" $Last
    Set-Content -LiteralPath $aibTestGamemode -Value $config -NoNewline
}

$hasExact = ![string]::IsNullOrWhiteSpace($Scenario)
$hasStart = ![string]::IsNullOrWhiteSpace($StartScenario)
$hasEnd = ![string]::IsNullOrWhiteSpace($EndScenario)
if ($hasExact -and ($hasStart -or $hasEnd)) {
    throw "-Scenario cannot be combined with -StartScenario or -EndScenario."
}

$allScenarioNames = @(Get-AIBScenarioNames)
$firstIndex = 0
$lastIndex = $allScenarioNames.Count - 1
if ($hasExact) {
    $firstIndex = Get-AIBScenarioIndex -Names $allScenarioNames -Name $Scenario
    if ($firstIndex -lt 0) {
        throw "Unknown AIB test scenario: $Scenario"
    }
    $lastIndex = $firstIndex
} else {
    if ($hasStart) {
        $firstIndex = Get-AIBScenarioIndex -Names $allScenarioNames -Name $StartScenario
        if ($firstIndex -lt 0) {
            throw "Unknown AIB test start scenario: $StartScenario"
        }
    }
    if ($hasEnd) {
        $lastIndex = Get-AIBScenarioIndex -Names $allScenarioNames -Name $EndScenario
        if ($lastIndex -lt 0) {
            throw "Unknown AIB test end scenario: $EndScenario"
        }
    }
    if ($firstIndex -gt $lastIndex) {
        throw "Start scenario '$StartScenario' comes after end scenario '$EndScenario'."
    }
}

$selectedScenarioNames = @($allScenarioNames[$firstIndex..$lastIndex])
$expectedCount = $selectedScenarioNames.Count

function Restore-AIBTestFiles {
    if ((Test-Path $ctfGamemodeDisabled) -and !(Test-Path $ctfGamemode)) {
        Move-Item -LiteralPath $ctfGamemodeDisabled -Destination $ctfGamemode
    }
    if ($null -ne $kagAutoconfigOriginal) {
        Set-Content -LiteralPath $kagAutoconfig -Value $kagAutoconfigOriginal -NoNewline
    }
    if ($null -ne $aibTestGamemodeOriginal) {
        Set-Content -LiteralPath $aibTestGamemode -Value $aibTestGamemodeOriginal -NoNewline
    }
}

function Test-AIBLogComplete {
    param(
        [string]$Text,
        [int]$ExpectedCount
    )

    if ($Text -notmatch "\[AIBTEST\] BOOT scenarios=(\d+)") { return $false }

    $declared = [int]$Matches[1]
    if ($ExpectedCount -le 0 -or $declared -ne $ExpectedCount) { return $false }

    if ($Text -match "\[AIBTEST\] CONFIG_ERROR") { return $true }
    # The final fixture is intentionally retained. DONE means all selected
    # verdicts are final; the parser verifies their count and order.
    return $Text -match "\[AIBTEST\] DONE"
}

try {
    $configExact = if ($hasExact) { $Scenario } else { "" }
    $configFirst = if (!$hasExact -and $hasStart) { $StartScenario } else { "" }
    $configLast = if (!$hasExact -and $hasEnd) { $EndScenario } else { "" }
    Set-AIBTestSelection -Exact $configExact -First $configFirst -Last $configLast

    Write-Host "AIB test selection: $($selectedScenarioNames[0]) through $($selectedScenarioNames[-1]) ($expectedCount scenario(s))"

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
    $lastProgressAt = $null
    $lastObservedLength = [int64]-1
    $lastObservedWriteUtc = [DateTime]::MinValue
    $lastHeartbeatGameTime = [int64]-1
    $lastHeartbeatScenario = "unknown"
    $scenarioStarted = $false
    $stalled = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        $candidates = Get-ChildItem $logsDir -Filter "console-*.txt" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $startedAt.AddSeconds(-2) } |
            Sort-Object LastWriteTime -Descending

        foreach ($candidate in $candidates) {
            if (!$before.ContainsKey($candidate.FullName)) {
                if ($log -and $candidate.FullName -ne $log) {
                    continue
                }
                $text = Get-Content $candidate.FullName -Raw -ErrorAction SilentlyContinue
                # Rules can fail before AIBTestRunner emits its first marker.
                # Treat a fresh mod script error as immediate evidence instead
                # of spending the whole behavior timeout waiting for a marker
                # that cannot be produced.
                if ($text -match 'ERROR .*GuiftsDynamicBlueprint_vDev|Rules partially failed initialization|Script .* has errors') {
                    $log = $candidate.FullName
                    if (!$process.HasExited) {
                        Stop-Process -Id $process.Id -Force
                    }
                    $compileLines = @(Select-String -LiteralPath $log -Pattern 'ERROR .*GuiftsDynamicBlueprint_vDev|Rules partially failed initialization|Script .* has errors' |
                        Select-Object -Last 8 | ForEach-Object { $_.Line })
                    Restore-AIBTestFiles
                    Write-Error ("AIB test rules failed before START: log={0}`n{1}" -f $log, ($compileLines -join "`n"))
                    exit 2
                }
                if ($text -match "\[AIBTEST\]") {
                    $now = Get-Date
                    $firstActivity = !$log
                    $log = $candidate.FullName

                    $heartbeatMatches = [regex]::Matches(
                        $text,
                        '\[AIBTEST\] HEARTBEAT scenario=(?<scenario>[^\s]+).*?gametime=(?<gametime>\d+)'
                    )
                    $heartbeatAdvanced = $false
                    if ($heartbeatMatches.Count -gt 0) {
                        $latestHeartbeat = $heartbeatMatches[$heartbeatMatches.Count - 1]
                        $heartbeatGameTime = [int64]$latestHeartbeat.Groups['gametime'].Value
                        $lastHeartbeatScenario = $latestHeartbeat.Groups['scenario'].Value
                        if ($heartbeatGameTime -gt $lastHeartbeatGameTime) {
                            $lastHeartbeatGameTime = $heartbeatGameTime
                            $heartbeatAdvanced = $true
                        }
                    }
                    $startMatches = [regex]::Matches($text, '\[AIBTEST\] START (?<scenario>[^\s]+)')
                    if ($startMatches.Count -gt 0) {
                        $scenarioStarted = $true
                        $lastHeartbeatScenario = $startMatches[$startMatches.Count - 1].Groups['scenario'].Value
                    }

                    $fileAdvanced = $firstActivity -or
                        $candidate.Length -ne $lastObservedLength -or
                        $candidate.LastWriteTimeUtc -ne $lastObservedWriteUtc
                    if ($fileAdvanced -or $heartbeatAdvanced) {
                        $lastProgressAt = $now
                        $lastObservedLength = $candidate.Length
                        $lastObservedWriteUtc = $candidate.LastWriteTimeUtc
                    }

                    # KAG can append/flush between Get-Content and this check.
                    # Query the file directly for DONE as well; the parser below
                    # remains authoritative for scenario counts and ordering.
                    $doneOnDisk = Select-String -LiteralPath $candidate.FullName -SimpleMatch '[AIBTEST] DONE' -Quiet -ErrorAction SilentlyContinue
                    if ($doneOnDisk -or (Test-AIBLogComplete $text $expectedCount)) {
                        if ($StopAfterRun -and !$process.HasExited) {
                            Stop-Process -Id $process.Id -Force
                        } elseif (!$process.HasExited) {
                            Write-Host "KAG left running visibly (PID $($process.Id))."
                        }
                        Restore-AIBTestFiles
                        & $parser -LogPath $log -ExpectedScenarios $selectedScenarioNames
                        exit $LASTEXITCODE
                    }
                }
            }
        }

        # BOOT can precede several seconds of normal asset loading. Focused
        # stale limits apply only once a real scenario has started; the outer
        # timeout remains the startup/compile-hang guard.
        if ($scenarioStarted -and $lastProgressAt -and !$process.HasExited -and
            ((Get-Date) - $lastProgressAt).TotalSeconds -ge $StaleSeconds) {
            $stalled = $true
            break
        }

        if ($process.HasExited) {
            if ($log) {
                & $parser -LogPath $log -ExpectedScenarios $selectedScenarioNames
                Write-Error "KAG exited before [AIBTEST] DONE: exit_code=$($process.ExitCode) scenario=$lastHeartbeatScenario gametime=$lastHeartbeatGameTime log=$log"
            } else {
                $latest = $candidates | Select-Object -First 1
                if ($latest) {
                    Write-Error "KAG exited before producing [AIBTEST] output: exit_code=$($process.ExitCode) latest_log=$($latest.FullName)"
                } else {
                    Write-Error "KAG exited before producing a console log: exit_code=$($process.ExitCode)"
                }
            }
            exit 2
        }
    }


    if ($stalled) {
        if ($StopAfterRun -and !$process.HasExited) {
            Stop-Process -Id $process.Id -Force
        } elseif (!$process.HasExited) {
            Write-Host "KAG left running visibly after detected stall (PID $($process.Id))."
        }

        if ($log) {
            & $parser -LogPath $log -ExpectedScenarios $selectedScenarioNames
        }

        $gameTimeText = if ($lastHeartbeatGameTime -ge 0) { [string]$lastHeartbeatGameTime } else { "unknown" }
        Write-Error "AIB test simulation/log stalled for $StaleSeconds seconds: scenario=$lastHeartbeatScenario gametime=$gameTimeText PID=$($process.Id) log=$log" -ErrorAction Continue
        exit 2
    }

    if ($StopAfterRun -and !$process.HasExited) {
        Stop-Process -Id $process.Id -Force
    } elseif (!$process.HasExited) {
        Write-Host "KAG left running visibly after timeout (PID $($process.Id))."
    }

    if ($log) {
        & $parser -LogPath $log -ExpectedScenarios $selectedScenarioNames
        if ($LASTEXITCODE -eq 0) {
            exit 0
        }
        Write-Error "Timed out waiting for AIB test completion. Latest test log: $log"
    } else {
        Write-Error "Timed out waiting for an AIB test log."
    }
    exit 2
}
finally {
    Restore-AIBTestFiles
}
