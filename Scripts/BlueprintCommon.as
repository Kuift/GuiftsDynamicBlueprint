// Shared blueprint identifiers, layer names, and rules keys.
// Keep this file dependency-free so editor, builder brain, and server director
// can all include it.

const string AIBP_COMPAT_DATA = "aibuilder blueprint data";
const string AIBP_COMPAT_WIDTH = "aibuilder blueprint width";
const string AIBP_COMPAT_HEIGHT = "aibuilder blueprint height";
const string AIBP_TEAM_SUFFIX = " team ";
const u16 AIBP_MAX_PREFAB_WIDTH = 64;
const u16 AIBP_MAX_PREFAB_HEIGHT = 64;
const u32 AIBP_MAX_PREFAB_CELLS = 4096;

namespace AIBP_Layer
{
	enum layer
	{
		human = 0,
		ai_work = 1,
		ai_desired = 2
	}
}

namespace AIBP_TaskState
{
	enum state
	{
		pending = 0,
		reserved,
		completed,
		cancelled
	}
}

namespace AIBP_Phase
{
	enum phase
	{
		foundation = 0,
		access = 1,
		shell = 2,
		roof = 3,
		closure = 4
	}
}

namespace AIBP_StrategyMode
{
	enum mode
	{
		off = 0,
		suggest = 1,
		auto_mode = 2
	}
}

bool AIBP_IsDirectorEnabled(const u8 mode)
{
	return mode == AIBP_StrategyMode::auto_mode;
}

u8 AIBP_ToggleDirectorMode(const u8 mode)
{
	return AIBP_IsDirectorEnabled(mode) ? AIBP_StrategyMode::off : AIBP_StrategyMode::auto_mode;
}

string AIBP_CompatDataKey(const u8 team) { return AIBP_COMPAT_DATA + AIBP_TEAM_SUFFIX + int(team); }
string AIBP_CompatWidthKey(const u8 team) { return AIBP_COMPAT_WIDTH + AIBP_TEAM_SUFFIX + int(team); }
string AIBP_CompatHeightKey(const u8 team) { return AIBP_COMPAT_HEIGHT + AIBP_TEAM_SUFFIX + int(team); }

string AIBP_LayerName(const u8 layer)
{
	if (layer == AIBP_Layer::human) return "human";
	if (layer == AIBP_Layer::ai_work) return "ai work";
	return "ai desired";
}

string AIBP_LayerDataKey(const u8 team, const u8 layer)
{
	return "aib blueprint " + AIBP_LayerName(layer) + " data team " + int(team);
}

string AIBP_LayerWidthKey(const u8 team, const u8 layer)
{
	return "aib blueprint " + AIBP_LayerName(layer) + " width team " + int(team);
}

string AIBP_LayerHeightKey(const u8 team, const u8 layer)
{
	return "aib blueprint " + AIBP_LayerName(layer) + " height team " + int(team);
}

string AIBP_PlanKey(const u8 team, const string &in field)
{
	return "aib strategy plan " + field + " team " + int(team);
}

string AIBP_TaskKey(const u8 team, const string &in field)
{
	return "aib strategy tasks " + field + " team " + int(team);
}

string AIBP_ModeKey(const u8 team)
{
	return "aib strategy mode team " + int(team);
}

u16 AIBP_BlockId(const u16 encoded) { return encoded & 0x3fff; }

// KAG does not give every buildable blob four distinct orientations.  Keep
// the blueprint representation canonical so the renderer, placement code,
// and completion checks cannot disagree about physically equivalent angles.
u8 AIBP_NormalizeRotationForId(const u16 id, const u8 rotation)
{
	// Doors and ordinary platforms only distinguish horizontal from vertical.
	if (id == 3 || id == 6 || id == 9) return rotation & 1;
	// Team bridges opt out of placement rotation in the base game. Tiles and
	// workshops have no blob orientation at all.
	if (id == 7 || id == 1 || id == 2 || id == 4 || id == 5 ||
		id == 48 || id == 64 || id == 196 || id == 205 ||
		(id >= 80 && id <= 87) || (id >= 89 && id <= 91)) return 0;
	// Ladders are placed horizontally because vertical ladders are unreliable
	// unless they attach to a wall.
	if (id == 88) return 1;
	// Spikes have four meaningful support/facing directions.
	return rotation & 3;
}

u8 AIBP_BlockRotation(const u16 encoded)
{
	return AIBP_NormalizeRotationForId(AIBP_BlockId(encoded), u8(encoded >> 14));
}

u16 AIBP_EncodeBlock(const u16 id, const u8 rotation = 0)
{
	const u16 canonicalId = AIBP_BlockId(id);
	return canonicalId | (u16(AIBP_NormalizeRotationForId(canonicalId, rotation)) << 14);
}

bool AIBP_IsPrefabSizeValid(const u16 width, const u16 height)
{
	return width > 0 && height > 0 && width <= AIBP_MAX_PREFAB_WIDTH &&
		height <= AIBP_MAX_PREFAB_HEIGHT && u32(width) * u32(height) <= AIBP_MAX_PREFAB_CELLS;
}
