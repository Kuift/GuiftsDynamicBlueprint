#define SERVER_ONLY

#include "AIBStrategyEventLog.as";
#include "AIBPlacementPlanner.as";

u32 AIBW_DesiredPlanCost(const u8 team)
{
	array<u16>@ desired = null;
	if (!AIBP_GetLayerGrid(team, AIBP_Layer::ai_desired, @desired) || desired is null) return 0;
	u32 total = 0;
	for (uint i = 0; i < desired.length; i++) total += AIBP_BlockCost(desired[i]);
	return total;
}

AIBPlanCandidate@ AIBW_CurrentCandidate(const u8 team)
{
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(team, @xs, @ys, @blocks, @phases, @states, @reserved, @untils)) return null;
	AIBPlanCandidate@ candidate = AIBPlanCandidate();
	candidate.intent = getRules().get_u8(AIBP_PlanKey(team, "intent"));
	candidate.anchor = getRules().get_Vec2f(AIBP_PlanKey(team, "anchor"));
	for (uint i = 0; i < xs.length && i < ys.length && i < blocks.length && i < phases.length; i++)
		candidate.tasks.push_back(BlueprintTask(xs[i], ys[i], blocks[i], phases[i]));
	return candidate;
}

void onInit(CRules@ this)
{
	this.set_bool("aib wave running", false);
	this.set_bool("aib wave enabled", false);
}

void onRestart(CRules@ this)
{
	this.set_bool("aib wave running", false);
	this.set_bool("aib wave enabled", false);
	this.set_bool("aib strategy event log enabled", false);
}

void AIBW_Start(CRules@ rules)
{
	const u8 team = rules.get_u8("aib wave team");
	rules.set_bool("aib wave running", true);
	rules.set_u32("aib wave start tick", getGameTime());
	rules.set_u8("aib wave spawned", 0);
	rules.set_u8("aib wave crossings", 0);
	rules.set_u8("aib wave deaths", 0);
	rules.set_u8("aib wave builder deaths", 0);
	rules.set_u8("aib wave flag approaches", 0);
	rules.set_u16("aib wave reservation conflicts", 0);
	rules.set_u16("aib wave replans", 0);
	rules.set_u16("aib wave damage events", 0);
	rules.set_u32("aib wave damage cost", 0);
	rules.set_u32("aib wave first breach", 0);
	rules.set_u32("aib wave completion tick", 0);
	rules.set_u32("aib wave first damage tick", 0);
	rules.set_f32("aib wave builder travel", 0.0f);
	rules.set_u32("aib wave builder idle", 0);
	rules.set_u32("aib wave plan cost", AIBW_DesiredPlanCost(team));
	rules.set_u16("aib wave completed start", rules.get_u16(AIBP_PlanKey(team, "completed")));
	rules.set_u16("aib wave damaged start", rules.get_u16(AIBP_PlanKey(team, "damaged")));
	AIBPlanCandidate@ candidate = AIBW_CurrentCandidate(team);
	const f32 routePenalty = candidate is null ? 0.0f : AIBS_FriendlyRoutePenalty(candidate);
	rules.set_f32("aib wave friendly route penalty", routePenalty);
	rules.set_bool("aib wave route preserved", routePenalty < 1.0f);
	rules.set_u16("aib wave plan tasks", candidate is null ? 0 : candidate.tasks.length);
	if (candidate !is null && candidate.tasks.length > 0 && rules.get_u16(AIBP_PlanKey(team, "pending")) == 0)
		rules.set_u32("aib wave completion tick", 1); // Plan was already complete when the measured wave began.
	AIBS_Log("wave_start", team, "seed=" + rules.get_u32("aib wave seed") + " variant=" + rules.get_string("aib wave variant") +
		" scenario=" + rules.get_string("aib wave scenario") + " pending=" + rules.get_u16(AIBP_PlanKey(team, "pending")) +
		" completed=" + rules.get_u16(AIBP_PlanKey(team, "completed")) + " cost=" + rules.get_u32("aib wave plan cost") +
		" route_preserved=" + rules.get_bool("aib wave route preserved"));
}

void AIBW_SpawnUnit(CRules@ rules)
{
	const u8 team = rules.get_u8("aib wave team");
	const u8 enemyTeam = team == 0 ? 1 : 0;
	const u8 index = rules.get_u8("aib wave spawned");
	const u32 seed = rules.get_u32("aib wave seed");
	AIBWorldState@ world = AIBS_ObserveWorld(team);
	if (world is null || world.home == Vec2f_zero) return;
	Vec2f spawn = world.enemyHome;
	if (spawn == Vec2f_zero)
	{
		CMap@ map = getMap();
		spawn = Vec2f(world.enemyDirection > 0 ? map.tilemapwidth * map.tilesize - 24 : 24, world.home.y);
	}
	const string scenario = rules.get_string("aib wave scenario");
	const bool archer = scenario == "archer" || (scenario == "mixed" && ((seed + index * 17) % 4) == 0);
	CBlob@ unit = server_CreateBlob(archer ? "archer" : "knight", enemyTeam, spawn + Vec2f(0, -(index % 3) * 4));
	if (unit !is null)
	{
		unit.Tag("aib strategy wave unit");
		unit.set_u8("aib wave target team", team);
		unit.set_u8("aib wave spawn index", index);
	}
	rules.set_u8("aib wave spawned", index + 1);
}

void AIBW_ThrowBomb(CBlob@ unit, CBlob@ home)
{
	if (unit is null || home is null || unit.hasTag("aib wave bomb thrown")) return;
	if ((home.getPosition() - unit.getPosition()).Length() > 176.0f) return;
	unit.Tag("aib wave bomb thrown");
	const f32 direction = home.getPosition().x >= unit.getPosition().x ? 1.0f : -1.0f;
	CBlob@ bomb = server_CreateBlob("bomb", unit.getTeamNum(), unit.getPosition() + Vec2f(direction * 8.0f, -4.0f));
	if (bomb !is null)
	{
		bomb.set_u16("explosive_parent", unit.getNetworkID());
		bomb.setVelocity(Vec2f(direction * 6.5f, -2.0f));
		bomb.Tag("aib strategy wave bomb");
	}
}

void AIBW_DriveUnits(CRules@ rules)
{
	const u8 team = rules.get_u8("aib wave team");
	CBlob@ home = AIBS_TeamHomeBlob(team);
	if (home is null) return;
	CBlob@[] units;
	getBlobsByTag("aib strategy wave unit", @units);
	for (uint i = 0; i < units.length; i++)
	{
		CBlob@ unit = units[i];
		if (unit is null || unit.hasTag("dead")) continue;
		const f32 direction = home.getPosition().x >= unit.getPosition().x ? 1.0f : -1.0f;
		unit.setKeyPressed(direction > 0 ? key_right : key_left, true);
		unit.setKeyPressed(key_action1, true);
		unit.setAimPos(home.getPosition());
		unit.setVelocity(Vec2f(direction * Maths::Max(1.5f, Maths::Abs(unit.getVelocity().x)), unit.getVelocity().y));
		const string scenario = rules.get_string("aib wave scenario");
		if (scenario == "bomb" || (scenario == "mixed" && (unit.get_u8("aib wave spawn index") + rules.get_u32("aib wave seed")) % 3 == 0)) AIBW_ThrowBomb(unit, home);
		if (!unit.hasTag("aib wave approached flag") && (unit.getPosition() - home.getPosition()).Length() <= 80.0f)
		{
			unit.Tag("aib wave approached flag");
			rules.set_u8("aib wave flag approaches", rules.get_u8("aib wave flag approaches") + 1);
		}
		if (!unit.hasTag("aib wave crossed") && Maths::Abs(unit.getPosition().x - home.getPosition().x) <= 16.0f)
		{
			unit.Tag("aib wave crossed");
			rules.set_u8("aib wave crossings", rules.get_u8("aib wave crossings") + 1);
			if (rules.get_u32("aib wave first breach") == 0) rules.set_u32("aib wave first breach", getGameTime() - rules.get_u32("aib wave start tick"));
		}
	}
}

void AIBW_SampleBuilders(CRules@ rules)
{
	const u8 team = rules.get_u8("aib wave team");
	CBlob@[] builders;
	getBlobsByName("aibuilder", @builders);
	for (uint i = 0; i < builders.length; i++)
	{
		CBlob@ builder = builders[i];
		if (builder is null || builder.hasTag("dead") || builder.getTeamNum() != team) continue;
		const string key = "aib wave builder last " + builder.getNetworkID();
		Vec2f last = rules.get_Vec2f(key);
		if (last != Vec2f_zero) rules.set_f32("aib wave builder travel", rules.get_f32("aib wave builder travel") + (builder.getPosition() - last).Length());
		rules.set_Vec2f(key, builder.getPosition());
		if (builder.get_u8("ai builder state") == 0) rules.set_u32("aib wave builder idle", rules.get_u32("aib wave builder idle") + 1);
	}
	const u32 elapsed = getGameTime() - rules.get_u32("aib wave start tick");
	if (rules.get_u16("aib wave plan tasks") > 0 && rules.get_u32("aib wave completion tick") == 0 && rules.get_u16(AIBP_PlanKey(team, "pending")) == 0)
		rules.set_u32("aib wave completion tick", elapsed);
	if (rules.get_u32("aib wave first damage tick") == 0 && rules.get_u16(AIBP_PlanKey(team, "damaged")) > rules.get_u16("aib wave damaged start"))
		rules.set_u32("aib wave first damage tick", elapsed);
}

void AIBW_Finish(CRules@ rules)
{
	const u8 team = rules.get_u8("aib wave team");
	const u32 elapsed = getGameTime() - rules.get_u32("aib wave start tick");
	const u32 absorbedCost = rules.get_u32("aib wave damage cost");
	const u32 completionTick = rules.get_u32("aib wave completion tick");
	const u32 structureLifetime = completionTick == 0 || completionTick >= elapsed ? 0 : elapsed - completionTick;
	AIBS_Log("wave_result", team, "seed=" + rules.get_u32("aib wave seed") +
		" variant=" + rules.get_string("aib wave variant") + " scenario=" + rules.get_string("aib wave scenario") + " elapsed=" + elapsed +
		" first_breach=" + rules.get_u32("aib wave first breach") + " crossings=" + rules.get_u8("aib wave crossings") +
		" enemy_deaths=" + rules.get_u8("aib wave deaths") + " builder_deaths=" + rules.get_u8("aib wave builder deaths") +
		" flag_approaches=" + rules.get_u8("aib wave flag approaches") + " plan_completed_delta=" +
			(int(rules.get_u16(AIBP_PlanKey(team, "completed"))) - int(rules.get_u16("aib wave completed start"))) +
		" plan_pending=" + rules.get_u16(AIBP_PlanKey(team, "pending")) + " plan_damaged=" + rules.get_u16(AIBP_PlanKey(team, "damaged")) +
		" damage_events=" + rules.get_u16("aib wave damage events") +
		" damage_absorbed_cost=" + absorbedCost + " plan_cost=" + rules.get_u32("aib wave plan cost") + " completion_tick=" + rules.get_u32("aib wave completion tick") +
		" first_damage_tick=" + rules.get_u32("aib wave first damage tick") + " structure_lifetime=" + structureLifetime +
		" builder_travel=" + rules.get_f32("aib wave builder travel") + " builder_idle_ticks=" + rules.get_u32("aib wave builder idle") +
		" reservation_conflicts=" + rules.get_u16("aib wave reservation conflicts") + " replans=" + rules.get_u16("aib wave replans") +
		" route_preserved=" + rules.get_bool("aib wave route preserved") + " friendly_route_penalty=" + rules.get_f32("aib wave friendly route penalty"));
	rules.set_bool("aib wave enabled", false);
	rules.set_bool("aib wave running", false);
	rules.set_bool("aib strategy event log enabled", false);
}

void onTick(CRules@ this)
{
	if (!isServer() || !this.get_bool("aib wave enabled")) return;
	if (!this.get_bool("aib wave running"))
	{
		if (getGameTime() < this.get_u32("aib wave arm tick")) return;
		AIBW_Start(this);
	}
	const u32 elapsed = getGameTime() - this.get_u32("aib wave start tick");
	if (this.get_u8("aib wave spawned") < 12 && elapsed % 45 == 1) AIBW_SpawnUnit(this);
	AIBW_DriveUnits(this);
	AIBW_SampleBuilders(this);
	if (elapsed >= 1200 || (this.get_u8("aib wave spawned") >= 12 && this.get_u8("aib wave crossings") + this.get_u8("aib wave deaths") >= 12)) AIBW_Finish(this);
}

void onBlobDie(CRules@ this, CBlob@ blob)
{
	if (!isServer() || blob is null || !this.get_bool("aib wave running")) return;
	if (blob.hasTag("aib strategy wave unit")) this.set_u8("aib wave deaths", this.get_u8("aib wave deaths") + 1);
	else if (blob.getName() == "aibuilder" && blob.getTeamNum() == this.get_u8("aib wave team"))
		this.set_u8("aib wave builder deaths", this.get_u8("aib wave builder deaths") + 1);
}
