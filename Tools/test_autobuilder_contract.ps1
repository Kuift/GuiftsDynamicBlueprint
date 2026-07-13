$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Read-RepoFile([string]$relativePath) {
    return Get-Content -LiteralPath (Join-Path $root $relativePath) -Raw
}

function Assert-Contains([string]$source, [string]$needle, [string]$message) {
    if (!$source.Contains($needle)) { throw "$message Missing: $needle" }
}

$config = Read-RepoFile 'Base\Entities\Characters\AutoBuilder\AutoBuilder.cfg'
$entity = Read-RepoFile 'Base\Entities\Characters\AutoBuilder\AutoBuilder.as'
$common = Read-RepoFile 'Scripts\AutoBuilderCommon.as'
$brain = Read-RepoFile 'Base\Entities\Characters\AIBuilder\AIBuilderBrain.as'
$shop = Read-RepoFile 'Base\Entities\Industry\CTFShops\AIBuilderShop\AIBuilderShop.as'
$jobs = Read-RepoFile 'Scripts\AIBStrategicJobs.as'
$director = Read-RepoFile 'Scripts\AIBStrategicDirector.as'
$types = Read-RepoFile 'Scripts\AIBStrategicTypes.as'
$world = Read-RepoFile 'Scripts\AIBWorldModel.as'
$planner = Read-RepoFile 'Scripts\AIBPlacementPlanner.as'
$scenarios = Read-RepoFile 'Scripts\AIBTestScenarios.as'
$renderer = Read-RepoFile 'Scripts\CustomRenderer.as'
$chat = Read-RepoFile 'Rules\CommonScripts\ChatCommands.as'
$wave = Read-RepoFile 'Scripts\AIBStrategyWaveHarness.as'

foreach ($needle in @(
    '$sprite_texture                                   = MagicOrb.png',
    'bool shape_collides                               = no',
    '$movement_factory                                 =',
    '$brain_factory                                    = generic_brain',
    '@$scripts                                         = AIBuilderBrain.as;',
    '$inventory_factory                                =',
    '$name                                             = autobuilder'
)) { Assert-Contains $config $needle 'Autobuilder entity config is incomplete.' }
if ($config -notmatch '(?m)^\$movement_factory\s*=\s*$' -or $config -notmatch '(?m)^\$inventory_factory\s*=\s*$') {
    throw 'Autobuilder movement and inventory factories must both be empty'
}

foreach ($needle in @(
    'shape.getConsts().mapCollisions = false;',
    'shape.getConsts().collidable = false;',
    'shape.SetGravityScale(0.0f);',
    'bool doesCollideWithBlob',
    'autobuilder build blueprint'
)) { Assert-Contains $entity $needle 'Autobuilder collision/manual-order contract is incomplete.' }
if ($entity -notmatch '(?s)bool doesCollideWithBlob\([^\)]*\)\s*\{\s*return false;\s*\}') {
    throw 'Autobuilder blob collision callback must unconditionally return false'
}
foreach ($needle in @(
    'caller.getTeamNum() != this.getTeamNum()',
    'caller.getDistanceTo(this) > 32.0f'
)) { Assert-Contains $entity $needle 'Manual Autobuilder order lacks authoritative team/radius validation.' }
if ($entity -match 'server_SetTile|server_DestroyTile') {
    throw 'Autobuilder entity script must use the shared blueprint executor, not mutate terrain directly'
}

foreach ($needle in @(
    'const u8 AIBU_PLACE_DELAY_TICKS = 30;',
    'const u8 AIBU_MAX_SPEED_LEVEL = 3;',
    'const u16 AIBU_SPEED_UPGRADE_GOLD_COST = 50;',
    'f32 AIBU_GetFlightSpeed',
    'case 1: return 6.0f;',
    'case 2: return 8.0f;',
    'case 3: return 12.0f;',
    'return 4.0f;',
    'rules.Sync(AIBU_SpeedLevelKey(team), true);'
)) { Assert-Contains $common $needle 'Autobuilder speed policy is incomplete.' }

foreach ($needle in @(
    'AIB_TickAutoBuilder(this, blob);',
    'AIB_GoToAutoBuilder(blob, destination);',
    'const f32 speed = AIBU_GetFlightSpeed(u8(blob.getTeamNum()));',
    'if (gameTime < blob.get_u32("ai builder next place")) return false;',
    'if (AIBU_IsAutoBuilder(blob)) return 65535;',
    'if (AIBU_IsAutoBuilder(blob)) return true;',
    'if (AIBU_IsAutoBuilder(blob)) return false;',
    'return AIBU_IsAutoBuilder(blob) ? AIBU_PLACE_DELAY_TICKS : AIB_BLUEPRINT_PLACE_DELAY;'
)) { Assert-Contains $brain $needle 'Shared blueprint executor is missing an Autobuilder specialization.' }
if ($brain -notmatch '(?s)bool AIB_GetBlueprintMaterialNeed\(.*?if \(AIBU_IsAutoBuilder\(blob\)\) return false;.*?\n\}') {
    throw 'Infinite-resource material-need bypass is not scoped to AIB_GetBlueprintMaterialNeed'
}
if ($brain -notmatch '(?s)u16 AIB_CountMaterial\(.*?if \(AIBU_IsAutoBuilder\(blob\)\) return 65535;.*?\n\}') {
    throw 'Infinite-resource material count is not scoped to AIB_CountMaterial'
}
if ($brain -notmatch '(?s)bool AIB_TakeMaterial\(.*?if \(AIBU_IsAutoBuilder\(blob\)\) return true;.*?\n\}') {
    throw 'Infinite-resource payment bypass is not scoped to AIB_TakeMaterial'
}
$placeWrites = [regex]::Matches($brain, 'set_u32\("ai builder next place",[^;]+AIB_GetBlueprintPlaceDelay\(blob\)\);').Count
if ($placeWrites -ne 3) { throw "Expected all three blueprint placement outcomes to use the shared delay helper; found $placeWrites" }

foreach ($needle in @(
    'Vec2f(2, 2)',
    '"Autobuilder Orb"',
    'this.addCommandID("upgrade autobuilder flight");',
    'caller.getTeamNum() != this.getTeamNum()',
    'this.hasTag("shop disabled")',
    'inventory.getCount("mat_gold") < AIBU_SPEED_UPGRADE_GOLD_COST',
    'inventory.server_RemoveItems("mat_gold", AIBU_SPEED_UPGRADE_GOLD_COST);',
    'AIBU_SetSpeedLevel(rules, team, AIBU_GetSpeedLevel(team) + 1);',
    'this.SendCommand(this.getCommandID("shop made item client"), soundParams);',
    'caller.getTeamNum() != shop.getTeamNum()',
    'rules.set_u32("aib strategy important event team " + caller.getTeamNum(), getGameTime());'
)) { Assert-Contains $shop $needle 'AI workshop Autobuilder integration is incomplete.' }
if ($shop -match 'spawnNothing|RefundUpgradeGold') { throw 'Gold upgrade must not use the generic pre-charging shop/refund path' }

foreach ($needle in @(
    'string[] names = { "aibuilder", AIBU_ENTITY_NAME };',
    'AIBS_SetBuilderJob(teamBuilders[i], AIBS_JOB_BLUEPRINT, AIBS_STATE_FIND_BLUEPRINT);',
    'if (hasAutoBuilder)',
    'builder.get_bool("aib strategy assigned") && builder.get_u8("ai builder job") == AIBS_JOB_BLUEPRINT',
    'AIBS_SetBuilderJob(builder, AIBS_JOB_WOOD, AIBS_STATE_FIND_TREE);'
)) { Assert-Contains $jobs $needle 'Director must discover Autobuilders and keep them out of harvesting roles.' }
if ($jobs -notmatch '(?s)AIBU_IsAutoBuilder\(teamBuilders\[i\]\).*?AIBS_SetBuilderJob\(teamBuilders\[i\], AIBS_JOB_BLUEPRINT, AIBS_STATE_FIND_BLUEPRINT\);.*?teamBuilders\.removeAt\(i\);.*?if \(hasAutoBuilder\).*?return;') {
    throw 'Autobuilder partition must assign the orb and short-circuit ordinary shortage/build allocation'
}
Assert-Contains $director 'blob.getName() == "aibuilder" || AIBU_IsAutoBuilder(blob)' 'Director death cleanup must release Autobuilder reservations.'
Assert-Contains $director 'AIBU_InitSpeedPolicy(this, team);' 'Director must initialize Autobuilder team speed policy.'
Assert-Contains $director 'AIBU_ResetSpeedLevel(this, team);' 'Director must reset Autobuilder speed each round.'
Assert-Contains $types 'u16 autoBuilders;' 'World state must distinguish Autobuilders.'
Assert-Contains $world 'if (name == "autobuilder") world.autoBuilders++;' 'World observation must count Autobuilders.'
if ($world -notmatch '(?s)bool AIBS_IsCombatBlob\(.*?name == "autobuilder";\s*\}') {
    throw 'AIBS_IsCombatBlob must admit Autobuilders before world worker counting'
}
foreach ($needle in @(
    'world.autoBuilders == 0 && !AIBS_TaskHasApproach',
    'world.autoBuilders == 0 && !AIBS_AllTasksHaveReachableApproach',
    'world.autoBuilders == 0 && (wood > world.storedWood + 1200',
    'world.autoBuilders > 0 ? 0 : (wood > world.storedWood',
    'world.autoBuilders > 0 ? 0 : (stone > world.storedStone'
)) { Assert-Contains $planner $needle 'Planner still binds Autobuilder strategy tests to path/resource availability.' }

foreach ($needle in @(
    'getBlobsByName("autobuilder", @untrackedAutoBuilders);',
    'AIBP_ReleaseBuilderReservation(u8(worker.getTeamNum()), worker.getNetworkID());',
    'for (u8 team = 0; team < 8; team++) AIBU_ResetSpeedLevel(rules, team);',
    'getBlobsByName("autobuilder", @autoBuilders);',
    'if (brain !is null) brain.server_SetActive(false);'
)) { Assert-Contains $scenarios $needle 'AIBTest cleanup does not isolate Autobuilder state.' }
if ($scenarios -notmatch '(?s)getBlobsByName\("autobuilder", @untrackedAutoBuilders\);.*?AIBP_ReleaseBuilderReservation\(u8\(worker\.getTeamNum\(\)\), worker\.getNetworkID\(\)\);.*?worker\.server_Die\(\);') {
    throw 'Untracked workshop Autobuilders must release reservations before scenario cleanup kills them'
}

foreach ($needle in @(
    'AIB_GetConstructionWorkers(builders);',
    'builder.getName() != "aibuilder" && builder.getName() != "autobuilder"',
    'if(autoBuilder && order != AIB_OVERSEER_ORDER_BLUEPRINT) return;',
    'builder.set_u8("ai builder state", autoBuilder ? 13 : 12);',
    'builder.set_bool("ai builder job active", true);',
    'Wood shortage: ignored by Autobuilder',
    'Stone shortage: ignored by Autobuilder'
)) { Assert-Contains $renderer $needle 'Overseer control does not support blueprint-only Autobuilder orders.' }

foreach ($needle in @(
    'const u16 fixtureVersion = 3;',
    'AIBWF_CaptureWorldManifest(rules, map, terrainHash, solidTiles, noBuildHash, noBuildTiles,',
    'normalAIBuilderCount',
    'autoBuilderCount',
    'aiBuilderTypePositionHash',
    'autoBuilderSpeedLevel = AIBU_GetSpeedLevel(team)'
)) { Assert-Contains $chat $needle 'Wave initial identity does not isolate Autobuilder type/speed.' }
foreach ($needle in @(
    'initial_autobuilder_speed_level=',
    'initial_ai_builder_type_position_hash=',
    'measurement_strategy_hash=',
    'AIBWF_CaptureWorldManifest(rules, map, terrainHash, solidTiles, noBuildHash, noBuildTiles,'
)) { Assert-Contains $wave $needle 'Wave result/measurement identity omits Autobuilder state.' }

Write-Output 'Autobuilder static contract passed'
