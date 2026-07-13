$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root 'Scripts\AIBTestScenarios.as'
$source = Get-Content -LiteralPath $path -Raw
$registryMatch = [regex]::Match($source, 'string\[\]\s+AIBT_SCENARIOS\s*=\s*\{(?<body>[\s\S]*?)\};')
if (!$registryMatch.Success) { throw 'Could not parse AIBT_SCENARIOS registry' }
$names = @([regex]::Matches($registryMatch.Groups['body'].Value, '"(?<name>[^"]+)"') | ForEach-Object { $_.Groups['name'].Value })
if ($names.Count -ne 60) { throw "Expected 60 registered scenarios, found $($names.Count)" }
if (@($names | Select-Object -Unique).Count -ne $names.Count) { throw 'Scenario registry contains duplicate names' }

for ($i = 0; $i -lt $names.Count; $i++) {
    $needle = 'case {0}:' -f $i
    $count = ([regex]::Matches($source, [regex]::Escape($needle))).Count
    if ($count -ne 2) { throw "Scenario $i '$($names[$i])' requires one setup and one evaluation case; found $count" }
}

Write-Output 'AIB scenario registry passed (60 unique setup/evaluation pairs)'
