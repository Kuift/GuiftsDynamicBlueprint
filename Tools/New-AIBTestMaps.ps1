param(
    [string]$OutputDir = "$PSScriptRoot\..\Maps\AIBTest"
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$resolved = Resolve-Path (Join-Path $PSScriptRoot "..")
$out = Join-Path $resolved "Maps\AIBTest"
New-Item -ItemType Directory -Force -Path $out | Out-Null

$colors = @{
    Sky = [System.Drawing.Color]::FromArgb(255, 165, 189, 200)
    Ground = [System.Drawing.Color]::FromArgb(255, 132, 71, 21)
    Castle = [System.Drawing.Color]::FromArgb(255, 100, 113, 96)
    CastleBack = [System.Drawing.Color]::FromArgb(255, 49, 52, 18)
}

function Set-Rect {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$X1,
        [int]$Y1,
        [int]$X2,
        [int]$Y2,
        [System.Drawing.Color]$Color
    )

    for ($y = $Y1; $y -le $Y2; $y++) {
        for ($x = $X1; $x -le $X2; $x++) {
            if ($x -ge 0 -and $y -ge 0 -and $x -lt $Bitmap.Width -and $y -lt $Bitmap.Height) {
                $Bitmap.SetPixel($x, $y, $Color)
            }
        }
    }
}

$width = 420
$height = 100
$groundY = 72
$bmp = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

for ($y = 0; $y -lt $height; $y++) {
    for ($x = 0; $x -lt $width; $x++) {
        $bmp.SetPixel($x, $y, $(if ($y -ge $groundY) { $colors.Ground } else { $colors.Sky }))
    }
}

# Hill fixture for high-level pathing checks.
for ($x = 118; $x -le 158; $x++) {
    $top = $groundY
    if ($x -le 128) {
        $top = 64
    } elseif ($x -le 150) {
        $top = 64 + [Math]::Floor(($x - 128) / 2)
    }
    Set-Rect -Bitmap $bmp -X1 $x -Y1 $top -X2 $x -Y2 ($groundY - 1) -Color $colors.Ground
}

# Tall wall fixture used by enemy-line-of-sight tests.
Set-Rect -Bitmap $bmp -X1 260 -Y1 61 -X2 260 -Y2 ($groundY - 1) -Color $colors.Castle

# Low non-mineable obstacle fixture used by route/recovery tests.
Set-Rect -Bitmap $bmp -X1 320 -Y1 69 -X2 320 -Y2 ($groundY - 1) -Color $colors.Castle

# Mineable dirt plug fixture used by KAG_PATH mining tests.
Set-Rect -Bitmap $bmp -X1 352 -Y1 68 -X2 353 -Y2 ($groundY - 1) -Color $colors.Ground

# Blueprint fixtures: backwall support where tests ask the builder to place solid blocks.
Set-Rect -Bitmap $bmp -X1 388 -Y1 ($groundY - 1) -X2 404 -Y2 ($groundY - 1) -Color $colors.CastleBack

$path = Join-Path $out "aib_suite.png"
$bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Host "Wrote $path"
