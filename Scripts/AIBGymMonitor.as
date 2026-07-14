// Passive rolling diagnostics for AI-builder movement. This observer never
// presses keys, changes paths, or changes AI state; it only latches evidence
// for the gym and optional runtime telemetry.

#include "AIBGymCommon.as";

u16 AIBG_ClassifyWindow(const u16 movementIntentTicks, const f32 maxDisplacement,
	const u8 jumpAttempts, const u8 replans)
{
	u16 flags = AIBG_FAILURE_NONE;
	if (movementIntentTicks >= AIBG_MIN_MOVEMENT_INTENT_TICKS && maxDisplacement < AIBG_STALL_DISPLACEMENT)
		flags |= AIBG_FAILURE_MOTION_STALL;
	if (jumpAttempts >= AIBG_JUMP_LOOP_ATTEMPTS && maxDisplacement < AIBG_LOOP_DISPLACEMENT)
		flags |= AIBG_FAILURE_JUMP_LOOP;
	if (replans >= AIBG_PATH_THRASH_REPLANS && maxDisplacement < AIBG_LOOP_DISPLACEMENT)
		flags |= AIBG_FAILURE_PATH_THRASH;
	return flags;
}

void AIBG_Init(CBlob@ blob)
{
	if (blob is null) return;
	blob.set_u16("aib gym failure flags", AIBG_FAILURE_NONE);
	blob.set_u32("aib gym failure tick", 0);
	blob.set_string("aib gym failure detail", "");
	blob.set_u16("aib gym repath count", 0);
	blob.set_bool("aib gym jump was pressed", false);
	blob.set_u32("aib gym last jump attempt", 0);
	blob.set_u8("aib gym observed state", 255);
	blob.set_u16("aib gym invalid build count", 0);
	blob.set_string("aib gym invalid build reason", "");
	blob.set_netid("aib gym last target", 0);
	blob.set_Vec2f("aib gym last tile target", Vec2f_zero);
	array<s32> samples;
	blob.set("aib gym diagnostic samples", samples);
	blob.set_bool("aib gym diagnostic capture", false);
	blob.set_bool("aib gym diagnostic emitted", false);
	blob.set_u32("aib gym diagnostic until", 0);
	AIBG_ResetWindow(blob, 255);
}

void AIBG_Byte(array<u8> &inout bytes, const u8 value) { bytes.push_back(value); }
void AIBG_U16(array<u8> &inout bytes, const u16 value)
{
	AIBG_Byte(bytes, u8(value & 0xff)); AIBG_Byte(bytes, u8((value >> 8) & 0xff));
}
void AIBG_S16(array<u8> &inout bytes, const s16 value) { AIBG_U16(bytes, u16(value)); }
void AIBG_U32(array<u8> &inout bytes, const u32 value)
{
	AIBG_U16(bytes, u16(value & 0xffff)); AIBG_U16(bytes, u16((value >> 16) & 0xffff));
}

string AIBG_Base64(array<u8> &in bytes)
{
	const string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	string result = "";
	for (uint i = 0; i < bytes.length; i += 3)
	{
		const u32 a = bytes[i]; const bool hasB = i + 1 < bytes.length; const bool hasC = i + 2 < bytes.length;
		const u32 b = hasB ? bytes[i + 1] : 0; const u32 c = hasC ? bytes[i + 2] : 0;
		const u32 packed = (a << 16) | (b << 8) | c;
		result += alphabet.substr((packed >> 18) & 63, 1); result += alphabet.substr((packed >> 12) & 63, 1);
		result += hasB ? alphabet.substr((packed >> 6) & 63, 1) : "=";
		result += hasC ? alphabet.substr(packed & 63, 1) : "=";
	}
	return result;
}

u8 AIBG_InputMask(CBlob@ blob)
{
	if (blob is null) return 0;
	u8 mask = 0;
	if (blob.isKeyPressed(key_left)) mask |= 1; if (blob.isKeyPressed(key_right)) mask |= 2;
	if (blob.isKeyPressed(key_up)) mask |= 4; if (blob.isKeyPressed(key_down)) mask |= 8;
	if (blob.isKeyPressed(key_action1)) mask |= 16; if (blob.isKeyPressed(key_action2)) mask |= 32;
	if (blob.isKeyPressed(key_action3)) mask |= 64;
	return mask;
}

void AIBG_EmitDiagnosticWindow(CBlob@ blob, array<s32>@ samples)
{
	if (blob is null || samples is null || samples.length < AIBG_SAMPLE_FIELDS) return;
	const u32 failureTick = blob.get_u32("aib gym failure tick");
	const u8 count = u8(Maths::Min(uint(255), samples.length / AIBG_SAMPLE_FIELDS));
	array<u8> bytes;
	AIBG_Byte(bytes, 1); AIBG_U16(bytes, blob.getNetworkID()); AIBG_Byte(bytes, u8(blob.getTeamNum()));
	AIBG_U32(bytes, failureTick); AIBG_U16(bytes, blob.get_u16("aib gym failure flags")); AIBG_Byte(bytes, count);
	for (uint sample = 0; sample < count; sample++)
	{
		const uint at = sample * AIBG_SAMPLE_FIELDS;
		const s32 offset = samples[at] - s32(failureTick);
		AIBG_S16(bytes, s16(Maths::Max(-32767, Maths::Min(32767, offset))));
		AIBG_S16(bytes, s16(samples[at + 1])); AIBG_S16(bytes, s16(samples[at + 2]));
		AIBG_S16(bytes, s16(samples[at + 3])); AIBG_S16(bytes, s16(samples[at + 4]));
		AIBG_Byte(bytes, u8(samples[at + 5])); AIBG_Byte(bytes, u8(samples[at + 6])); AIBG_U16(bytes, u16(samples[at + 7]));
	}
	CRules@ rules = getRules();
	if (rules !is null && (rules.gamemode_name == "CTF" || rules.gamemode_name == "AIBTest"))
		print("[AIBGYMW] data=" + AIBG_Base64(bytes));
	blob.set_bool("aib gym diagnostic emitted", true);
	blob.set_bool("aib gym diagnostic capture", false);
}

void AIBG_SampleDiagnostic(CBlob@ blob, const u8 state, const u32 now)
{
	if (blob is null || now % AIBG_OUTCOME_SAMPLE_TICKS != blob.getNetworkID() % AIBG_OUTCOME_SAMPLE_TICKS) return;
	array<s32>@ samples = null;
	if (!blob.get("aib gym diagnostic samples", @samples) || samples is null)
	{
		array<s32> created;
		blob.set("aib gym diagnostic samples", created);
		if (!blob.get("aib gym diagnostic samples", @samples) || samples is null) return;
	}
	const Vec2f tile = blob.get_Vec2f("ai builder tile target");
	samples.push_back(s32(now)); samples.push_back(s32(blob.getPosition().x)); samples.push_back(s32(blob.getPosition().y));
	samples.push_back(s32(tile.x)); samples.push_back(s32(tile.y)); samples.push_back(state);
	samples.push_back(AIBG_InputMask(blob)); samples.push_back(blob.get_netid("ai builder target"));
	const bool capture = blob.get_bool("aib gym diagnostic capture");
	const uint maxValues = uint(capture ? AIBG_PRE_SAMPLES + AIBG_POST_SAMPLES : AIBG_PRE_SAMPLES) * AIBG_SAMPLE_FIELDS;
	while (samples.length > maxValues) for (u8 i = 0; i < AIBG_SAMPLE_FIELDS; i++) samples.removeAt(0);
	if (capture && !blob.get_bool("aib gym diagnostic emitted") && now >= blob.get_u32("aib gym diagnostic until"))
		AIBG_EmitDiagnosticWindow(blob, samples);
}

void AIBG_ResetWindow(CBlob@ blob, const u8 state)
{
	if (blob is null) return;
	blob.set_u32("aib gym window start", getGameTime());
	blob.set_Vec2f("aib gym window origin", blob.getPosition());
	blob.set_f32("aib gym max displacement", 0.0f);
	blob.set_u16("aib gym movement intent ticks", 0);
	blob.set_u8("aib gym jump attempts", 0);
	blob.set_u16("aib gym interaction ticks", 0);
	blob.set_u8("aib gym target changes", 0);
	blob.set_u8("aib gym outcome changes", 0);
	blob.set_u16("aib gym repath baseline", blob.get_u16("aib gym repath count"));
	blob.set_u16("aib gym invalid build baseline", blob.get_u16("aib gym invalid build count"));
	blob.set_u16("aib gym last wood", AIB_CountMaterial(blob, "mat_wood"));
	blob.set_u16("aib gym last stone", AIB_CountMaterial(blob, "mat_stone"));
	blob.set_u16("aib gym last gold", AIB_CountMaterial(blob, "mat_gold"));
	CRules@ rules = getRules();
	const u8 team = u8(blob.getTeamNum());
	blob.set_u16("aib gym last plan completed", rules is null ? 0 : rules.get_u16(AIBP_PlanKey(team, "completed")));
	blob.set_u16("aib gym last plan damaged", rules is null ? 0 : rules.get_u16(AIBP_PlanKey(team, "damaged")));
	blob.set_u8("aib gym observed state", state);
}

void AIBG_RecordRepath(CBlob@ blob)
{
	if (blob is null) return;
	blob.set_u16("aib gym repath count", blob.get_u16("aib gym repath count") + 1);
}

void AIBG_RecordInvalidBuild(CBlob@ blob, const string &in reason)
{
	if (blob is null) return;
	blob.set_u16("aib gym invalid build count", blob.get_u16("aib gym invalid build count") + 1);
	blob.set_string("aib gym invalid build reason", reason);
}

bool AIBG_HasStaleReservation(CBlob@ blob)
{
	if (blob is null) return false;
	array<u16>@ xs = null; array<u16>@ ys = null; array<u16>@ blocks = null; array<u16>@ reserved = null;
	array<u8>@ phases = null; array<u8>@ states = null; array<u32>@ untils = null;
	if (!AIBP_LoadTaskArrays(u8(blob.getTeamNum()), @xs, @ys, @blocks, @phases, @states, @reserved, @untils)) return false;
	const u32 now = getGameTime();
	for (uint i = 0; i < reserved.length && i < untils.length && i < states.length; i++)
	{
		if (reserved[i] == 0 || states[i] == AIBP_TaskState::completed || states[i] == AIBP_TaskState::cancelled) continue;
		CBlob@ owner = getBlobByNetworkID(reserved[i]);
		// The observer runs before this tick's builder behavior, so allow a short
		// renewal grace instead of flagging a live owner at the exact expiry tick.
		if (untils[i] + 5 < now || owner is null || owner.hasTag("dead")) return true;
	}
	return false;
}

bool AIBG_HasAccessibleBlueprintResource(CBlob@ blob)
{
	if (blob is null || blob.get_u8("ai builder state") != AIBuilderState::collect_blueprint_resources) return false;
	string material; u16 amount = 0;
	if (!AIB_GetBlueprintMaterialNeed(blob, material, amount) || material == "" || amount == 0) return false;
	CBlob@ home = AIB_GetTeamHome(blob);
	return home !is null && AIB_CountHomeMaterial(home, material) >= amount;
}

bool AIBG_StateHasMovementIntent(CBlob@ blob, const bool monitorableState)
{
	if (blob is null || !monitorableState) return false;
	if (blob.isKeyPressed(key_left) || blob.isKeyPressed(key_right) || blob.isKeyPressed(key_up)) return true;
	Vec2f destination = blob.get_Vec2f("ai builder destination");
	return destination != Vec2f_zero && (destination - blob.getPosition()).Length() > 24.0f;
}

void AIBG_Tick(CBrain@ brain, CBlob@ blob, const u8 state, const bool monitorableState)
{
	if (blob is null || blob.hasTag("dead")) return;
	if (!blob.exists("aib gym window start")) AIBG_Init(blob);

	if (!monitorableState || blob.get_u8("aib gym observed state") != state)
	{
		AIBG_ResetWindow(blob, state);
		blob.set_bool("aib gym jump was pressed", blob.isKeyPressed(key_up));
		return;
	}

	Vec2f origin = blob.get_Vec2f("aib gym window origin");
	const f32 displacement = (blob.getPosition() - origin).Length();
	if (displacement > blob.get_f32("aib gym max displacement")) blob.set_f32("aib gym max displacement", displacement);

	if (AIBG_StateHasMovementIntent(blob, monitorableState))
		blob.set_u16("aib gym movement intent ticks", blob.get_u16("aib gym movement intent ticks") + 1);

	const bool up = blob.isKeyPressed(key_up);
	const u32 now = getGameTime();
	AIBG_SampleDiagnostic(blob, state, now);
	const bool groundedRetry = up && blob.isOnGround() && now - blob.get_u32("aib gym last jump attempt") >= 3;
	if ((up && !blob.get_bool("aib gym jump was pressed")) || groundedRetry)
	{
		blob.set_u8("aib gym jump attempts", blob.get_u8("aib gym jump attempts") + 1);
		blob.set_u32("aib gym last jump attempt", now);
	}
	blob.set_bool("aib gym jump was pressed", up);
	if (blob.isKeyPressed(key_action1) || blob.isKeyPressed(key_action2) || blob.isKeyPressed(key_action3))
		blob.set_u16("aib gym interaction ticks", blob.get_u16("aib gym interaction ticks") + 1);

	const u16 target = blob.get_netid("ai builder target");
	const Vec2f tileTarget = blob.get_Vec2f("ai builder tile target");
	if (target != blob.get_netid("aib gym last target") || tileTarget != blob.get_Vec2f("aib gym last tile target"))
	{
		blob.set_u8("aib gym target changes", blob.get_u8("aib gym target changes") + 1);
		blob.set_netid("aib gym last target", target);
		blob.set_Vec2f("aib gym last tile target", tileTarget);
	}
	CRules@ rules = getRules();
	const u8 team = u8(blob.getTeamNum());
	// Inventory traversal is the expensive observation here. Stagger it across
	// builders and sample at 6 Hz; target/key/motion evidence stays per tick.
	if (now % AIBG_OUTCOME_SAMPLE_TICKS == blob.getNetworkID() % AIBG_OUTCOME_SAMPLE_TICKS)
	{
		const u16 wood = AIB_CountMaterial(blob, "mat_wood");
		const u16 stone = AIB_CountMaterial(blob, "mat_stone");
		const u16 gold = AIB_CountMaterial(blob, "mat_gold");
		const u16 completed = rules is null ? 0 : rules.get_u16(AIBP_PlanKey(team, "completed"));
		const u16 damaged = rules is null ? 0 : rules.get_u16(AIBP_PlanKey(team, "damaged"));
		if (wood != blob.get_u16("aib gym last wood") || stone != blob.get_u16("aib gym last stone") ||
			gold != blob.get_u16("aib gym last gold") || completed != blob.get_u16("aib gym last plan completed") ||
			damaged != blob.get_u16("aib gym last plan damaged"))
		{
			blob.set_u8("aib gym outcome changes", blob.get_u8("aib gym outcome changes") + 1);
			blob.set_u16("aib gym last wood", wood); blob.set_u16("aib gym last stone", stone); blob.set_u16("aib gym last gold", gold);
			blob.set_u16("aib gym last plan completed", completed); blob.set_u16("aib gym last plan damaged", damaged);
		}
	}

	if (now - blob.get_u32("aib gym window start") < AIBG_WINDOW_TICKS) return;
	const u16 repathTotal = blob.get_u16("aib gym repath count");
	const u16 repathBase = blob.get_u16("aib gym repath baseline");
	const u8 replans = u8(Maths::Min(u16(255), u16(repathTotal - repathBase)));
	const u16 movementTicks = blob.get_u16("aib gym movement intent ticks");
	const u8 jumps = blob.get_u8("aib gym jump attempts");
	const f32 maxMove = blob.get_f32("aib gym max displacement");
	u16 flags = AIBG_ClassifyWindow(movementTicks, maxMove, jumps, replans);
	const u16 interactions = blob.get_u16("aib gym interaction ticks");
	const u8 targetChanges = blob.get_u8("aib gym target changes");
	const u8 outcomes = blob.get_u8("aib gym outcome changes");
	const u16 invalidAttempts = blob.get_u16("aib gym invalid build count") - blob.get_u16("aib gym invalid build baseline");
	const bool activeIdle = state == AIBuilderState::idle && blob.get_bool("ai builder job active");
	const u32 waitTouched = blob.get_u32("ai builder status wait touched");
	const bool explicitlyWaiting = waitTouched + 1 >= now;
	if (activeIdle) flags |= AIBG_FAILURE_NO_INTENT;
	if (targetChanges >= AIBG_TARGET_THRASH_CHANGES && outcomes == 0) flags |= AIBG_FAILURE_TARGET_THRASH;
	// Direct controllers can advance without leaving key/destination intent set
	// when this observer samples. Real displacement is still progress: the
	// Gloryhill miner moved 25px in a quiet window before later delivering its
	// stone, so state-stall must require low motion as well as no side effect.
	if (!activeIdle && !explicitlyWaiting && movementTicks == 0 && interactions == 0 && targetChanges == 0 && outcomes == 0 &&
		maxMove < AIBG_STALL_DISPLACEMENT)
		flags |= AIBG_FAILURE_STATE_STALL;
	if (AIBG_HasAccessibleBlueprintResource(blob) && outcomes == 0 && maxMove < AIBG_STALL_DISPLACEMENT)
		flags |= AIBG_FAILURE_RESOURCE_DEADLOCK;
	if (AIBG_HasStaleReservation(blob)) flags |= AIBG_FAILURE_RESERVATION_DEADLOCK;
	if (invalidAttempts >= AIBG_INVALID_BUILD_ATTEMPTS) flags |= AIBG_FAILURE_INVALID_BUILD;
	if (rules !is null && rules.gamemode_name == "AIBTest")
	{
		AIB_LogEvent("gym", "window", AIB_EventBlobRef(blob), "state=" + state + " movement_ticks=" + movementTicks +
			" max_displacement=" + maxMove + " jumps=" + jumps + " replans=" + replans + " interactions=" + interactions +
			" targets=" + targetChanges + " outcomes=" + outcomes + " invalid=" + invalidAttempts + " flags=" + AIBG_FailureNames(flags));
	}

	if (flags != AIBG_FAILURE_NONE && blob.get_u16("aib gym failure flags") == AIBG_FAILURE_NONE)
	{
		blob.set_u16("aib gym failure flags", flags);
		blob.set_u32("aib gym failure tick", now);
		blob.set_bool("aib gym diagnostic capture", true);
		blob.set_u32("aib gym diagnostic until", now + AIBG_POST_TICKS);
		const string detail = "kind=" + AIBG_FailureNames(flags) + " state=" + state +
			" movement_ticks=" + movementTicks + " max_displacement=" + maxMove +
			" jumps=" + jumps + " replans=" + replans + " interactions=" + interactions + " targets=" + targetChanges +
			" outcomes=" + outcomes + " invalid=" + invalidAttempts + " invalid_reason=" + blob.get_string("aib gym invalid build reason") +
			" pos=" + int(blob.getPosition().x) + "," + int(blob.getPosition().y) +
			" destination=" + int(blob.get_Vec2f("ai builder destination").x) + "," + int(blob.get_Vec2f("ai builder destination").y);
		blob.set_string("aib gym failure detail", detail);
		AIB_LogEvent("gym", "progress_violation", AIB_EventBlobRef(blob), detail);
		if (rules !is null && rules.gamemode_name == "CTF")
		{
			const Vec2f tile = blob.get_Vec2f("ai builder tile target");
			print("[AIBGYM] v=1 t=" + now + " b=" + blob.getNetworkID() + " tm=" + blob.getTeamNum() +
				" f=" + flags + " s=" + state + " x=" + int(blob.getPosition().x) + " y=" + int(blob.getPosition().y) +
				" tx=" + int(tile.x) + " ty=" + int(tile.y) + " mv=" + int(maxMove) + " j=" + jumps +
				" rp=" + replans + " in=" + interactions + " tg=" + targetChanges + " out=" + outcomes + " inv=" + invalidAttempts);
		}
	}

	AIBG_ResetWindow(blob, state);
}
