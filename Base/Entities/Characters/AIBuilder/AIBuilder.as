// AIBuilder.as

#include "AIBEventLog.as";

void onInit(CBlob@ this)
{
	this.addCommandID("ai harvest wood");
	this.addCommandID("ai mine stone");
	this.addCommandID("ai build blueprint");
	this.Tag("builder");
	this.Tag("player");
	this.Tag("no pickup");
	this.set_u8("ai builder state", 0);
	this.set_u8("ai builder job", 0);
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}

void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint@ attachedPoint)
{
	// Do not force-detach here. Detaching from inside the attach callback can
	// recurse through attachment code and crash the engine.
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (caller is null || caller.getTeamNum() != this.getTeamNum()) return;
	if ((caller.getPosition() - this.getPosition()).Length() > 32.0f) return;

	CButton@ button = caller.CreateGenericButton("$mat_wood$", Vec2f(0.0f, -8.0f), this, this.getCommandID("ai harvest wood"), "Harvest wood");
	if (button !is null)
	{
		button.enableRadius = 32.0f;
	}

	CButton@ stoneButton = caller.CreateGenericButton("$mat_stone$", Vec2f(0.0f, 4.0f), this, this.getCommandID("ai mine stone"), "Mine stone");
	if (stoneButton !is null)
	{
		stoneButton.enableRadius = 32.0f;
	}

	CButton@ buildButton = caller.CreateGenericButton("$stone_block$", Vec2f(14.0f, 4.0f), this, this.getCommandID("ai build blueprint"), "Build blueprint");
	if (buildButton !is null)
	{
		buildButton.enableRadius = 32.0f;
	}
}

void onCommand(CBlob@ this, u8 cmd, CBitStream@ params)
{
	if (cmd == this.getCommandID("ai harvest wood") && isServer())
	{
		AIB_LogEvent("player", "command", AIB_EventBlobRef(this), "command=harvest_wood pos=" + AIB_EventPos(this.getPosition()));
		this.set_u8("ai builder state", 1);
		this.set_u8("ai builder job", 0);
		this.set_netid("ai builder target", 0);
		this.set_Vec2f("ai builder destination", Vec2f_zero);
		this.Sync("ai builder state", true);
	}
	else if (cmd == this.getCommandID("ai mine stone") && isServer())
	{
		AIB_LogEvent("player", "command", AIB_EventBlobRef(this), "command=mine_stone pos=" + AIB_EventPos(this.getPosition()));
		this.set_u8("ai builder state", 7);
		this.set_u8("ai builder job", 1);
		this.set_netid("ai builder target", 0);
		this.set_Vec2f("ai builder destination", Vec2f_zero);
		this.set_Vec2f("ai builder tile target", Vec2f_zero);
		this.set_Vec2f("ai builder shaft top", Vec2f_zero);
		this.Sync("ai builder state", true);
	}
	else if (cmd == this.getCommandID("ai build blueprint") && isServer())
	{
		AIB_LogEvent("player", "command", AIB_EventBlobRef(this), "command=build_blueprint pos=" + AIB_EventPos(this.getPosition()));
		this.set_u8("ai builder state", 12);
		this.set_u8("ai builder job", 2);
		this.set_netid("ai builder target", 0);
		this.set_Vec2f("ai builder destination", Vec2f_zero);
		this.set_Vec2f("ai builder tile target", Vec2f_zero);
		this.set_Vec2f("ai builder shaft top", Vec2f_zero);
		this.Sync("ai builder state", true);
	}
}
