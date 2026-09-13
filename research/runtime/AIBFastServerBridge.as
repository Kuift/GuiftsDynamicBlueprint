// Research-only server bridge for persistent focused AIBTest iterations.

const string AIBFAST_RESTART_COMMAND = "aibfast server restart";
const u16 AIBFAST_BRIDGE_VERSION = 3;
const string AIBFAST_PENDING_KEY = "aibfast server pending";
const string AIBFAST_EPOCH_KEY = "aibfast server epoch";
const string AIBFAST_LAST_STATUS_KEY = "aibfast server last status";

// Bounded, research-only movement measurements.  The observer runs after the
// production AIBTest runner and never changes a blob, path, key, or verdict.
bool AIBFAST_pathActive = false;
u16 AIBFAST_pathBot = 0;
string AIBFAST_pathScenario = "";
u32 AIBFAST_pathStartTick = 0;
u32 AIBFAST_pathLastTick = 0;
u32 AIBFAST_pathSamples = 0;
Vec2f AIBFAST_pathStartPos = Vec2f_zero;
Vec2f AIBFAST_pathLastPos = Vec2f_zero;
Vec2f AIBFAST_pathMinPos = Vec2f_zero;
Vec2f AIBFAST_pathMaxPos = Vec2f_zero;
Vec2f AIBFAST_pathLastDestination = Vec2f_zero;
u8 AIBFAST_pathLastKeys = 0;
u8 AIBFAST_pathLastState = 255;
u8 AIBFAST_pathLastObstruction = 0;
u8 AIBFAST_pathMaxObstruction = 0;
u8 AIBFAST_pathLastBrainState = 255;
u16 AIBFAST_pathRepathBaseline = 0;
u16 AIBFAST_pathRepathLast = 0;
u32 AIBFAST_pathFirstDestinationTick = 0;
u32 AIBFAST_pathFirstIntentTick = 0;
u32 AIBFAST_pathFirstMovementTick = 0;
u32 AIBFAST_pathFirstOldPositionDeltaTick = 0;
u32 AIBFAST_pathFirstHorizontalMovementTick = 0;
u32 AIBFAST_pathFirstOldHorizontalDeltaTick = 0;
u16 AIBFAST_pathIntentTicks = 0;
u16 AIBFAST_pathMovementTicks = 0;
u16 AIBFAST_pathHorizontalMovementTicks = 0;
u16 AIBFAST_pathStalledIntentTicks = 0;
u16 AIBFAST_pathCurrentStall = 0;
u16 AIBFAST_pathLongestStall = 0;
u16 AIBFAST_pathDestinationChanges = 0;
u16 AIBFAST_pathKeyChanges = 0;
u16 AIBFAST_pathStateChanges = 0;
u16 AIBFAST_pathObstructionChanges = 0;
u16 AIBFAST_pathBrainStateChanges = 0;
u16 AIBFAST_pathOldPositionDeltaTicks = 0;
u16 AIBFAST_pathGroundTicks = 0;
u16 AIBFAST_pathWallTicks = 0;
u16 AIBFAST_pathLadderTicks = 0;
u16 AIBFAST_pathBrainIdleTicks = 0;
u16 AIBFAST_pathBrainSearchingTicks = 0;
u16 AIBFAST_pathBrainWrongPathTicks = 0;
u16 AIBFAST_pathBrainHasPathTicks = 0;
u16 AIBFAST_pathBrainStuckTicks = 0;
u16 AIBFAST_pathBrainOtherTicks = 0;
f32 AIBFAST_pathTotalDistance = 0.0f;
f32 AIBFAST_pathMaxDistance = 0.0f;

void AIBFAST_ResetPathMetrics()
{
	AIBFAST_pathActive = false;
	AIBFAST_pathBot = 0;
	AIBFAST_pathScenario = "";
	AIBFAST_pathStartTick = 0;
	AIBFAST_pathLastTick = 0;
	AIBFAST_pathSamples = 0;
	AIBFAST_pathStartPos = Vec2f_zero;
	AIBFAST_pathLastPos = Vec2f_zero;
	AIBFAST_pathMinPos = Vec2f_zero;
	AIBFAST_pathMaxPos = Vec2f_zero;
	AIBFAST_pathLastDestination = Vec2f_zero;
	AIBFAST_pathLastKeys = 0;
	AIBFAST_pathLastState = 255;
	AIBFAST_pathLastObstruction = 0;
	AIBFAST_pathMaxObstruction = 0;
	AIBFAST_pathLastBrainState = 255;
	AIBFAST_pathRepathBaseline = 0;
	AIBFAST_pathRepathLast = 0;
	AIBFAST_pathFirstDestinationTick = 0;
	AIBFAST_pathFirstIntentTick = 0;
	AIBFAST_pathFirstMovementTick = 0;
	AIBFAST_pathFirstOldPositionDeltaTick = 0;
	AIBFAST_pathFirstHorizontalMovementTick = 0;
	AIBFAST_pathFirstOldHorizontalDeltaTick = 0;
	AIBFAST_pathIntentTicks = 0;
	AIBFAST_pathMovementTicks = 0;
	AIBFAST_pathHorizontalMovementTicks = 0;
	AIBFAST_pathStalledIntentTicks = 0;
	AIBFAST_pathCurrentStall = 0;
	AIBFAST_pathLongestStall = 0;
	AIBFAST_pathDestinationChanges = 0;
	AIBFAST_pathKeyChanges = 0;
	AIBFAST_pathStateChanges = 0;
	AIBFAST_pathObstructionChanges = 0;
	AIBFAST_pathBrainStateChanges = 0;
	AIBFAST_pathOldPositionDeltaTicks = 0;
	AIBFAST_pathGroundTicks = 0;
	AIBFAST_pathWallTicks = 0;
	AIBFAST_pathLadderTicks = 0;
	AIBFAST_pathBrainIdleTicks = 0;
	AIBFAST_pathBrainSearchingTicks = 0;
	AIBFAST_pathBrainWrongPathTicks = 0;
	AIBFAST_pathBrainHasPathTicks = 0;
	AIBFAST_pathBrainStuckTicks = 0;
	AIBFAST_pathBrainOtherTicks = 0;
	AIBFAST_pathTotalDistance = 0.0f;
	AIBFAST_pathMaxDistance = 0.0f;
}

u8 AIBFAST_InputMask(CBlob@ blob)
{
	if (blob is null) return 0;
	u8 mask = 0;
	if (blob.isKeyPressed(key_left)) mask |= 1;
	if (blob.isKeyPressed(key_right)) mask |= 2;
	if (blob.isKeyPressed(key_up)) mask |= 4;
	if (blob.isKeyPressed(key_down)) mask |= 8;
	if (blob.isKeyPressed(key_action1)) mask |= 16;
	if (blob.isKeyPressed(key_action2)) mask |= 32;
	if (blob.isKeyPressed(key_action3)) mask |= 64;
	return mask;
}

void AIBFAST_CountBrainState(const u8 state)
{
	switch (state)
	{
		case CBrain::idle: AIBFAST_pathBrainIdleTicks++; break;
		case CBrain::searching: AIBFAST_pathBrainSearchingTicks++; break;
		case CBrain::wrong_path: AIBFAST_pathBrainWrongPathTicks++; break;
		case CBrain::has_path: AIBFAST_pathBrainHasPathTicks++; break;
		case CBrain::stuck: AIBFAST_pathBrainStuckTicks++; break;
		default: AIBFAST_pathBrainOtherTicks++; break;
	}
}

void AIBFAST_BeginPathMetrics(CBlob@ blob, const string &in scenario, const u32 now)
{
	AIBFAST_ResetPathMetrics();
	if (blob is null) return;
	AIBFAST_pathActive = true;
	AIBFAST_pathBot = blob.getNetworkID();
	AIBFAST_pathScenario = scenario;
	AIBFAST_pathStartTick = now;
	AIBFAST_pathLastTick = now;
	AIBFAST_pathStartPos = blob.getPosition();
	AIBFAST_pathLastPos = AIBFAST_pathStartPos;
	AIBFAST_pathMinPos = AIBFAST_pathStartPos;
	AIBFAST_pathMaxPos = AIBFAST_pathStartPos;
	AIBFAST_pathLastDestination = blob.get_Vec2f("ai builder destination");
	AIBFAST_pathLastKeys = AIBFAST_InputMask(blob);
	AIBFAST_pathLastState = blob.get_u8("ai builder state");
	AIBFAST_pathLastObstruction = blob.get_u8("ai builder obstruction threshold");
	AIBFAST_pathMaxObstruction = AIBFAST_pathLastObstruction;
	AIBFAST_pathRepathBaseline = blob.get_u16("aib gym repath count");
	AIBFAST_pathRepathLast = AIBFAST_pathRepathBaseline;
	CBrain@ brain = blob.getBrain();
	AIBFAST_pathLastBrainState = brain is null ? 255 : u8(brain.getState());
}

void AIBFAST_SamplePathMetrics(CBlob@ blob, const string &in scenario, const u32 now)
{
	if (blob is null) return;
	if (!AIBFAST_pathActive || AIBFAST_pathBot != blob.getNetworkID() || AIBFAST_pathScenario != scenario)
		AIBFAST_BeginPathMetrics(blob, scenario, now);
	if (!AIBFAST_pathActive) return;

	Vec2f pos = blob.getPosition();
	Vec2f oldPos = blob.getOldPosition();
	Vec2f destination = blob.get_Vec2f("ai builder destination");
	Vec2f lastPos = AIBFAST_pathLastPos;
	Vec2f startPos = AIBFAST_pathStartPos;
	Vec2f lastDestination = AIBFAST_pathLastDestination;
	const u8 inputMask = AIBFAST_InputMask(blob);
	const u8 state = blob.get_u8("ai builder state");
	const u8 obstruction = blob.get_u8("ai builder obstruction threshold");
	CBrain@ brain = blob.getBrain();
	const u8 brainState = brain is null ? 255 : u8(brain.getState());
	const f32 step = (pos - lastPos).Length();
	const f32 fromStart = (pos - startPos).Length();
	const bool intent = (inputMask & 7) != 0;
	const bool moved = step > 0.25f;
	const bool oldPositionDelta = (pos - oldPos).Length() > 0.25f;
	const bool movedHorizontally = Maths::Abs(pos.x - lastPos.x) > 0.25f;
	const bool oldHorizontalDelta = Maths::Abs(pos.x - oldPos.x) > 0.25f;

	AIBFAST_pathSamples++;
	AIBFAST_pathLastTick = now;
	AIBFAST_pathTotalDistance += step;
	if (fromStart > AIBFAST_pathMaxDistance) AIBFAST_pathMaxDistance = fromStart;
	if (pos.x < AIBFAST_pathMinPos.x) AIBFAST_pathMinPos.x = pos.x;
	if (pos.y < AIBFAST_pathMinPos.y) AIBFAST_pathMinPos.y = pos.y;
	if (pos.x > AIBFAST_pathMaxPos.x) AIBFAST_pathMaxPos.x = pos.x;
	if (pos.y > AIBFAST_pathMaxPos.y) AIBFAST_pathMaxPos.y = pos.y;

	if (destination.Length() > 0.01f && AIBFAST_pathFirstDestinationTick == 0) AIBFAST_pathFirstDestinationTick = now;
	if (intent)
	{
		AIBFAST_pathIntentTicks++;
		if (AIBFAST_pathFirstIntentTick == 0) AIBFAST_pathFirstIntentTick = now;
	}
	if (moved)
	{
		AIBFAST_pathMovementTicks++;
		if (AIBFAST_pathFirstMovementTick == 0) AIBFAST_pathFirstMovementTick = now;
	}
	if (movedHorizontally)
	{
		AIBFAST_pathHorizontalMovementTicks++;
		if (AIBFAST_pathFirstHorizontalMovementTick == 0) AIBFAST_pathFirstHorizontalMovementTick = now;
	}
	if (oldPositionDelta)
	{
		AIBFAST_pathOldPositionDeltaTicks++;
		if (AIBFAST_pathFirstOldPositionDeltaTick == 0) AIBFAST_pathFirstOldPositionDeltaTick = now;
	}
	if (oldHorizontalDelta && AIBFAST_pathFirstOldHorizontalDeltaTick == 0)
		AIBFAST_pathFirstOldHorizontalDeltaTick = now;
	if (intent && !moved)
	{
		AIBFAST_pathStalledIntentTicks++;
		AIBFAST_pathCurrentStall++;
		if (AIBFAST_pathCurrentStall > AIBFAST_pathLongestStall) AIBFAST_pathLongestStall = AIBFAST_pathCurrentStall;
	}
	else AIBFAST_pathCurrentStall = 0;

	if ((destination - lastDestination).Length() > 0.25f) AIBFAST_pathDestinationChanges++;
	if (inputMask != AIBFAST_pathLastKeys) AIBFAST_pathKeyChanges++;
	if (state != AIBFAST_pathLastState) AIBFAST_pathStateChanges++;
	if (obstruction != AIBFAST_pathLastObstruction) AIBFAST_pathObstructionChanges++;
	if (brainState != AIBFAST_pathLastBrainState) AIBFAST_pathBrainStateChanges++;
	if (obstruction > AIBFAST_pathMaxObstruction) AIBFAST_pathMaxObstruction = obstruction;
	if (blob.isOnGround()) AIBFAST_pathGroundTicks++;
	if (blob.isOnWall()) AIBFAST_pathWallTicks++;
	if (blob.isOnLadder()) AIBFAST_pathLadderTicks++;
	AIBFAST_CountBrainState(brainState);

	AIBFAST_pathRepathLast = blob.get_u16("aib gym repath count");
	AIBFAST_pathLastPos = pos;
	AIBFAST_pathLastDestination = destination;
	AIBFAST_pathLastKeys = inputMask;
	AIBFAST_pathLastState = state;
	AIBFAST_pathLastObstruction = obstruction;
	AIBFAST_pathLastBrainState = brainState;
}

string AIBFAST_PathMetricRecord(CRules@ rules, const u32 epoch)
{
	if (!AIBFAST_pathActive)
		return "AIBFAST|PATH_METRICS|epoch=" + epoch + "|bridge=" + AIBFAST_BRIDGE_VERSION +
			"|scenario=" + rules.get_string("aib test scenario") + "|valid=0";
	CBlob@ blob = getBlobByNetworkID(AIBFAST_pathBot);
	Vec2f endPos = AIBFAST_pathLastPos;
	if (blob !is null) endPos = blob.getPosition();
	Vec2f startPos = AIBFAST_pathStartPos;
	Vec2f net = endPos - startPos;
	return "AIBFAST|PATH_METRICS|epoch=" + epoch + "|bridge=" + AIBFAST_BRIDGE_VERSION +
		"|scenario=" + AIBFAST_pathScenario + "|valid=1|bot=" + AIBFAST_pathBot +
		"|start_t=" + AIBFAST_pathStartTick + "|end_t=" + AIBFAST_pathLastTick + "|samples=" + AIBFAST_pathSamples +
		"|first_dest_t=" + AIBFAST_pathFirstDestinationTick + "|first_intent_t=" + AIBFAST_pathFirstIntentTick +
		"|first_move_t=" + AIBFAST_pathFirstMovementTick + "|first_old_delta_t=" + AIBFAST_pathFirstOldPositionDeltaTick +
		"|first_x_move_t=" + AIBFAST_pathFirstHorizontalMovementTick + "|first_old_x_delta_t=" + AIBFAST_pathFirstOldHorizontalDeltaTick +
		"|start_x10=" + int(AIBFAST_pathStartPos.x * 10.0f) + "|start_y10=" + int(AIBFAST_pathStartPos.y * 10.0f) +
		"|end_x10=" + int(endPos.x * 10.0f) + "|end_y10=" + int(endPos.y * 10.0f) +
		"|net_x10=" + int(net.x * 10.0f) + "|net_y10=" + int(net.y * 10.0f) +
		"|total_d10=" + int(AIBFAST_pathTotalDistance * 10.0f) + "|max_d10=" + int(AIBFAST_pathMaxDistance * 10.0f) +
		"|min_x10=" + int(AIBFAST_pathMinPos.x * 10.0f) + "|max_x10=" + int(AIBFAST_pathMaxPos.x * 10.0f) +
		"|min_y10=" + int(AIBFAST_pathMinPos.y * 10.0f) + "|max_y10=" + int(AIBFAST_pathMaxPos.y * 10.0f) +
		"|intent_ticks=" + AIBFAST_pathIntentTicks + "|move_ticks=" + AIBFAST_pathMovementTicks +
		"|x_move_ticks=" + AIBFAST_pathHorizontalMovementTicks +
		"|stall_ticks=" + AIBFAST_pathStalledIntentTicks + "|longest_stall=" + AIBFAST_pathLongestStall +
		"|dest_changes=" + AIBFAST_pathDestinationChanges + "|key_changes=" + AIBFAST_pathKeyChanges +
		"|state_changes=" + AIBFAST_pathStateChanges + "|obstruction_changes=" + AIBFAST_pathObstructionChanges +
		"|max_obstruction=" + AIBFAST_pathMaxObstruction + "|repaths=" + (AIBFAST_pathRepathLast - AIBFAST_pathRepathBaseline) +
		"|old_delta_ticks=" + AIBFAST_pathOldPositionDeltaTicks + "|ground_ticks=" + AIBFAST_pathGroundTicks +
		"|wall_ticks=" + AIBFAST_pathWallTicks + "|ladder_ticks=" + AIBFAST_pathLadderTicks +
		"|brain_state_changes=" + AIBFAST_pathBrainStateChanges + "|brain_idle=" + AIBFAST_pathBrainIdleTicks +
		"|brain_searching=" + AIBFAST_pathBrainSearchingTicks + "|brain_wrong=" + AIBFAST_pathBrainWrongPathTicks +
		"|brain_has=" + AIBFAST_pathBrainHasPathTicks + "|brain_stuck=" + AIBFAST_pathBrainStuckTicks +
		"|brain_other=" + AIBFAST_pathBrainOtherTicks;
}

void onInit(CRules@ this)
{
	this.addCommandID(AIBFAST_RESTART_COMMAND);
	if (isServer())
	{
		this.set_bool(AIBFAST_PENDING_KEY, false);
		this.set_u32(AIBFAST_EPOCH_KEY, 0);
		this.set_string(AIBFAST_LAST_STATUS_KEY, "");
		AIBFAST_ResetPathMetrics();
	}
}

void onCommand(CRules@ this, u8 cmd, CBitStream@ params)
{
	if (cmd != this.getCommandID(AIBFAST_RESTART_COMMAND) || !isServer()) return;
	if (this.gamemode_name != "AIBTest") return;

	const u32 epoch = this.get_u32(AIBFAST_EPOCH_KEY) + 1;
	this.set_u32(AIBFAST_EPOCH_KEY, epoch);
	this.set_bool(AIBFAST_PENDING_KEY, true);
	this.set_string(AIBFAST_LAST_STATUS_KEY, "");
	AIBFAST_ResetPathMetrics();
	tcpr("AIBFAST|SERVER_ACK|epoch=" + epoch + "|bridge=" + AIBFAST_BRIDGE_VERSION + "|t=" + getGameTime());
	this.RestartRules();
}

void onTick(CRules@ this)
{
	if (!isServer() || !this.get_bool(AIBFAST_PENDING_KEY)) return;

	const u32 epoch = this.get_u32(AIBFAST_EPOCH_KEY);
	const string status = this.get_string("aib test display status");
	const string scenario = this.get_string("aib test scenario");
	CBlob@ metricBot = getBlobByNetworkID(this.get_netid("aibt_bot"));
	if (metricBot !is null && !metricBot.hasTag("dead") && scenario != "boot")
		AIBFAST_SamplePathMetrics(metricBot, scenario, getGameTime());
	const string previous = this.get_string(AIBFAST_LAST_STATUS_KEY);
	if (status != previous)
	{
		this.set_string(AIBFAST_LAST_STATUS_KEY, status);
		tcpr("AIBFAST|SERVER_STATE|epoch=" + epoch + "|bridge=" + AIBFAST_BRIDGE_VERSION +
			"|done=" + (this.get_bool("aib tests done") ? "1" : "0") +
			"|scenario=" + scenario +
			"|status=" + status + "|t=" + getGameTime());
	}

	if (!this.get_bool("aib tests done")) return;
	const bool passed = status.findFirst("PASS - FROZEN: ") == 0;
	const bool failed = status.findFirst("FAIL - FROZEN: ") == 0;
	if (!passed && !failed) return;

	tcpr(AIBFAST_PathMetricRecord(this, epoch));
	tcpr("AIBFAST|SERVER_DONE|epoch=" + epoch + "|bridge=" + AIBFAST_BRIDGE_VERSION +
		"|outcome=" + (passed ? "pass" : "fail") +
		"|scenario=" + scenario +
		"|status=" + status + "|t=" + getGameTime());
	this.set_bool(AIBFAST_PENDING_KEY, false);
}
