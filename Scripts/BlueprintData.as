#include "BlueprintCatalog.as";
#include "AIBStrategicTypes.as";
#include "AIBStrategyEventLog.as";

const u32 AIBP_RESERVATION_TICKS = 150;

void AIBP_NewEmptyGrid(array<u16> &out grid)
{
	CMap@ map = getMap();
	grid.clear();
	if (map is null) return;
	grid.set_length(map.tilemapwidth * map.tilemapheight);
	for (uint i = 0; i < grid.length; i++) grid[i] = 0;
}

bool AIBP_GetLayerGrid(const u8 team, const u8 layer, array<u16>@ &out grid)
{
	CRules@ rules = getRules();
	CMap@ map = getMap();
	if (rules is null || map is null)
	{
		@grid = null;
		return false;
	}

	const uint expected = map.tilemapwidth * map.tilemapheight;
	if (!rules.get(AIBP_LayerDataKey(team, layer), @grid) || grid is null || grid.length != expected)
	{
		array<u16> fresh;
		AIBP_NewEmptyGrid(fresh);
		rules.set(AIBP_LayerDataKey(team, layer), fresh);
		rules.set_u16(AIBP_LayerWidthKey(team, layer), map.tilemapwidth);
		rules.set_u16(AIBP_LayerHeightKey(team, layer), map.tilemapheight);
		rules.get(AIBP_LayerDataKey(team, layer), @grid);
	}
	return grid !is null;
}

bool AIBP_GetCompatibilityGrid(const u8 team, array<u16>@ &out grid)
{
	CRules@ rules = getRules();
	CMap@ map = getMap();
	if (rules is null || map is null)
	{
		@grid = null;
		return false;
	}

	if (!rules.get(AIBP_CompatDataKey(team), @grid) || grid is null ||
		grid.length != uint(map.tilemapwidth * map.tilemapheight))
	{
		array<u16> fresh;
		AIBP_NewEmptyGrid(fresh);
		rules.set(AIBP_CompatDataKey(team), fresh);
		rules.set_u16(AIBP_CompatWidthKey(team), map.tilemapwidth);
		rules.set_u16(AIBP_CompatHeightKey(team), map.tilemapheight);
		if (team == 0)
		{
			rules.set(AIBP_COMPAT_DATA, fresh);
			rules.set_u16(AIBP_COMPAT_WIDTH, map.tilemapwidth);
			rules.set_u16(AIBP_COMPAT_HEIGHT, map.tilemapheight);
		}
		rules.get(AIBP_CompatDataKey(team), @grid);
	}
	return grid !is null;
}

u16 AIBP_GridValue(array<u16>@ grid, const u16 width, const int x, const int y)
{
	if (grid is null || x < 0 || y < 0 || x >= width) return 0;
	const uint index = y * width + x;
	return index < grid.length ? grid[index] : 0;
}

void AIBP_NotifyDisplayTile(const u8 team, const u16 x, const u16 y)
{
	if (!isServer()) return;
	CRules@ rules = getRules();
	if (rules is null) return;
	CBitStream sync;
	sync.write_u8(team);
	sync.write_u16(x);
	sync.write_u16(y);
	sync.write_u16(AIBP_GetDisplayTile(team, x, y));
	sync.write_u16(rules.get_u16(AIBP_PlanKey(team, "human version")));
	rules.SendCommand(rules.getCommandID("syncBlueprintBlock"), sync);
}

u16 AIBP_GetDisplayTile(const u8 team, const u16 x, const u16 y)
{
	CMap@ map = getMap();
	if (map is null || x >= map.tilemapwidth || y >= map.tilemapheight) return 0;
	array<u16>@ human = null;
	array<u16>@ ai = null;
	AIBP_GetLayerGrid(team, AIBP_Layer::human, @human);
	CRules@ rules = getRules();
	const u8 mode = rules is null ? AIBP_StrategyMode::off : rules.get_u8(AIBP_ModeKey(team));
	AIBP_GetLayerGrid(team, mode == AIBP_StrategyMode::suggest ? AIBP_Layer::ai_desired : AIBP_Layer::ai_work, @ai);
	const uint index = y * map.tilemapwidth + x;
	if (human !is null && index < human.length && human[index] != 0) return human[index];
	return ai !is null && index < ai.length ? ai[index] : 0;
}

void AIBP_RebuildCompatibility(const u8 team, const bool notifySnapshot = false)
{
	if (!isServer()) return;
	CRules@ rules = getRules();
	CMap@ map = getMap();
	if (rules is null || map is null) return;

	array<u16>@ human = null;
	array<u16>@ ai = null;
	AIBP_GetLayerGrid(team, AIBP_Layer::human, @human);
	AIBP_GetLayerGrid(team, AIBP_Layer::ai_work, @ai);
	array<u16> merged;
	AIBP_NewEmptyGrid(merged);
	for (uint i = 0; i < merged.length; i++)
	{
		const u16 humanValue = human is null || i >= human.length ? 0 : human[i];
		const u16 aiValue = ai is null || i >= ai.length ? 0 : ai[i];
		merged[i] = humanValue != 0 ? humanValue : aiValue;
	}

	rules.set(AIBP_CompatDataKey(team), merged);
	rules.set_u16(AIBP_CompatWidthKey(team), map.tilemapwidth);
	rules.set_u16(AIBP_CompatHeightKey(team), map.tilemapheight);
	if (team == 0)
	{
		rules.set(AIBP_COMPAT_DATA, merged);
		rules.set_u16(AIBP_COMPAT_WIDTH, map.tilemapwidth);
		rules.set_u16(AIBP_COMPAT_HEIGHT, map.tilemapheight);
	}
	if (notifySnapshot) AIBP_SendDisplaySnapshot(0, team);
}

void AIBP_SendDisplaySnapshot(const u16 targetNetID, const u8 team)
{
	if (!isServer()) return;
	CMap@ map = getMap();
	CRules@ rules = getRules();
	if (map is null || rules is null) return;
	CBitStream snapshot;
	snapshot.write_u16(targetNetID);
	snapshot.write_u8(team);
	snapshot.write_u16(map.tilemapwidth);
	snapshot.write_u16(map.tilemapheight);
	snapshot.write_u16(rules.get_u16(AIBP_PlanKey(team, "human version")));
	array<u16>@ human = null;
	array<u16>@ ai = null;
	AIBP_GetLayerGrid(team, AIBP_Layer::human, @human);
	const u8 mode = rules.get_u8(AIBP_ModeKey(team));
	AIBP_GetLayerGrid(team, mode == AIBP_StrategyMode::suggest ? AIBP_Layer::ai_desired : AIBP_Layer::ai_work, @ai);
	const uint cells = uint(map.tilemapwidth) * uint(map.tilemapheight);
	for (uint index = 0; index < cells; index++)
	{
		const u16 humanValue = human is null || index >= human.length ? 0 : human[index];
		const u16 aiValue = ai is null || index >= ai.length ? 0 : ai[index];
		snapshot.write_u16(humanValue != 0 ? humanValue : aiValue);
	}
	rules.SendCommand(rules.getCommandID("giveAllBlocks"), snapshot);
}

bool AIBP_SetHumanTile(const u8 team, const u16 x, const u16 y, const u16 value, const u16 expectedVersion = 0xffff)
{
	if (!isServer()) return false;
	CMap@ map = getMap();
	CRules@ rules = getRules();
	if (map is null || rules is null || x >= map.tilemapwidth || y >= map.tilemapheight) return false;
	const string versionKey = AIBP_PlanKey(team, "human version");
	const u16 currentVersion = rules.get_u16(versionKey);
	if (expectedVersion != 0xffff && expectedVersion != currentVersion) return false;
	if (value != 0 && !AIBP_IsCatalogBlock(value)) return false;

	array<u16>@ human = null;
	if (!AIBP_GetLayerGrid(team, AIBP_Layer::human, @human) || human is null) return false;
	const uint index = y * map.tilemapwidth + x;
	if (index >= human.length) return false;
	human[index] = value;
	rules.set(AIBP_LayerDataKey(team, AIBP_Layer::human), human);
	rules.set_u16(versionKey, currentVersion + 1);
	rules.Sync(versionKey, true);
	AIBP_RebuildCompatibility(team, false);
	AIBP_NotifyDisplayTile(team, x, y);
	AIBS_Log("human_delta", team, "x=" + x + " y=" + y + " block=" + value + " version=" + (currentVersion + 1));
	return true;
}

bool AIBP_ApplyHumanPlacement(const u8 team, const u16 centerX, const u16 centerY,
	const u16 width, const u16 height, uint16[][] &source)
{
	if (!isServer() || !AIBP_IsPrefabSizeValid(width, height)) return false;
	CMap@ map = getMap();
	CRules@ rules = getRules();
	if (map is null || rules is null || source.size() < width) return false;
	for (uint x = 0; x < width; x++)
	{
		if (source[x].size() < height) return false;
		for (uint y = 0; y < height; y++)
		{
			const u16 value = source[x][y];
			if (value != 0 && !AIBP_IsCatalogBlock(value)) return false;
		}
	}
	const int startX = centerX - Maths::Ceil(float(width) / 2.0f);
	const int startY = centerY - Maths::Ceil(float(height) / 2.0f);
	array<u16>@ human = null;
	if (!AIBP_GetLayerGrid(team, AIBP_Layer::human, @human) || human is null) return false;
	bool changed = false;
	for (int y = 0; y < height; y++)
	{
		for (int x = 0; x < width; x++)
		{
			const int tx = startX + x;
			const int ty = startY + y;
			if (tx < 0 || ty < 0 || tx >= map.tilemapwidth || ty >= map.tilemapheight) continue;
			const u16 value = source[x][y];
			const uint index = ty * map.tilemapwidth + tx;
			if (index >= human.length || human[index] == value) continue;
			human[index] = value;
			changed = true;
		}
	}
	if (changed)
	{
		const string versionKey = AIBP_PlanKey(team, "human version");
		const u16 version = rules.get_u16(versionKey) + 1;
		rules.set(AIBP_LayerDataKey(team, AIBP_Layer::human), human);
		rules.set_u16(versionKey, version);
		rules.Sync(versionKey, true);
		AIBP_RebuildCompatibility(team, false);
		AIBP_SendDisplaySnapshot(0, team);
		AIBS_Log("human_prefab", team, "center=" + centerX + "," + centerY + " size=" + width + "x" + height + " version=" + version);
	}
	return changed;
}

void AIBP_SaveTasks(const u8 team, array<BlueprintTask@>@ tasks)
{
	CRules@ rules = getRules();
	if (rules is null || tasks is null) return;
	array<u16> xs, ys, blocks, reserved;
	array<u8> phases, states;
	array<u32> untils;
	u16 pending = 0; u16 completed = 0;
	for (uint i = 0; i < tasks.length; i++)
	{
		BlueprintTask@ task = tasks[i];
		if (task is null) continue;
		xs.push_back(task.x); ys.push_back(task.y); blocks.push_back(task.block);
		phases.push_back(task.phase); states.push_back(task.state);
		reserved.push_back(task.reservedBy); untils.push_back(task.reservedUntil);
		if (task.state == AIBP_TaskState::completed) completed++;
		else if (task.state != AIBP_TaskState::cancelled) pending++;
	}
	rules.set(AIBP_TaskKey(team, "x"), xs);
	rules.set(AIBP_TaskKey(team, "y"), ys);
	rules.set(AIBP_TaskKey(team, "block"), blocks);
	rules.set(AIBP_TaskKey(team, "phase"), phases);
	rules.set(AIBP_TaskKey(team, "state"), states);
	rules.set(AIBP_TaskKey(team, "reserved"), reserved);
	rules.set(AIBP_TaskKey(team, "until"), untils);
	rules.set_u16(AIBP_PlanKey(team, "pending"), pending);
	rules.set_u16(AIBP_PlanKey(team, "completed"), completed);
	rules.set_u16(AIBP_PlanKey(team, "damaged"), 0);
	rules.Sync(AIBP_PlanKey(team, "pending"), true);
	rules.Sync(AIBP_PlanKey(team, "completed"), true);
	rules.Sync(AIBP_PlanKey(team, "damaged"), true);
}

bool AIBP_LoadTaskArrays(const u8 team, array<u16>@ &out xs, array<u16>@ &out ys,
	array<u16>@ &out blocks, array<u8>@ &out phases, array<u8>@ &out states,
	array<u16>@ &out reserved, array<u32>@ &out untils)
{
	CRules@ rules = getRules();
	if (rules is null) return false;
	return rules.get(AIBP_TaskKey(team, "x"), @xs) && xs !is null &&
		rules.get(AIBP_TaskKey(team, "y"), @ys) && ys !is null &&
		rules.get(AIBP_TaskKey(team, "block"), @blocks) && blocks !is null &&
		rules.get(AIBP_TaskKey(team, "phase"), @phases) && phases !is null &&
		rules.get(AIBP_TaskKey(team, "state"), @states) && states !is null &&
		rules.get(AIBP_TaskKey(team, "reserved"), @reserved) && reserved !is null &&
		rules.get(AIBP_TaskKey(team, "until"), @untils) && untils !is null;
}

bool AIBP_PublishAIPlan(BlueprintPlan@ plan, const bool activate)
{
	if (!isServer() || plan is null) return false;
	CMap@ map = getMap();
	CRules@ rules = getRules();
	if (map is null || rules is null) return false;
	const u8 team = plan.team;
	const u16 currentVersion = rules.get_u16(AIBP_PlanKey(team, "version"));
	if (plan.version <= currentVersion) plan.version = currentVersion + 1;

	array<u16>@ human = null;
	AIBP_GetLayerGrid(team, AIBP_Layer::human, @human);
	array<u16> desired;
	array<u16> work;
	AIBP_NewEmptyGrid(desired);
	AIBP_NewEmptyGrid(work);
	for (uint i = 0; i < plan.tasks.length; i++)
	{
		BlueprintTask@ task = plan.tasks[i];
		if (task is null || task.x >= map.tilemapwidth || task.y >= map.tilemapheight || !AIBP_IsCatalogBlock(task.block)) return false;
		const uint index = task.y * map.tilemapwidth + task.x;
		if (human !is null && index < human.length && human[index] != 0) return false;
		if (desired[index] != 0) return false;
		desired[index] = task.block;
		if (activate && task.state != AIBP_TaskState::completed && task.state != AIBP_TaskState::cancelled) work[index] = task.block;
	}
	if (rules.get_u16(AIBP_PlanKey(team, "id")) != 0 && rules.get_u8(AIBP_PlanKey(team, "status")) == 1)
	{
		rules.set_u8(AIBP_PlanKey(team, "status"), 3);
		const string replacementReason = rules.get_string("aib strategy replacement reason team " + int(team));
		AIBP_ArchiveCurrentPlan(team, replacementReason == "" ? "strategically_replaced" : replacementReason);
		rules.set_string("aib strategy replacement reason team " + int(team), "");
	}

	rules.set(AIBP_LayerDataKey(team, AIBP_Layer::ai_desired), desired);
	rules.set(AIBP_LayerDataKey(team, AIBP_Layer::ai_work), work);
	rules.set_u16(AIBP_LayerWidthKey(team, AIBP_Layer::ai_desired), map.tilemapwidth);
	rules.set_u16(AIBP_LayerHeightKey(team, AIBP_Layer::ai_desired), map.tilemapheight);
	rules.set_u16(AIBP_LayerWidthKey(team, AIBP_Layer::ai_work), map.tilemapwidth);
	rules.set_u16(AIBP_LayerHeightKey(team, AIBP_Layer::ai_work), map.tilemapheight);
	rules.set_u16(AIBP_PlanKey(team, "id"), plan.id);
	rules.set_u16(AIBP_PlanKey(team, "version"), plan.version);
	rules.set_u8(AIBP_PlanKey(team, "owner"), plan.owner);
	rules.set_u8(AIBP_PlanKey(team, "intent"), plan.intent);
	rules.set_u8(AIBP_PlanKey(team, "status"), plan.status);
	rules.set_string(AIBP_PlanKey(team, "template"), plan.templateName);
	rules.set_Vec2f(AIBP_PlanKey(team, "anchor"), plan.anchor);
	rules.set_f32(AIBP_PlanKey(team, "score"), plan.score);
	rules.set_string(AIBP_PlanKey(team, "reasons"), plan.reasons);
	rules.set_u32(AIBP_PlanKey(team, "created"), plan.createdAt);
	rules.set_u32(AIBP_PlanKey(team, "updated"), getGameTime());
	rules.set_u32("aib strategy template last " + plan.templateName + " team " + int(team), getGameTime());
	rules.Sync(AIBP_PlanKey(team, "id"), true);
	rules.Sync(AIBP_PlanKey(team, "version"), true);
	rules.Sync(AIBP_PlanKey(team, "owner"), true);
	rules.Sync(AIBP_PlanKey(team, "intent"), true);
	rules.Sync(AIBP_PlanKey(team, "status"), true);
	rules.Sync(AIBP_PlanKey(team, "template"), true);
	rules.Sync(AIBP_PlanKey(team, "anchor"), true);
	rules.Sync(AIBP_PlanKey(team, "score"), true);
	rules.Sync(AIBP_PlanKey(team, "reasons"), true);
	AIBP_SaveTasks(team, @plan.tasks);
	AIBP_RebuildCompatibility(team, false);
	AIBP_SendDisplaySnapshot(0, team);
	AIBS_Log("publish", team, "plan=" + plan.id + " version=" + plan.version + " template=" + plan.templateName + " tasks=" + plan.tasks.length + " active=" + activate);
	return true;
}

void AIBP_SetAIWorkEnabled(const u8 team, const bool enabled)
{
	if (!isServer()) return;
	CMap@ map = getMap();
	if (map is null) return;
	array<u16>@ desired = null;
	AIBP_GetLayerGrid(team, AIBP_Layer::ai_desired, @desired);
	array<u16> work;
	AIBP_NewEmptyGrid(work);
	if (enabled && desired !is null)
	{
		array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
		array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
		const bool hasTasks = AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils);
		for (uint i = 0; i < desired.length && i < work.length; i++) work[i] = desired[i];
		if (hasTasks)
		{
			for (uint i = 0; i < xs.length && i < ys.length && i < states.length; i++)
			{
				if (states[i] != AIBP_TaskState::completed && states[i] != AIBP_TaskState::cancelled) continue;
				const uint index = ys[i] * map.tilemapwidth + xs[i];
				if (index < work.length) work[index] = 0;
			}
		}
	}
	getRules().set(AIBP_LayerDataKey(team, AIBP_Layer::ai_work), work);
	AIBP_RebuildCompatibility(team, false);
	AIBP_SendDisplaySnapshot(0, team);
}

u8 AIBP_CurrentTaskPhase(const u8 team)
{
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils)) return AIBP_Phase::shell;
	u8 result = AIBP_Phase::shell;
	bool found = false;
	for (uint i = 0; i < states.length && i < phases.length; i++)
	{
		if (states[i] == AIBP_TaskState::completed || states[i] == AIBP_TaskState::cancelled) continue;
		if (!found || phases[i] < result) { result = phases[i]; found = true; }
	}
	return result;
}

string AIBP_LooseReservationKey(const u8 team, const u16 x, const u16 y, const string &in field)
{
	return "aib blueprint loose reservation " + field + " team " + int(team) + " x " + x + " y " + y;
}

string AIBP_BuilderLooseReservationKey(const u8 team, const u16 builderNetID, const string &in field)
{
	return "aib blueprint builder loose reservation " + field + " team " + int(team) + " builder " + builderNetID;
}

void AIBP_ReleaseLooseBuilderReservation(const u8 team, const u16 builderNetID)
{
	CRules@ rules = getRules();
	if (rules is null || !rules.get_bool(AIBP_BuilderLooseReservationKey(team, builderNetID, "active"))) return;
	const u16 x = rules.get_u16(AIBP_BuilderLooseReservationKey(team, builderNetID, "x"));
	const u16 y = rules.get_u16(AIBP_BuilderLooseReservationKey(team, builderNetID, "y"));
	const string ownerKey = AIBP_LooseReservationKey(team, x, y, "owner");
	if (rules.get_netid(ownerKey) == builderNetID) rules.set_netid(ownerKey, 0);
	rules.set_u32(AIBP_LooseReservationKey(team, x, y, "until"), 0);
	rules.set_bool(AIBP_BuilderLooseReservationKey(team, builderNetID, "active"), false);
}

bool AIBP_LooseTaskAvailable(const u8 team, const u16 x, const u16 y, const u16 builderNetID)
{
	CRules@ rules = getRules();
	if (rules is null) return false;
	const u16 owner = rules.get_netid(AIBP_LooseReservationKey(team, x, y, "owner"));
	const u32 until = rules.get_u32(AIBP_LooseReservationKey(team, x, y, "until"));
	return owner == 0 || owner == builderNetID || until <= getGameTime();
}

bool AIBP_ReserveLooseTask(const u8 team, const u16 x, const u16 y, const u16 builderNetID)
{
	if (!AIBP_LooseTaskAvailable(team, x, y, builderNetID))
	{
		CRules@ rules = getRules();
		if (rules !is null && rules.get_bool("aib wave running") && rules.get_u8("aib wave team") == team)
			rules.set_u16("aib wave reservation conflicts", rules.get_u16("aib wave reservation conflicts") + 1);
		return false;
	}
	CRules@ rules = getRules();
	if (rules is null) return false;
	AIBP_ReleaseLooseBuilderReservation(team, builderNetID);
	rules.set_netid(AIBP_LooseReservationKey(team, x, y, "owner"), builderNetID);
	rules.set_u32(AIBP_LooseReservationKey(team, x, y, "until"), getGameTime() + AIBP_RESERVATION_TICKS);
	rules.set_u16(AIBP_BuilderLooseReservationKey(team, builderNetID, "x"), x);
	rules.set_u16(AIBP_BuilderLooseReservationKey(team, builderNetID, "y"), y);
	rules.set_bool(AIBP_BuilderLooseReservationKey(team, builderNetID, "active"), true);
	return true;
}

void AIBP_ClearLooseReservationAt(const u8 team, const u16 x, const u16 y)
{
	CRules@ rules = getRules();
	if (rules is null) return;
	rules.set_netid(AIBP_LooseReservationKey(team, x, y, "owner"), 0);
	rules.set_u32(AIBP_LooseReservationKey(team, x, y, "until"), 0);
}

bool AIBP_ReserveTask(const u8 team, const u16 x, const u16 y, const u16 builderNetID)
{
	if (!isServer() || builderNetID == 0) return false;
	if (AIBP_IsHumanTile(team, x, y)) return AIBP_ReserveLooseTask(team, x, y, builderNetID);
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils)) return AIBP_ReserveLooseTask(team, x, y, builderNetID);
	const u8 activePhase = AIBP_CurrentTaskPhase(team);
	const u32 now = getGameTime();
	for (uint i = 0; i < xs.length && i < ys.length && i < states.length && i < phases.length && i < reserved.length && i < untils.length; i++)
	{
		if (xs[i] != x || ys[i] != y || phases[i] != activePhase) continue;
		if (states[i] == AIBP_TaskState::completed || states[i] == AIBP_TaskState::cancelled) return false;
		if (reserved[i] != 0 && reserved[i] != builderNetID && untils[i] > now)
		{
			CRules@ rules = getRules();
			if (rules !is null && rules.get_bool("aib wave running") && rules.get_u8("aib wave team") == team)
				rules.set_u16("aib wave reservation conflicts", rules.get_u16("aib wave reservation conflicts") + 1);
			return false;
		}
		AIBP_ReleaseLooseBuilderReservation(team, builderNetID);
		reserved[i] = builderNetID; untils[i] = now + AIBP_RESERVATION_TICKS; states[i] = AIBP_TaskState::reserved;
		getRules().set(AIBP_TaskKey(team, "reserved"), reserved);
		getRules().set(AIBP_TaskKey(team, "until"), untils);
		getRules().set(AIBP_TaskKey(team, "state"), states);
		AIBS_Log("reserve", team, "plan=" + getRules().get_u16(AIBP_PlanKey(team, "id")) + " x=" + x + " y=" + y + " builder=" + builderNetID + " phase=" + activePhase);
		return true;
	}
	return AIBP_ReserveLooseTask(team, x, y, builderNetID); // Generated support tiles are not explicit strategic tasks.
}

bool AIBP_IsHumanTile(const u8 team, const u16 x, const u16 y)
{
	CMap@ map = getMap();
	if (map is null || x >= map.tilemapwidth || y >= map.tilemapheight) return false;
	array<u16>@ human = null;
	if (!AIBP_GetLayerGrid(team, AIBP_Layer::human, @human) || human is null) return false;
	const uint index = y * map.tilemapwidth + x;
	return index < human.length && human[index] != 0;
}

bool AIBP_TaskAvailableForBuilder(const u8 team, const u16 x, const u16 y, const u16 builderNetID)
{
	if (AIBP_IsHumanTile(team, x, y)) return AIBP_LooseTaskAvailable(team, x, y, builderNetID);
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils)) return AIBP_LooseTaskAvailable(team, x, y, builderNetID);
	const u8 activePhase = AIBP_CurrentTaskPhase(team);
	const u32 now = getGameTime();
	for (uint i = 0; i < xs.length && i < ys.length && i < phases.length && i < states.length && i < reserved.length && i < untils.length; i++)
	{
		if (xs[i] != x || ys[i] != y) continue;
		if (phases[i] != activePhase || states[i] == AIBP_TaskState::completed || states[i] == AIBP_TaskState::cancelled) return false;
		return reserved[i] == 0 || reserved[i] == builderNetID || untils[i] <= now;
	}
	return AIBP_LooseTaskAvailable(team, x, y, builderNetID);
}

bool AIBP_TaskReservedBy(const u8 team, const u16 x, const u16 y, const u16 builderNetID)
{
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils))
		return getRules().get_netid(AIBP_LooseReservationKey(team, x, y, "owner")) == builderNetID &&
			getRules().get_u32(AIBP_LooseReservationKey(team, x, y, "until")) >= getGameTime();
	for (uint i = 0; i < xs.length && i < ys.length && i < reserved.length && i < untils.length; i++)
	{
		if (xs[i] == x && ys[i] == y) return reserved[i] == builderNetID && untils[i] >= getGameTime();
	}
	return getRules().get_netid(AIBP_LooseReservationKey(team, x, y, "owner")) == builderNetID &&
		getRules().get_u32(AIBP_LooseReservationKey(team, x, y, "until")) >= getGameTime();
}

void AIBP_ReleaseBuilderReservation(const u8 team, const u16 builderNetID)
{
	AIBP_ReleaseLooseBuilderReservation(team, builderNetID);
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils)) return;
	bool changed = false;
	for (uint i = 0; i < reserved.length && i < states.length && i < untils.length; i++)
	{
		if (reserved[i] != builderNetID) continue;
		reserved[i] = 0; untils[i] = 0;
		if (states[i] == AIBP_TaskState::reserved) states[i] = AIBP_TaskState::pending;
		changed = true;
	}
	if (changed)
	{
		getRules().set(AIBP_TaskKey(team, "reserved"), reserved);
		getRules().set(AIBP_TaskKey(team, "until"), untils);
		getRules().set(AIBP_TaskKey(team, "state"), states);
	}
}

void AIBP_CompleteTaskAt(const u8 team, const u16 x, const u16 y)
{
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils)) return;
	for (uint i = 0; i < xs.length && i < ys.length && i < states.length && i < reserved.length && i < untils.length; i++)
	{
		if (xs[i] != x || ys[i] != y) continue;
		states[i] = AIBP_TaskState::completed; reserved[i] = 0; untils[i] = 0;
		getRules().set(AIBP_TaskKey(team, "state"), states);
		getRules().set(AIBP_TaskKey(team, "reserved"), reserved);
		getRules().set(AIBP_TaskKey(team, "until"), untils);
		getRules().set_u32(AIBP_PlanKey(team, "updated"), getGameTime());
		bool allDone = true;
		for (uint j = 0; j < states.length; j++)
		{
			if (states[j] != AIBP_TaskState::completed && states[j] != AIBP_TaskState::cancelled) { allDone = false; break; }
		}
		if (allDone)
		{
			getRules().set_u8(AIBP_PlanKey(team, "status"), 2);
			getRules().Sync(AIBP_PlanKey(team, "status"), true);
			AIBP_ArchiveCurrentPlan(team, "completed");
		}
		AIBS_Log("complete", team, "plan=" + getRules().get_u16(AIBP_PlanKey(team, "id")) + " x=" + x + " y=" + y);
		return;
	}
}

void AIBP_ArchiveCurrentPlan(const u8 team, const string &in reason)
{
	CRules@ rules = getRules();
	if (rules is null) return;
	const u16 planID = rules.get_u16(AIBP_PlanKey(team, "id"));
	if (planID == 0) return;
	const string prefix = "aib strategy history plan " + planID + " team " + int(team) + " ";
	array<u16>@ desired = null;
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	AIBP_GetLayerGrid(team, AIBP_Layer::ai_desired, @desired);
	AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils);
	if (desired !is null) rules.set(prefix + "desired", desired);
	if (xs !is null) rules.set(prefix + "x", xs);
	if (ys !is null) rules.set(prefix + "y", ys);
	if (blocks !is null) rules.set(prefix + "block", blocks);
	if (phases !is null) rules.set(prefix + "phase", phases);
	if (states !is null) rules.set(prefix + "state", states);
	rules.set_string(prefix + "template", rules.get_string(AIBP_PlanKey(team, "template")));
	rules.set_string(prefix + "reasons", rules.get_string(AIBP_PlanKey(team, "reasons")));
	rules.set_string(prefix + "archive reason", reason);
	rules.set_u8(prefix + "status", rules.get_u8(AIBP_PlanKey(team, "status")));
	rules.set_u32(prefix + "created", rules.get_u32(AIBP_PlanKey(team, "created")));
	rules.set_u32(prefix + "archived", getGameTime());
	if (rules.get_bool("aib wave running") && rules.get_u8("aib wave team") == team && reason != "completed")
		rules.set_u16("aib wave replans", rules.get_u16("aib wave replans") + 1);
	array<u16>@ history = null;
	if (!rules.get("aib strategy history ids team " + int(team), @history) || history is null)
	{
		array<u16> fresh;
		rules.set("aib strategy history ids team " + int(team), fresh);
		rules.get("aib strategy history ids team " + int(team), @history);
	}
	if (history !is null)
	{
		bool found = false;
		for (uint i = 0; i < history.length; i++) if (history[i] == planID) { found = true; break; }
		if (!found) { history.push_back(planID); rules.set("aib strategy history ids team " + int(team), history); }
	}
	AIBS_Log("archive", team, "plan=" + planID + " reason=" + reason);
}

void AIBP_ClearConsumableTile(const u8 team, const u16 x, const u16 y)
{
	if (!isServer()) return;
	CMap@ map = getMap();
	if (map is null || x >= map.tilemapwidth || y >= map.tilemapheight) return;
	array<u16>@ human = null;
	array<u16>@ ai = null;
	AIBP_GetLayerGrid(team, AIBP_Layer::human, @human);
	AIBP_GetLayerGrid(team, AIBP_Layer::ai_work, @ai);
	const uint index = y * map.tilemapwidth + x;
	AIBP_ClearLooseReservationAt(team, x, y);
	if (human !is null && index < human.length && human[index] != 0)
	{
		human[index] = 0;
		getRules().set(AIBP_LayerDataKey(team, AIBP_Layer::human), human);
	}
	else if (ai !is null && index < ai.length)
	{
		ai[index] = 0;
		getRules().set(AIBP_LayerDataKey(team, AIBP_Layer::ai_work), ai);
		AIBP_CompleteTaskAt(team, x, y);
	}
	AIBP_RebuildCompatibility(team, false);
	AIBP_NotifyDisplayTile(team, x, y);
}

bool AIBP_MapMatchesBlock(const u16 x, const u16 y, const u16 block)
{
	CMap@ map = getMap();
	if (map is null || x >= map.tilemapwidth || y >= map.tilemapheight) return false;
	const Vec2f center = Vec2f(x * map.tilesize + map.tilesize * 0.5f, y * map.tilesize + map.tilesize * 0.5f);
	if (!AIBP_IsBlobBlock(block)) return map.getTile(center).type == AIBP_BlockTileType(block);
	CBlob@[] nearby;
	if (!map.getBlobsInRadius(center, 6.0f, @nearby)) return false;
	const string expected = AIBP_BlockBlobName(block);
	const u8 rotation = AIBP_BlockRotation(block);
	for (uint i = 0; i < nearby.length; i++)
	{
		CBlob@ placed = nearby[i];
		if (placed is null || placed.hasTag("dead") || placed.getName() != expected) continue;
		if (!AIBP_BlobAnchoredAtTile(placed, x, y)) continue;
		const u8 actual = AIBP_NormalizeRotationForId(AIBP_BlockId(block),
			u8((Maths::Round(placed.getAngleDegrees() / 90.0f) + 4) % 4));
		if (actual == rotation) return true;
	}
	return false;
}

bool AIBP_BlobAnchoredAtTile(CBlob@ blob, const u16 x, const u16 y)
{
	CMap@ map = getMap();
	if (blob is null || map is null) return false;

	const Vec2f anchor = map.getTileSpacePosition(blob.getPosition());
	return Maths::Floor(anchor.x) == x && Maths::Floor(anchor.y) == y;
}

void AIBP_RefreshPlanState(const u8 team, const bool reactivateDamaged)
{
	if (!isServer()) return;
	CRules@ rules = getRules();
	CMap@ map = getMap();
	if (rules is null || map is null || rules.get_u16(AIBP_PlanKey(team, "id")) == 0) return;
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils)) return;
	array<u16>@ work = null;
	AIBP_GetLayerGrid(team, AIBP_Layer::ai_work, @work);
	u16 pending = 0; u16 completed = 0; u16 damaged = 0;
	bool changed = false; bool workChanged = false;
	for (uint i = 0; i < xs.length && i < ys.length && i < blocks.length && i < states.length; i++)
	{
		const bool matches = AIBP_MapMatchesBlock(xs[i], ys[i], blocks[i]);
		const uint index = ys[i] * map.tilemapwidth + xs[i];
		if (states[i] == AIBP_TaskState::completed && !matches)
		{
			damaged++;
			if (reactivateDamaged)
			{
				if (rules.get_bool("aib wave running") && rules.get_u8("aib wave team") == team)
				{
					rules.set_u16("aib wave damage events", rules.get_u16("aib wave damage events") + 1);
					rules.set_u32("aib wave damage cost", rules.get_u32("aib wave damage cost") + AIBP_BlockCost(blocks[i]));
					if (rules.get_u32("aib wave first damage tick") == 0)
						rules.set_u32("aib wave first damage tick", getGameTime() - rules.get_u32("aib wave start tick"));
				}
				states[i] = AIBP_TaskState::pending;
				if (i < reserved.length) reserved[i] = 0;
				if (i < untils.length) untils[i] = 0;
				if (work !is null && index < work.length) { work[index] = blocks[i]; workChanged = true; }
				changed = true;
				pending++;
				AIBS_Log("damage", team, "plan=" + rules.get_u16(AIBP_PlanKey(team, "id")) + " x=" + xs[i] + " y=" + ys[i]);
			}
			else completed++;
		}
		else if (states[i] == AIBP_TaskState::completed) completed++;
		else if (states[i] != AIBP_TaskState::cancelled && matches)
		{
			states[i] = AIBP_TaskState::completed;
			if (i < reserved.length) reserved[i] = 0;
			if (i < untils.length) untils[i] = 0;
			if (work !is null && index < work.length) { work[index] = 0; workChanged = true; }
			changed = true;
			completed++;
		}
		else if (states[i] != AIBP_TaskState::cancelled) pending++;
	}
	rules.set_u16(AIBP_PlanKey(team, "pending"), pending);
	rules.set_u16(AIBP_PlanKey(team, "completed"), completed);
	rules.set_u16(AIBP_PlanKey(team, "damaged"), damaged);
	rules.Sync(AIBP_PlanKey(team, "pending"), true);
	rules.Sync(AIBP_PlanKey(team, "completed"), true);
	rules.Sync(AIBP_PlanKey(team, "damaged"), true);
	if (changed)
	{
		rules.set(AIBP_TaskKey(team, "state"), states);
		rules.set(AIBP_TaskKey(team, "reserved"), reserved);
		rules.set(AIBP_TaskKey(team, "until"), untils);
		const u8 oldStatus = rules.get_u8(AIBP_PlanKey(team, "status"));
		const u8 newStatus = pending == 0 ? 2 : 1;
		rules.set_u8(AIBP_PlanKey(team, "status"), newStatus);
		rules.set_u32(AIBP_PlanKey(team, "updated"), getGameTime());
		rules.Sync(AIBP_PlanKey(team, "status"), true);
		if (newStatus == 2 && oldStatus != 2) AIBP_ArchiveCurrentPlan(team, "completed");
	}
	if (workChanged)
	{
		rules.set(AIBP_LayerDataKey(team, AIBP_Layer::ai_work), work);
		AIBP_RebuildCompatibility(team, false);
		AIBP_SendDisplaySnapshot(0, team);
	}
}

u16 AIBP_RemainingMaterialCost(const u8 team, const string &in material)
{
	array<u16>@ grid = null;
	if (!AIBP_GetCompatibilityGrid(team, @grid) || grid is null) return 0;
	u32 total = 0;
	for (uint i = 0; i < grid.length; i++)
	{
		if (AIBP_BlockMaterial(grid[i]) == material) total += AIBP_BlockCost(grid[i]);
	}
	return u16(Maths::Min(total, 65535));
}

u16 AIBP_MinRemainingBlockCost(const u8 team, const string &in material)
{
	array<u16>@ grid = null;
	if (!AIBP_GetCompatibilityGrid(team, @grid) || grid is null) return 0;
	u16 result = 0;
	for (uint i = 0; i < grid.length; i++)
	{
		if (AIBP_BlockMaterial(grid[i]) != material) continue;
		const u16 cost = AIBP_BlockCost(grid[i]);
		if (cost > 0 && (result == 0 || cost < result)) result = cost;
	}
	return result;
}
