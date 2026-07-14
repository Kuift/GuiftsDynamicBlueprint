$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$renderer = Get-Content -LiteralPath (Join-Path $root 'Scripts\CustomRenderer.as') -Raw
$data = Get-Content -LiteralPath (Join-Path $root 'Scripts\BlueprintData.as') -Raw
$memory = Get-Content -LiteralPath (Join-Path $root 'Scripts\BlueprintMemory.as') -Raw

foreach ($needle in @(
    'array<Vec2f> blueprintSaveSelect = {Vec2f(0.0f,0.0f),Vec2f(0.0f,0.0f)};',
    'bool blueprintSaveSelectionValid = false;',
    'blueprintSaveSelectionValid = false;'
)) {
    if (!$renderer.Contains($needle)) { throw "Dedicated blueprint save-selection state is incomplete: $needle" }
}

$normalizeStart = $renderer.IndexOf('bool AIB_NormalizeTileRect(')
$normalizeEnd = $renderer.IndexOf('bool AIB_NormalizeSelectionRect(', $normalizeStart)
$selectionEnd = $renderer.IndexOf('void AIB_SendBlueprintBlockCommand(', $normalizeEnd)
if ($normalizeStart -lt 0 -or $normalizeEnd -le $normalizeStart -or $selectionEnd -le $normalizeEnd) {
    throw 'Blueprint rectangle normalization/commit helpers could not be isolated'
}
$normalize = $renderer.Substring($normalizeStart, $normalizeEnd - $normalizeStart)
$selection = $renderer.Substring($normalizeEnd, $selectionEnd - $normalizeEnd)
foreach ($needle in @(
    'Maths::Floor(first.x)',
    'Maths::Floor(second.y)',
    'Maths::Max(0, Maths::Min(ax, bx))',
    'Maths::Min(map.tilemapwidth - 1, Maths::Max(ax, bx))'
)) {
    if (!$normalize.Contains($needle)) { throw "Rectangle normalization lost inclusive/clamped semantics: $needle" }
}
foreach ($needle in @(
    'return blueprintSaveSelectionValid &&',
    'AIB_NormalizeTileRect(blueprintSaveSelect[0], blueprintSaveSelect[1]',
    'AIB_NormalizeSelectionRect(x1, y1, x2, y2)',
    'blueprintSaveSelect[0] = Vec2f(x1, y1);',
    'blueprintSaveSelect[1] = Vec2f(x2, y2);'
)) {
    if (!$selection.Contains($needle)) { throw "Committed blueprint selection is incomplete: $needle" }
}

$editorStart = $renderer.IndexOf('if(blueprintEditorActive && enableLiveEdit == 1')
$editorEnd = $renderer.IndexOf('if(aibTreeSelectMode', $editorStart)
if ($editorStart -lt 0 -or $editorEnd -le $editorStart) { throw 'Blueprint editor selection gesture could not be isolated' }
$editor = $renderer.Substring($editorStart, $editorEnd - $editorStart)
$begin = $editor.IndexOf('blueprintSaveSelectionValid = false;')
$finish = $editor.IndexOf('displayMouseSelect = AIB_CommitBlueprintSelection();')
if ($begin -lt 0 -or $finish -le $begin) {
    throw 'Blueprint selection must invalidate on press and commit only on release'
}

$saveStart = $renderer.IndexOf('void SaveBlueprintToPng(')
$saveEnd = $renderer.IndexOf('uint16[][] currentBlueprintData;', $saveStart)
if ($saveStart -lt 0 -or $saveEnd -le $saveStart) { throw 'Blueprint save path could not be isolated' }
$save = $renderer.Substring($saveStart, $saveEnd - $saveStart)
foreach ($needle in @(
    'AIB_GetBlueprintSaveRect(x1, y1, x2, y2)',
    'int width = endingXPosition - startingXPosition + 1;',
    'int height = endingYPosition - startingYPosition + 1;',
    'RuntimeBlueprint@ runtimeBlueprint = RuntimeBlueprint(blueprintPath, width, height);',
    'int imageX = xp - startingXPosition;',
    'int imageY = yp - startingYPosition;',
    'runtimeBlueprint.data[imageX][imageY] = blockData;'
)) {
    if (!$save.Contains($needle)) { throw "Blueprint save dimensions/data mapping are incomplete: $needle" }
}
if ($save.Contains('AIB_NormalizeSelectionRect(x1, y1, x2, y2)')) {
    throw 'Blueprint save still reads the shared tree/stone/overseer rectangle'
}

$memoryLoadStart = $renderer.IndexOf('bool LoadBlueprintFromMemory(')
$pngLoadStart = $renderer.IndexOf('void LoadBlueprintFromPng(', $memoryLoadStart)
$loadEnd = $renderer.IndexOf('bool displayLoadedBlueprint', $pngLoadStart)
if ($memoryLoadStart -lt 0 -or $pngLoadStart -le $memoryLoadStart -or $loadEnd -le $pngLoadStart) {
    throw 'Blueprint memory/PNG load paths could not be isolated'
}
$memoryLoad = $renderer.Substring($memoryLoadStart, $pngLoadStart - $memoryLoadStart)
$pngLoad = $renderer.Substring($pngLoadStart, $loadEnd - $pngLoadStart)
foreach ($needle in @(
    'currentBlueprintWidth = blueprint.width;',
    'currentBlueprintHeight = blueprint.height;',
    'currentBlueprintData[x][y] = blueprint.data[x][y];'
)) {
    if (!$memoryLoad.Contains($needle)) { throw "Runtime blueprint round trip is incomplete: $needle" }
}
foreach ($needle in @(
    'currentBlueprintWidth = save_image.getWidth();',
    'currentBlueprintHeight = save_image.getHeight();',
    'currentBlueprintData[save_image.getPixelPosition().x][save_image.getPixelPosition().y] = AIBP_EncodeBlock(uint16(r), b);'
)) {
    if (!$pngLoad.Contains($needle)) { throw "PNG blueprint dimensions/data mapping are incomplete: $needle" }
}
foreach ($needle in @('int16 width;', 'int16 height;', 'uint16[][] empty(width, uint16[](height, 0));')) {
    if (!$memory.Contains($needle)) { throw "Runtime blueprint shape is incomplete: $needle" }
}

$sendStart = $renderer.IndexOf('if(c.isKeyJustPressed(KEY_LBUTTON) && displayLoadedBlueprint == true')
$sendEnd = $renderer.IndexOf('if(c.isKeyJustPressed(KEY_KEY_I)', $sendStart)
$receiveStart = $renderer.IndexOf('if(cmd == this.getCommandID("sendBlueprint")')
$receiveEnd = $renderer.IndexOf('if(cmd == this.getCommandID("setLiveEdit"))', $receiveStart)
if ($sendStart -lt 0 -or $sendEnd -le $sendStart -or $receiveStart -lt 0 -or $receiveEnd -le $receiveStart) {
    throw 'Blueprint prefab send/receive paths could not be isolated'
}
$send = $renderer.Substring($sendStart, $sendEnd - $sendStart)
$receive = $renderer.Substring($receiveStart, $receiveEnd - $receiveStart)
foreach ($needle in @(
    'params.write_u16(currentBlueprintWidth);',
    'params.write_u16(currentBlueprintHeight);',
    'for(int y = 0; y < currentBlueprintHeight; y++)',
    'for(int x = 0; x < currentBlueprintWidth; x++)',
    'params.write_u16(currentBlueprintData[x][y]);'
)) {
    if (!$send.Contains($needle)) { throw "Blueprint packet shape/order is incomplete: $needle" }
}
foreach ($needle in @(
    'uint16 bpWidth = params.read_u16();',
    'uint16 bpHeight = params.read_u16();',
    'for(int y = 0; y < bpHeight; y++)',
    'for(int x = 0; x < bpWidth; x++)',
    'networkBlueprintData[x][y] = params.read_u16();',
    'AIBP_ServerApplyHumanPrefab(netID, expectedVersion, indx, indy, bpWidth, bpHeight, networkBlueprintData);'
)) {
    if (!$receive.Contains($needle)) { throw "Blueprint packet receive/order is incomplete: $needle" }
}

$placementStart = $data.IndexOf('bool AIBP_ApplyHumanPlacement(')
$placementEnd = $data.IndexOf('void AIBP_SaveTasks(', $placementStart)
if ($placementStart -lt 0 -or $placementEnd -le $placementStart) { throw 'Authoritative prefab placement could not be isolated' }
$placement = $data.Substring($placementStart, $placementEnd - $placementStart)
foreach ($needle in @(
    'const int startX = centerX - Maths::Ceil(float(width) / 2.0f);',
    'const int startY = centerY - Maths::Ceil(float(height) / 2.0f);',
    'for (int y = 0; y < height; y++)',
    'for (int x = 0; x < width; x++)',
    'const u16 value = source[x][y];'
)) {
    if (!$placement.Contains($needle)) { throw "Authoritative prefab placement dimensions/order are incomplete: $needle" }
}

function Normalize-Rect {
    param([int]$Ax, [int]$Ay, [int]$Bx, [int]$By, [int]$MapWidth, [int]$MapHeight)
    $sx = [Math]::Max(0, [Math]::Min($Ax, $Bx))
    $sy = [Math]::Max(0, [Math]::Min($Ay, $By))
    $ex = [Math]::Min($MapWidth - 1, [Math]::Max($Ax, $Bx))
    $ey = [Math]::Min($MapHeight - 1, [Math]::Max($Ay, $By))
    if ($sx -gt $ex -or $sy -gt $ey) { return $null }
    return [int[]]@($sx, $sy, $ex, $ey)
}

$rect = Normalize-Rect 6 4 3 2 20 10
if ($null -eq $rect -or ($rect -join ',') -ne '3,2,6,4') { throw 'Reverse-drag rectangle normalization failed' }
$width = $rect[2] - $rect[0] + 1
$height = $rect[3] - $rect[1] + 1
if ($width -ne 4 -or $height -ne 3) { throw "Inclusive selection dimensions failed: ${width}x${height}" }
$single = Normalize-Rect 5 5 5 5 20 10
if ($null -eq $single -or ($single -join ',') -ne '5,5,5,5') { throw 'One-tile blueprint selections are not valid rectangles' }

$source = @(
    @(11, 12, 13),
    @(21, 22, 23),
    @(31, 32, 33),
    @(41, 42, 43)
)
$runtime = foreach ($column in $source) { ,@($column) }
$loaded = foreach ($column in $runtime) { ,@($column) }
for ($x = 0; $x -lt $width; $x++) {
    for ($y = 0; $y -lt $height; $y++) {
        if ($loaded[$x][$y] -ne $source[$x][$y]) { throw "Asymmetric round trip transposed data at $x,$y" }
    }
}
$centerX = 10
$centerY = 8
$startX = $centerX - [Math]::Ceiling($width / 2.0)
$startY = $centerY - [Math]::Ceiling($height / 2.0)
if ($startX -ne 8 -or $startY -ne 6 -or ($startX + $width - 1) -ne 11 -or ($startY + $height - 1) -ne 8) {
    throw 'Asymmetric prefab footprint does not preserve its exact dimensions around the placement anchor'
}

Write-Output 'AIB blueprint selection/save/load round-trip contract passed'
