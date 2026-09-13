// Schema shared by the brain-side passive observer and rules-side test
// consumers. Keep this file independent of AIBuilderBrain helpers/state so
// importing verdict names cannot pull brain-only code into the rules script.

const u16 AIBG_FAILURE_NONE = 0;
const u16 AIBG_FAILURE_MOTION_STALL = 1;
const u16 AIBG_FAILURE_JUMP_LOOP = 2;
const u16 AIBG_FAILURE_PATH_THRASH = 4;
const u16 AIBG_FAILURE_NO_INTENT = 8;
const u16 AIBG_FAILURE_TARGET_THRASH = 16;
const u16 AIBG_FAILURE_STATE_STALL = 32;
const u16 AIBG_FAILURE_RESOURCE_DEADLOCK = 64;
const u16 AIBG_FAILURE_RESERVATION_DEADLOCK = 128;
const u16 AIBG_FAILURE_INVALID_BUILD = 256;
const u32 AIBG_WINDOW_TICKS = 40;
const u16 AIBG_MIN_MOVEMENT_INTENT_TICKS = 30;
const f32 AIBG_STALL_DISPLACEMENT = 8.0f;
const f32 AIBG_LOOP_DISPLACEMENT = 12.0f;
const u8 AIBG_JUMP_LOOP_ATTEMPTS = 5;
const u8 AIBG_PATH_THRASH_REPLANS = 4;
const u8 AIBG_TARGET_THRASH_CHANGES = 6;
const u8 AIBG_INVALID_BUILD_ATTEMPTS = 4;
const u8 AIBG_OUTCOME_SAMPLE_TICKS = 5;
const u8 AIBG_PRE_SAMPLES = 30;
const u8 AIBG_POST_SAMPLES = 12;
const u32 AIBG_POST_TICKS = 60;
const u8 AIBG_SAMPLE_FIELDS = 8;

string AIBG_FailureNames(const u16 flags)
{
	string result = "";
	if ((flags & AIBG_FAILURE_MOTION_STALL) != 0) result = "motion_stall";
	if ((flags & AIBG_FAILURE_JUMP_LOOP) != 0) result += (result == "" ? "" : "+") + "jump_loop";
	if ((flags & AIBG_FAILURE_PATH_THRASH) != 0) result += (result == "" ? "" : "+") + "path_thrash";
	if ((flags & AIBG_FAILURE_NO_INTENT) != 0) result += (result == "" ? "" : "+") + "no_intent";
	if ((flags & AIBG_FAILURE_TARGET_THRASH) != 0) result += (result == "" ? "" : "+") + "target_thrash";
	if ((flags & AIBG_FAILURE_STATE_STALL) != 0) result += (result == "" ? "" : "+") + "state_stall";
	if ((flags & AIBG_FAILURE_RESOURCE_DEADLOCK) != 0) result += (result == "" ? "" : "+") + "resource_deadlock";
	if ((flags & AIBG_FAILURE_RESERVATION_DEADLOCK) != 0) result += (result == "" ? "" : "+") + "reservation_deadlock";
	if ((flags & AIBG_FAILURE_INVALID_BUILD) != 0) result += (result == "" ? "" : "+") + "invalid_build";
	return result == "" ? "none" : result;
}
