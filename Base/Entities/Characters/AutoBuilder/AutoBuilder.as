#include "AIBEventLog.as";

const u8 AIBU_JOB_BLUEPRINT = 2;
const u8 AIBU_STATE_FIND_BLUEPRINT = 13;

void onInit(CBlob@ this)
{
	this.Tag("autobuilder");
	this.Tag("no pickup");
	this.addCommandID("autobuilder build blueprint");
	this.addCommandID("ai builder status bubble");
	this.set_u8("ai builder state", 0);
	this.set_u8("ai builder job", AIBU_JOB_BLUEPRINT);
	this.set_bool("ai builder job active", false);
	this.set_string("ai builder status bubble text", "");
	this.set_u32("ai builder status bubble until", 0);
	this.set_u8("air_count", 255);

	CShape@ shape = this.getShape();
	if (shape !is null)
	{
		shape.getConsts().mapCollisions = false;
		shape.getConsts().collidable = false;
		shape.SetGravityScale(0.0f);
	}

	this.SetLight(true);
	this.SetLightRadius(20.0f);
	this.SetLightColor(SColor(255, 211, 121, 224));
	CSprite@ sprite = this.getSprite();
	if (sprite !is null)
	{
		sprite.SetZ(1000.0f);
		sprite.PlaySound("/Construct.ogg");
	}
}

void onTick(CBlob@ this)
{
	CShape@ shape = this.getShape();
	if (shape is null) return;
	shape.getConsts().mapCollisions = false;
	shape.getConsts().collidable = false;
	shape.SetGravityScale(0.0f);
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	return false;
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (caller is null || caller.getTeamNum() != this.getTeamNum()) return;
	if ((caller.getPosition() - this.getPosition()).Length() > 32.0f) return;

	CButton@ button = caller.CreateGenericButton("$stone_block$", Vec2f_zero, this,
		this.getCommandID("autobuilder build blueprint"),
		"Build blueprint (infinite resources; one block per second)");
	if (button !is null) button.enableRadius = 32.0f;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("ai builder status bubble"))
	{
		if (!isClient()) return;
		string text;
		if (!params.saferead_string(text)) return;
		this.set_string("ai builder status bubble text", text);
		this.set_u32("ai builder status bubble until", getGameTime() + 4 * 30);
		return;
	}

	if (cmd != this.getCommandID("autobuilder build blueprint") || !isServer()) return;
	CPlayer@ player = getNet().getActiveCommandPlayer();
	CBlob@ caller = player is null ? null : player.getBlob();
	if (caller is null || caller.getTeamNum() != this.getTeamNum() || caller.getDistanceTo(this) > 32.0f) return;

	AIB_LogEvent("player", "command", AIB_EventBlobRef(this),
		"command=autobuilder_build_blueprint pos=" + AIB_EventPos(this.getPosition()));
	this.set_u8("ai builder state", AIBU_STATE_FIND_BLUEPRINT);
	this.set_u8("ai builder job", AIBU_JOB_BLUEPRINT);
	this.set_bool("ai builder job active", true);
	this.set_bool("aib strategy assigned", false);
	this.set_netid("ai builder target", 0);
	this.set_Vec2f("ai builder destination", Vec2f_zero);
	this.set_Vec2f("ai builder tile target", Vec2f_zero);
	this.set_bool("ai builder saw blueprint target", false);
	this.Sync("ai builder state", true);
	this.Sync("ai builder job", true);
	this.Sync("ai builder job active", true);
}
