param(
    [string]$HostName = "127.0.0.1",
    [int]$Port = 50301,
    [switch]$SkipConfig
)

$script = Join-Path $PSScriptRoot "codex_tcpr_bridge.py"
$kagRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$configPath = Join-Path $kagRoot "autoconfig.cfg"

function Get-ConfigValue([string]$Text, [string]$Name) {
    $match = [regex]::Match($Text, "(?m)^\s*" + [regex]::Escape($Name) + "\s*=\s*([^#\r\n]*)")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return $null
}

function Set-ConfigValue([string]$Text, [string]$Name, [string]$Value) {
    $pattern = "(?m)^(\s*" + [regex]::Escape($Name) + "\s*=\s*)[^#\r\n]*(.*)$"
    if ([regex]::IsMatch($Text, $pattern)) {
        return [regex]::Replace($Text, $pattern, {
            param($match)
            $match.Groups[1].Value + $Value + " " + $match.Groups[2].Value
        }, 1)
    }
    return $Text.TrimEnd() + [Environment]::NewLine + "$Name = $Value" + [Environment]::NewLine
}

if (!$SkipConfig -and ($HostName -eq "127.0.0.1" -or $HostName -eq "localhost") -and (Test-Path $configPath)) {
    $config = Get-Content -Raw -Path $configPath
    $enabled = (Get-ConfigValue $config "sv_tcpr") -eq "true"
    $password = Get-ConfigValue $config "sv_rconpassword"

    if ([string]::IsNullOrWhiteSpace($password)) {
        $securePassword = Read-Host "Choose a local KAG TCPR password (stored in KAG/autoconfig.cfg)" -AsSecureString
        $password = [System.Net.NetworkCredential]::new("", $securePassword).Password
        if ([string]::IsNullOrWhiteSpace($password)) {
            throw "TCPR requires a non-empty password."
        }
    }

    if (!$enabled -or (Get-ConfigValue $config "sv_tcpr_everything") -ne "false" -or
        (Get-ConfigValue $config "sv_tcpr_timestamp") -ne "false" -or
        (Get-ConfigValue $config "sv_rconpassword") -ne $password) {
        $config = Set-ConfigValue $config "sv_tcpr" "true"
        $config = Set-ConfigValue $config "sv_tcpr_everything" "false"
        $config = Set-ConfigValue $config "sv_tcpr_timestamp" "false"
        $config = Set-ConfigValue $config "sv_rconpassword" $password
        Set-Content -Path $configPath -Value $config -NoNewline
        Write-Host "Configured TCPR in $configPath"
        Write-Host "Restart KAG if it is already running; the bridge will wait for it."
    }

    $env:KAG_TCPR_PASSWORD = $password
}

python $script --host $HostName --port $Port
