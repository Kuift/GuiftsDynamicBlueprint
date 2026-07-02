// AIBuilderShop.as

#include "ShopCommon.as"
#include "GenericButtonCommon.as"
#include "TeamIconToken.as"

void onInit(CBlob@ this)
{
	this.set_TileType("background tile", CMap::tile_wood_back);

	this.getSprite().SetZ(-50);
	this.getShape().getConsts().mapCollisions = false;

	ShopMadeItem@ onMadeItem = @onShopMadeItem;
	this.set("onShopMadeItem handle", @onMadeItem);

	this.Tag("has window");
	this.addCommandID("become overseer");
	this.getCurrentScript().runFlags |= Script::tick_hasattached;

	this.set_Vec2f("shop offset", Vec2f_zero);
	this.set_Vec2f("shop menu size", Vec2f(2, 2));
	this.set_string("shop description", "Deploy");
	this.set_u8("shop icon", 25);

	this.set_Vec2f("class offset", Vec2f(-6, 0));
	this.set_string("required class", "builder");

	AddIconToken("$aibuilder$", "AIBuilderMale.png", Vec2f(32, 32), 0);
	// Keep the action icon compact inside the generic round button.  The shop
	// frame used here previously was larger than the button and obscured nearby
	// interaction controls.
	AddIconToken("$aibuilder_overseer$", "FlagBase.png", Vec2f(8, 8), 0);

	ShopItem@ s = addShopItem(this, "Builder AI", "$aibuilder$", "aibuilder", "Deploys a builder AI. It can be ordered to harvest wood.", false);
	s.customButton = true;
	s.buttonwidth = 2;
	s.buttonheight = 1;
}

void GetButtonsFor(CBlob@ this, CBlob@ caller)
{
	if (!canSeeButtons(this, caller)) return;

	AttachmentPoint@ overseer = this.getAttachments().getAttachmentPointByName("OVERSEER");
	const bool canBecomeOverseer = caller.getTeamNum() == this.getTeamNum()
		&& caller.getDistanceTo(this) <= 40.0f
		&& !caller.isAttached()
		&& overseer !is null
		&& overseer.getOccupied() is null;
	if (canBecomeOverseer)
	{
		caller.CreateGenericButton("$aibuilder_overseer$", Vec2f(-6, 0), this,
			this.getCommandID("become overseer"), getTranslatedString("Become overseer"));
	}

	if (caller.getConfig() == this.get_string("required class") && !canBecomeOverseer)
	{
		this.set_Vec2f("shop offset", Vec2f_zero);
	}
	else
	{
		this.set_Vec2f("shop offset", Vec2f(6, 0));
	}
	this.set_bool("shop available", this.isOverlapping(caller));
}

void onShopMadeItem(CBitStream@ params)
{
	if (!isServer()) return;

	u16 this_id, caller_id, item_id;
	string name;

	if (!params.saferead_u16(this_id) || !params.saferead_u16(caller_id) || !params.saferead_u16(item_id) || !params.saferead_string(name))
	{
		return;
	}

	if (name != "aibuilder") return;

	CBlob@ caller = getBlobByNetworkID(caller_id);
	CBlob@ bot = getBlobByNetworkID(item_id);
	if (caller is null || bot is null) return;

	bot.server_setTeamNum(caller.getTeamNum());
	bot.setPosition(caller.getPosition() + Vec2f(0.0f, -8.0f));
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	if (cmd == this.getCommandID("become overseer") && isServer())
	{
		CPlayer@ player = getNet().getActiveCommandPlayer();
		CBlob@ caller = player is null ? null : player.getBlob();
		AttachmentPoint@ overseer = this.getAttachments().getAttachmentPointByName("OVERSEER");
		if (caller is null || caller.getTeamNum() != this.getTeamNum() || caller.isAttached()
			|| caller.getDistanceTo(this) > 40.0f || overseer is null || overseer.getOccupied() !is null)
		{
			return;
		}

		CBlob@ carried = caller.getCarriedBlob();
		if (carried !is null && !caller.server_PutInInventory(carried))
		{
			carried.server_DetachFrom(caller);
		}
		this.server_AttachTo(caller, "OVERSEER");
	}
	else if (cmd == this.getCommandID("shop made item client") && isClient())
	{
		this.getSprite().PlaySound("/ChaChing.ogg");
	}
}

void onAttach(CBlob@ this, CBlob@ attached, AttachmentPoint@ point)
{
	if (point.name != "OVERSEER") return;

	attached.getShape().getConsts().collidable = false;
	attached.Tag("seated");
	attached.setVelocity(Vec2f_zero);
	attached.SetFacingLeft(false);

	CSprite@ sprite = this.getSprite();
	if (sprite !is null) sprite.SetFrame(1);

	CSprite@ attachedSprite = attached.getSprite();
	if (attachedSprite !is null) attachedSprite.PlaySound("GetInVehicle.ogg");
}

void onDetach(CBlob@ this, CBlob@ detached, AttachmentPoint@ point)
{
	if (point.name != "OVERSEER") return;

	detached.getShape().getConsts().collidable = true;
	detached.Untag("seated");
	detached.AddForce(Vec2f(0.0f, -20.0f));

	CSprite@ sprite = this.getSprite();
	if (sprite !is null) sprite.SetFrame(0);
}
