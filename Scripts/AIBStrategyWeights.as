class AIBStrategyWeights
{
	u16 version = 1;
	f32 baseDefense = 20.0f;
	f32 enemyKnightPressure = 9.0f;
	f32 enemyArcherPressure = 6.0f;
	f32 worldPressure = 12.0f;
	f32 accessRouteGain = 55.0f;
	f32 defaultRouteGain = 15.0f;
	f32 heightMeasureScale = 4.0f;
	f32 tacticalHeightBonus = 15.0f;
	f32 nonTacticalHeightScale = 0.25f;
	f32 chokepoint = 3.0f;
	f32 sightline = 1.5f;
	f32 emergencyUrgency = 100.0f;
	f32 gatehouseKnightFit = 8.0f;
	f32 otherArcherFit = 5.0f;
	f32 localPressureFit = 4.0f;
	f32 continuityMax = 24.0f;
	f32 continuityDistance = 0.75f;
	u32 templateCooldownTicks = 900;
	f32 templateCooldownPenalty = 20.0f;
	f32 woodCost = 0.08f;
	f32 stoneCost = 0.06f;
	f32 woodShortage = 0.16f;
	f32 stoneShortage = 0.12f;
	f32 travel = 0.04f;
	f32 taskBuildTime = 1.2f;
	f32 exposureFreeDistance = 160.0f;
	f32 exposureDistance = 0.08f;
	f32 exposurePressure = 2.0f;
	f32 friendlyRoutePenalty = 60.0f;
	f32 nearBestFraction = 0.07f;
}

AIBStrategyWeights AIBS_strategy_weights;
bool AIBS_strategy_weights_loaded = false;

AIBStrategyWeights@ AIBS_GetStrategyWeights()
{
	if (AIBS_strategy_weights_loaded) return @AIBS_strategy_weights;
	AIBS_strategy_weights_loaded = true;
	ConfigFile cfg = ConfigFile();
	const string filename = CFileMatcher("AIBStrategyWeights.cfg").getFirst();
	if (filename != "") cfg.loadFile(filename);
	AIBS_strategy_weights.version = u16(cfg.read_s32("config_version", 1));
	AIBS_strategy_weights.baseDefense = cfg.read_f32("base_defense", 20.0f);
	AIBS_strategy_weights.enemyKnightPressure = cfg.read_f32("enemy_knight_pressure", 9.0f);
	AIBS_strategy_weights.enemyArcherPressure = cfg.read_f32("enemy_archer_pressure", 6.0f);
	AIBS_strategy_weights.worldPressure = cfg.read_f32("world_pressure", 12.0f);
	AIBS_strategy_weights.accessRouteGain = cfg.read_f32("access_route_gain", 55.0f);
	AIBS_strategy_weights.defaultRouteGain = cfg.read_f32("default_route_gain", 15.0f);
	AIBS_strategy_weights.heightMeasureScale = cfg.read_f32("height_measure_scale", 4.0f);
	AIBS_strategy_weights.tacticalHeightBonus = cfg.read_f32("tactical_height_bonus", 15.0f);
	AIBS_strategy_weights.nonTacticalHeightScale = cfg.read_f32("non_tactical_height_scale", 0.25f);
	AIBS_strategy_weights.chokepoint = cfg.read_f32("chokepoint", 3.0f);
	AIBS_strategy_weights.sightline = cfg.read_f32("sightline", 1.5f);
	AIBS_strategy_weights.emergencyUrgency = cfg.read_f32("emergency_urgency", 100.0f);
	AIBS_strategy_weights.gatehouseKnightFit = cfg.read_f32("gatehouse_knight_fit", 8.0f);
	AIBS_strategy_weights.otherArcherFit = cfg.read_f32("other_archer_fit", 5.0f);
	AIBS_strategy_weights.localPressureFit = cfg.read_f32("local_pressure_fit", 4.0f);
	AIBS_strategy_weights.continuityMax = cfg.read_f32("continuity_max", 24.0f);
	AIBS_strategy_weights.continuityDistance = cfg.read_f32("continuity_distance", 0.75f);
	AIBS_strategy_weights.templateCooldownTicks = u32(cfg.read_s32("template_cooldown_ticks", 900));
	AIBS_strategy_weights.templateCooldownPenalty = cfg.read_f32("template_cooldown_penalty", 20.0f);
	AIBS_strategy_weights.woodCost = cfg.read_f32("wood_cost", 0.08f);
	AIBS_strategy_weights.stoneCost = cfg.read_f32("stone_cost", 0.06f);
	AIBS_strategy_weights.woodShortage = cfg.read_f32("wood_shortage", 0.16f);
	AIBS_strategy_weights.stoneShortage = cfg.read_f32("stone_shortage", 0.12f);
	AIBS_strategy_weights.travel = cfg.read_f32("travel", 0.04f);
	AIBS_strategy_weights.taskBuildTime = cfg.read_f32("task_build_time", 1.2f);
	AIBS_strategy_weights.exposureFreeDistance = cfg.read_f32("exposure_free_distance", 160.0f);
	AIBS_strategy_weights.exposureDistance = cfg.read_f32("exposure_distance", 0.08f);
	AIBS_strategy_weights.exposurePressure = cfg.read_f32("exposure_pressure", 2.0f);
	AIBS_strategy_weights.friendlyRoutePenalty = cfg.read_f32("friendly_route_penalty", 60.0f);
	AIBS_strategy_weights.nearBestFraction = cfg.read_f32("near_best_fraction", 0.07f);
	return @AIBS_strategy_weights;
}
