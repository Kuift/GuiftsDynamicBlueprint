# KAG Engine API Usage Inventory

Installed interface build: **4762**
Scanned AngelScript files: **54**

> Counts are lexical call-like matches. A member name shared by several
> engine types is intentionally shown under each possible owner; this is
> a prioritization map, not full AngelScript type inference.

## Priority surface

| Engine type | Call-like references | Used methods | Published methods |
|---|---:|---:|---:|
| `CBrain` | 70 | 13 | 32 |
| `CBlob` | 4322 | 110 | 253 |
| `CMap` | 3233 | 64 | 168 |
| `CInventory` | 91 | 12 | 19 |
| `CRules` | 2924 | 43 | 85 |
| `CShape` | 446 | 17 | 53 |
| `CNet` | 15 | 2 | 11 |
| `CBitStream` | 311 | 16 | 66 |
| `CPlayer` | 3190 | 44 | 109 |
| `CCamera` | 393 | 3 | 9 |
| `CSprite` | 58 | 13 | 83 |
| `CControls` | 169 | 7 | 23 |
| `Driver` | 21 | 5 | 24 |
| `SMesh` | 20 | 7 | 13 |
| `SMaterial` | 6 | 4 | 20 |

## CBrain

| Method | References | Files | Published signatures |
|---|---:|---:|---|
| `EndPath` | 22 | 2 | `void EndPath()` |
| `getBlob` | 12 | 8 | `CBlob@ getBlob()` |
| `getState` | 8 | 1 | `CBrain::BrainState getState()` |
| `SetTarget` | 7 | 1 | `void SetTarget(CBlob@ blob)` |
| `getCurrentScript` | 4 | 2 | `ScriptData@ getCurrentScript()` |
| `getVars` | 4 | 3 | `BrainVars@ getVars()` |
| `server_SetActive` | 4 | 2 | `void server_SetActive(bool active)` |
| `AddScript` | 2 | 2 | `bool AddScript(const string&in fileName)` |
| `SetSuggestedKeys` | 2 | 1 | `void SetSuggestedKeys()` |
| `getPathSize` | 2 | 1 | `int getPathSize()` |
| `SetPathTo` | 1 | 1 | `void SetPathTo(Vec2f endpoint, bool ignoreGravity)`<br>`void SetPathTo(Vec2f endpoint, int search_style)` |
| `getPathPositionAtIndex` | 1 | 1 | `Vec2f getPathPositionAtIndex(int index)` |
| `hasScript` | 1 | 1 | `bool hasScript(const string&in fileName)` |

## CBlob

| Method | References | Files | Published signatures |
|---|---:|---:|---|
| `getPosition` | 368 | 24 | `Vec2f getPosition()` |
| `get_u16` | 266 | 21 | `uint16 get_u16(const string&in)` |
| `set_bool` | 261 | 19 | `void set_bool(const string&in, bool v)` |
| `set_u16` | 218 | 14 | `void set_u16(const string&in, uint16 v)` |
| `getTeamNum` | 215 | 26 | `int getTeamNum()` |
| `get_u8` | 209 | 19 | `uint8 get_u8(const string&in)` |
| `get_bool` | 202 | 18 | `bool get_bool(const string&in)` |
| `set_u32` | 181 | 22 | `void set_u32(const string&in, uint v)` |
| `set_u8` | 172 | 18 | `void set_u8(const string&in, uint8 v)` |
| `hasTag` | 165 | 23 | `bool hasTag(const string&in name)` |
| `getNetworkID` | 144 | 19 | `uint16 getNetworkID()` |
| `get_u32` | 124 | 14 | `uint get_u32(const string&in)` |
| `set` | 120 | 17 | `void set(const string&in, ?&in)`<br>`void set(const string&in, double&in)`<br>`void set(const string&in, int64&in)` |
| `set_Vec2f` | 109 | 12 | `void set_Vec2f(const string&in, Vec2f v)` |
| `set_string` | 101 | 14 | `void set_string(const string&in, string v)` |
| `setKeyPressed` | 93 | 5 | `void setKeyPressed(keys key, bool pressed)` |
| `Sync` | 92 | 19 | `void Sync(const string&in name, bool relayToClients)` |
| `getName` | 92 | 26 | `const string& getName()` |
| `isKeyPressed` | 82 | 7 | `bool isKeyPressed(keys key)` |
| `set_netid` | 78 | 11 | `void set_netid(const string&in, uint16 v)` |
| `get` | 73 | 13 | `bool get(const string&in, ?&out) const`<br>`bool get(const string&in, double&out) const`<br>`bool get(const string&in, int64&out) const` |
| `get_string` | 72 | 12 | `string get_string(const string&in)` |
| `Tag` | 65 | 12 | `void Tag(const string&in name)` |
| `getCommandID` | 61 | 9 | `uint8 getCommandID(const string&in name)` |
| `get_Vec2f` | 54 | 10 | `Vec2f get_Vec2f(const string&in)` |
| `clear` | 49 | 12 | `void clear(const string&in)` |
| `get_netid` | 47 | 10 | `uint16 get_netid(const string&in)` |
| `getInventory` | 36 | 10 | `CInventory@ getInventory()` |
| `getShape` | 34 | 13 | `CShape@ getShape()` |
| `set_f32` | 34 | 7 | `void set_f32(const string&in, float v)` |
| `isKeyJustPressed` | 33 | 4 | `bool isKeyJustPressed(keys key)` |
| `SendCommand` | 27 | 7 | `void SendCommand(uint8 cmd)`<br>`void SendCommand(uint8 cmd, CBitStream&in params)` |
| `addCommandID` | 26 | 5 | `uint8 addCommandID(const string&in name)` |
| `exists` | 25 | 15 | `bool exists(const string&in)` |
| `getCarriedBlob` | 23 | 6 | `CBlob@ getCarriedBlob()` |
| `get_f32` | 20 | 6 | `float get_f32(const string&in)` |
| `server_Die` | 18 | 5 | `void server_Die()` |
| `setPosition` | 18 | 6 | `void setPosition(Vec2f pos)` |
| `server_PutInInventory` | 17 | 6 | `bool server_PutInInventory(CBlob@ blob)` |
| `setAimPos` | 17 | 3 | `void setAimPos(Vec2f aimpos)` |
| `isInInventory` | 16 | 6 | `bool isInInventory()` |
| `server_SetQuantity` | 16 | 7 | `void server_SetQuantity(int quantity)` |
| `setVelocity` | 15 | 4 | `void setVelocity(Vec2f vel)` |
| `removeAt` | 14 | 6 | `void removeAt(const string&in, int index)` |
| `getSprite` | 12 | 5 | `CSprite@ getSprite()` |
| `isAttached` | 12 | 5 | `bool isAttached()` |
| `getQuantity` | 11 | 7 | `uint16 getQuantity()` |
| `server_Pickup` | 10 | 1 | `bool server_Pickup(CBlob@ blob)` |
| `getHealth` | 9 | 5 | `float getHealth()` |
| `isInWater` | 9 | 3 | `bool isInWater()` |
| `get_s16` | 8 | 3 | `int16 get_s16(const string&in)` |
| `set_s32` | 8 | 3 | `void set_s32(const string&in, int v)` |
| `getDistanceTo` | 7 | 3 | `float getDistanceTo(CBlob@ other)` |
| `get_s32` | 7 | 3 | `int get_s32(const string&in)` |
| `set_s16` | 7 | 3 | `void set_s16(const string&in, int16 v)` |
| `CreateGenericButton` | 6 | 3 | `CButton@ CreateGenericButton(const string&in iconName, Vec2f _offset, CBlob@ attached, CallbackButtonFunc@ cb, const string&in)`<br>`CButton@ CreateGenericButton(const string&in iconName, Vec2f _offset, CBlob@ attached, uint8 cmdID, const string&in)`<br>`CButton@ CreateGenericButton(const string&in iconName, Vec2f _offset, CBlob@ attached, uint8 cmdID, const string&in, CBitStream&in parameters)`<br>`CButton@ CreateGenericButton(int _frameNum, Vec2f _offset, CBlob@ attached, CallbackButtonFunc@ cb, const string&in)`<br>`CButton@ CreateGenericButton(int _frameNum, Vec2f _offset, CBlob@ attached, uint8 cmdID, const string&in)`<br>`CButton@ CreateGenericButton(int _frameNum, Vec2f _offset, CBlob@ attached, uint8 cmdID, const string&in, CBitStream&in parameters)` |
| `isOnLadder` | 6 | 2 | `bool isOnLadder()` |
| `server_PutOutInventory` | 5 | 1 | `CBlob@ server_PutOutInventory(const string&in name)`<br>`bool server_PutOutInventory(CBlob@ blob)` |
| `Untag` | 4 | 4 | `void Untag(const string&in name)` |
| `getAngleDegrees` | 4 | 4 | `float getAngleDegrees()` |
| `getBrain` | 4 | 3 | `CBrain@ getBrain()` |
| `getCurrentScript` | 4 | 2 | `ScriptData@ getCurrentScript()` |
| `getRadius` | 4 | 2 | `float getRadius()` |
| `getVelocity` | 4 | 2 | `Vec2f getVelocity()` |
| `isCollidable` | 4 | 3 | `bool isCollidable()` |
| `server_SetActive` | 4 | 2 | `void server_SetActive(bool active)` |
| `getInitialHealth` | 3 | 2 | `float getInitialHealth()` |
| `get_TileType` | 3 | 3 | `uint16 get_TileType(const string&in)` |
| `isPlatform` | 3 | 3 | `bool isPlatform()` |
| `server_DetachFrom` | 3 | 2 | `bool server_DetachFrom(CBlob@ blob)` |
| `set_CBitStream` | 3 | 1 | `void set_CBitStream(const string&in, CBitStream&inout bs)` |
| `set_TileType` | 3 | 3 | `void set_TileType(const string&in, uint16 v)` |
| `AddScript` | 2 | 2 | `bool AddScript(const string&in fileName)` |
| `Init` | 2 | 2 | `void Init()` |
| `getAimPos` | 2 | 2 | `Vec2f getAimPos()` |
| `getAttachments` | 2 | 1 | `CAttachment@ getAttachments()` |
| `getInterpolatedPosition` | 2 | 2 | `Vec2f getInterpolatedPosition()` |
| `getOldPosition` | 2 | 1 | `Vec2f getOldPosition()` |
| `getPlayer` | 2 | 2 | `CPlayer@ getPlayer()` |
| `getTickSinceCreated` | 2 | 1 | `int getTickSinceCreated()` |
| `isAttachedToPoint` | 2 | 1 | `bool isAttachedToPoint(const string&in name)` |
| `isMyPlayer` | 2 | 2 | `bool isMyPlayer()` |
| `isOnGround` | 2 | 2 | `bool isOnGround()` |
| `isOnWall` | 2 | 1 | `bool isOnWall()` |
| `isOverlapping` | 2 | 2 | `bool isOverlapping(CBlob@ blob)`<br>`bool isOverlapping(const string&in name)` |
| `server_setTeamNum` | 2 | 2 | `void server_setTeamNum(int team)` |
| `setAngleDegrees` | 2 | 1 | `void setAngleDegrees(float angle)` |
| `AddForce` | 1 | 1 | `void AddForce(Vec2f force)` |
| `ClearMenus` | 1 | 1 | `void ClearMenus()` |
| `SetFacingLeft` | 1 | 1 | `void SetFacingLeft(bool left)` |
| `SetLight` | 1 | 1 | `void SetLight(bool on)` |
| `SetLightColor` | 1 | 1 | `void SetLightColor(SColor new_color)` |
| `SetLightRadius` | 1 | 1 | `void SetLightRadius(float new_radius)` |
| `SyncToPlayer` | 1 | 1 | `void SyncToPlayer(const string&in name, CPlayer@ player)` |
| `doesCollideWithBlob` | 1 | 1 | `bool doesCollideWithBlob(CBlob@ blob)` |
| `getConfig` | 1 | 1 | `string getConfig()` |
| `getDamageOwnerPlayer` | 1 | 1 | `CPlayer@ getDamageOwnerPlayer()` |
| `getHeight` | 1 | 1 | `float getHeight()` |
| `getOverlapping` | 1 | 1 | `bool getOverlapping(CBlob@[]@ list)` |
| `getPlayerOfRecentDamage` | 1 | 1 | `CPlayer@ getPlayerOfRecentDamage()` |
| `getScreenPos` | 1 | 1 | `Vec2f getScreenPos()` |
| `getWidth` | 1 | 1 | `float getWidth()` |
| `get_CBitStream` | 1 | 1 | `void get_CBitStream(const string&in, CBitStream&inout bs)` |
| `hasScript` | 1 | 1 | `bool hasScript(const string&in fileName)` |
| `isLadder` | 1 | 1 | `bool isLadder()` |
| `push` | 1 | 1 | `void push(const string&in, ?&in)` |
| `server_AttachTo` | 1 | 1 | `bool server_AttachTo(CBlob@ blob, AttachmentPoint@ ap)`<br>`bool server_AttachTo(CBlob@ blob, const string&in name)`<br>`bool server_AttachTo(CBlob@ blob, int attachment_index)` |
| `server_DetachFromAll` | 1 | 1 | `void server_DetachFromAll()` |
| `server_Hit` | 1 | 1 | `void server_Hit(CBlob@ blob, Vec2f worldPoint, Vec2f velocity, float damage, uint8 customData)`<br>`void server_Hit(CBlob@ blob, Vec2f worldPoint, Vec2f velocity, float damage, uint8 customData, bool hurtTeamMate)` |
| `server_SetHealth` | 1 | 1 | `void server_SetHealth(float amount)` |

## CMap

| Method | References | Files | Published signatures |
|---|---:|---:|---|
| `get_u16` | 266 | 21 | `uint16 get_u16(const string&in)` |
| `set_bool` | 261 | 19 | `void set_bool(const string&in, bool v)` |
| `set_u16` | 218 | 14 | `void set_u16(const string&in, uint16 v)` |
| `get_u8` | 209 | 19 | `uint8 get_u8(const string&in)` |
| `get_bool` | 202 | 18 | `bool get_bool(const string&in)` |
| `set_u32` | 181 | 22 | `void set_u32(const string&in, uint v)` |
| `set_u8` | 172 | 18 | `void set_u8(const string&in, uint8 v)` |
| `hasTag` | 165 | 23 | `bool hasTag(const string&in name)` |
| `getTile` | 126 | 14 | `Tile getTile(Vec2f posWorldspace)`<br>`Tile getTile(uint offset)` |
| `get_u32` | 124 | 14 | `uint get_u32(const string&in)` |
| `set` | 120 | 17 | `void set(const string&in, ?&in)`<br>`void set(const string&in, double&in)`<br>`void set(const string&in, int64&in)` |
| `set_Vec2f` | 109 | 12 | `void set_Vec2f(const string&in, Vec2f v)` |
| `set_string` | 101 | 14 | `void set_string(const string&in, string v)` |
| `Sync` | 92 | 19 | `void Sync(const string&in name, bool relayToClients)` |
| `isTileSolid` | 90 | 14 | `bool isTileSolid(Vec2f posWorldspace)`<br>`bool isTileSolid(const Tile&in tile)`<br>`bool isTileSolid(uint16 tile)` |
| `set_netid` | 78 | 11 | `void set_netid(const string&in, uint16 v)` |
| `get` | 73 | 13 | `bool get(const string&in, ?&out) const`<br>`bool get(const string&in, double&out) const`<br>`bool get(const string&in, int64&out) const` |
| `get_string` | 72 | 12 | `string get_string(const string&in)` |
| `Tag` | 65 | 12 | `void Tag(const string&in name)` |
| `get_Vec2f` | 54 | 10 | `Vec2f get_Vec2f(const string&in)` |
| `clear` | 49 | 12 | `void clear(const string&in)` |
| `get_netid` | 47 | 10 | `uint16 get_netid(const string&in)` |
| `getTileSpacePosition` | 41 | 9 | `Vec2f getTileSpacePosition(Vec2f posWorldspace)`<br>`Vec2f getTileSpacePosition(uint offset)` |
| `set_f32` | 34 | 7 | `void set_f32(const string&in, float v)` |
| `exists` | 25 | 15 | `bool exists(const string&in)` |
| `getSectorAtPosition` | 22 | 8 | `CMap::Sector@ getSectorAtPosition(Vec2f posWorldspace)`<br>`CMap::Sector@ getSectorAtPosition(Vec2f posWorldspace, const string&in name)` |
| `get_f32` | 20 | 6 | `float get_f32(const string&in)` |
| `server_SetTile` | 15 | 3 | `void server_SetTile(Vec2f posWorldspace, const Tile&in tile)`<br>`void server_SetTile(Vec2f posWorldspace, const uint16 type)` |
| `isTileCastle` | 14 | 1 | `bool isTileCastle(uint16 tile)` |
| `removeAt` | 14 | 6 | `void removeAt(const string&in, int index)` |
| `getBlobsInRadius` | 12 | 4 | `bool getBlobsInRadius(Vec2f posWorldspace, float radius, CBlob@[]@ list)` |
| `getTileWorldPosition` | 12 | 4 | `Vec2f getTileWorldPosition(Vec2f posWorldspace)`<br>`Vec2f getTileWorldPosition(uint offset)` |
| `isTileBedrock` | 12 | 7 | `bool isTileBedrock(uint16 tile)` |
| `isTileStone` | 12 | 6 | `bool isTileStone(uint16 tile)` |
| `isTileGround` | 11 | 5 | `bool isTileGround(uint16 tile)` |
| `rayCastSolid` | 10 | 2 | `bool rayCastSolid(Vec2f startPosWorldspace, Vec2f endPosWorldspace)`<br>`bool rayCastSolid(Vec2f startPosWorldspace, Vec2f endPosWorldspace, Vec2f&out pointPosWorldspace)` |
| `isInWater` | 9 | 3 | `bool isInWater(Vec2f posWorldspace)` |
| `isTileThickStone` | 9 | 5 | `bool isTileThickStone(uint16 tile)` |
| `get_s16` | 8 | 3 | `int16 get_s16(const string&in)` |
| `set_s32` | 8 | 3 | `void set_s32(const string&in, int v)` |
| `get_s32` | 7 | 3 | `int get_s32(const string&in)` |
| `isTileGold` | 7 | 3 | `bool isTileGold(uint16 tile)` |
| `set_s16` | 7 | 3 | `void set_s16(const string&in, int16 v)` |
| `getBlobsInBox` | 5 | 3 | `bool getBlobsInBox(Vec2f upperleftWorldspace, Vec2f lowerrightWorldspace, CBlob@[]@ list)` |
| `hasSupportAtPos` | 5 | 3 | `bool hasSupportAtPos(Vec2f posWorldspace)` |
| `isTileGrass` | 5 | 2 | `bool isTileGrass(uint16 tile)` |
| `Untag` | 4 | 4 | `void Untag(const string&in name)` |
| `getMapDimensions` | 4 | 2 | `Vec2f getMapDimensions()` |
| `getMapName` | 3 | 3 | `string getMapName()` |
| `get_TileType` | 3 | 3 | `uint16 get_TileType(const string&in)` |
| `set_CBitStream` | 3 | 1 | `void set_CBitStream(const string&in, CBitStream&inout bs)` |
| `set_TileType` | 3 | 3 | `void set_TileType(const string&in, uint16 v)` |
| `AddScript` | 2 | 2 | `bool AddScript(const string&in fileName)` |
| `getColorLight` | 2 | 1 | `SColor getColorLight(Vec2f pos)` |
| `server_DestroyTile` | 2 | 1 | `void server_DestroyTile(Vec2f posWorldspace, float damage)`<br>`void server_DestroyTile(Vec2f posWorldspace, float damage, CBlob@ damager)` |
| `RemoveSectorsAtPosition` | 1 | 1 | `void RemoveSectorsAtPosition(Vec2f posWorldspace)`<br>`void RemoveSectorsAtPosition(Vec2f posWorldspace, const string&in name)`<br>`void RemoveSectorsAtPosition(Vec2f posWorldspace, const string&in name, const uint16 id)` |
| `SyncToPlayer` | 1 | 1 | `void SyncToPlayer(const string&in name, CPlayer@ player)` |
| `getAlignedWorldPos` | 1 | 1 | `Vec2f getAlignedWorldPos(Vec2f posWorldspace)` |
| `getBlobsAtPosition` | 1 | 1 | `bool getBlobsAtPosition(Vec2f posWorldspace, CBlob@[]@ list)` |
| `get_CBitStream` | 1 | 1 | `void get_CBitStream(const string&in, CBitStream&inout bs)` |
| `hasScript` | 1 | 1 | `bool hasScript(const string&in fileName)` |
| `push` | 1 | 1 | `void push(const string&in, ?&in)` |
| `server_AddSector` | 1 | 1 | `CMap::Sector@ server_AddSector(Vec2f posWorldspace, float radius, const string&in name)`<br>`CMap::Sector@ server_AddSector(Vec2f posWorldspace, float radius, const string&in name, const string&in scriptFilename)`<br>`CMap::Sector@ server_AddSector(Vec2f posWorldspace, float radius, const string&in name, const string&in scriptFilename, uint16 ownerID)`<br>`CMap::Sector@ server_AddSector(Vec2f upperleftPosWorldspace, Vec2f lowerrightPosWorldspace, const string&in name)`<br>`CMap::Sector@ server_AddSector(Vec2f upperleftPosWorldspace, Vec2f lowerrightPosWorldspace, const string&in name, const string&in scriptFilename)`<br>`CMap::Sector@ server_AddSector(Vec2f upperleftPosWorldspace, Vec2f lowerrightPosWorldspace, const string&in name, const string&in scriptFilename, uint16 ownerID)` |
| `server_setFloodWaterWorldspace` | 1 | 1 | `void server_setFloodWaterWorldspace(Vec2f posWorldspace, bool water)` |

## CInventory

| Method | References | Files | Published signatures |
|---|---:|---:|---|
| `getCount` | 19 | 7 | `int getCount(const string&in name)` |
| `isInInventory` | 16 | 6 | `bool isInInventory(CBlob@ blob)`<br>`bool isInInventory(const string&in, int)` |
| `getBlob` | 12 | 8 | `CBlob@ getBlob()` |
| `getItem` | 12 | 5 | `CBlob@ getItem(const string&in)`<br>`CBlob@ getItem(int index)` |
| `getItemsCount` | 12 | 5 | `int getItemsCount()` |
| `getCurrentScript` | 4 | 2 | `ScriptData@ getCurrentScript()` |
| `server_RemoveItems` | 4 | 2 | `int server_RemoveItems(const string&in blobName, int quantity)` |
| `server_SetActive` | 4 | 2 | `void server_SetActive(bool active)` |
| `canPutItem` | 3 | 2 | `bool canPutItem(CBlob@ blob)` |
| `AddScript` | 2 | 2 | `bool AddScript(const string&in fileName)` |
| `isFull` | 2 | 1 | `bool isFull()` |
| `hasScript` | 1 | 1 | `bool hasScript(const string&in fileName)` |

## CRules

| Method | References | Files | Published signatures |
|---|---:|---:|---|
| `get_u16` | 266 | 21 | `uint16 get_u16(const string&in)` |
| `set_bool` | 261 | 19 | `void set_bool(const string&in, bool v)` |
| `set_u16` | 218 | 14 | `void set_u16(const string&in, uint16 v)` |
| `get_u8` | 209 | 19 | `uint8 get_u8(const string&in)` |
| `get_bool` | 202 | 18 | `bool get_bool(const string&in)` |
| `set_u32` | 181 | 22 | `void set_u32(const string&in, uint v)` |
| `set_u8` | 172 | 18 | `void set_u8(const string&in, uint8 v)` |
| `hasTag` | 165 | 23 | `bool hasTag(const string&in name)` |
| `get_u32` | 124 | 14 | `uint get_u32(const string&in)` |
| `set` | 120 | 17 | `void set(const string&in, ?&in)`<br>`void set(const string&in, double&in)`<br>`void set(const string&in, int64&in)` |
| `set_Vec2f` | 109 | 12 | `void set_Vec2f(const string&in, Vec2f v)` |
| `set_string` | 101 | 14 | `void set_string(const string&in, string v)` |
| `Sync` | 92 | 19 | `void Sync(const string&in name, bool relayToClients)` |
| `set_netid` | 78 | 11 | `void set_netid(const string&in, uint16 v)` |
| `get` | 73 | 13 | `bool get(const string&in, ?&out) const`<br>`bool get(const string&in, double&out) const`<br>`bool get(const string&in, int64&out) const` |
| `get_string` | 72 | 12 | `string get_string(const string&in)` |
| `Tag` | 65 | 12 | `void Tag(const string&in name)` |
| `getCommandID` | 61 | 9 | `uint8 getCommandID(const string&in name)` |
| `get_Vec2f` | 54 | 10 | `Vec2f get_Vec2f(const string&in)` |
| `clear` | 49 | 12 | `void clear(const string&in)` |
| `get_netid` | 47 | 10 | `uint16 get_netid(const string&in)` |
| `set_f32` | 34 | 7 | `void set_f32(const string&in, float v)` |
| `SendCommand` | 27 | 7 | `void SendCommand(uint8 cmd, CBitStream&in params)`<br>`void SendCommand(uint8 cmd, CBitStream&in params, CPlayer@ player)`<br>`void SendCommand(uint8 cmd, CBitStream&in params, bool sendToClients)` |
| `addCommandID` | 26 | 5 | `uint8 addCommandID(const string&in name)` |
| `exists` | 25 | 15 | `bool exists(const string&in)` |
| `get_f32` | 20 | 6 | `float get_f32(const string&in)` |
| `removeAt` | 14 | 6 | `void removeAt(const string&in, int index)` |
| `get_s16` | 8 | 3 | `int16 get_s16(const string&in)` |
| `set_s32` | 8 | 3 | `void set_s32(const string&in, int v)` |
| `SetCurrentState` | 7 | 3 | `void SetCurrentState(uint8 state)` |
| `get_s32` | 7 | 3 | `int get_s32(const string&in)` |
| `set_s16` | 7 | 3 | `void set_s16(const string&in, int16 v)` |
| `Untag` | 4 | 4 | `void Untag(const string&in name)` |
| `get_TileType` | 3 | 3 | `uint16 get_TileType(const string&in)` |
| `set_CBitStream` | 3 | 1 | `void set_CBitStream(const string&in, CBitStream&inout bs)` |
| `set_TileType` | 3 | 3 | `void set_TileType(const string&in, uint16 v)` |
| `AddScript` | 2 | 2 | `bool AddScript(const string&in fileName)` |
| `isMatchRunning` | 2 | 2 | `bool isMatchRunning()` |
| `SyncToPlayer` | 1 | 1 | `void SyncToPlayer(const string&in name, CPlayer@ player)` |
| `getCurrentState` | 1 | 1 | `uint8 getCurrentState()` |
| `get_CBitStream` | 1 | 1 | `void get_CBitStream(const string&in, CBitStream&inout bs)` |
| `hasScript` | 1 | 1 | `bool hasScript(const string&in fileName)` |
| `push` | 1 | 1 | `void push(const string&in, ?&in)` |

## CShape

| Method | References | Files | Published signatures |
|---|---:|---:|---|
| `getPosition` | 368 | 24 | `Vec2f getPosition()` |
| `getConsts` | 17 | 8 | `ShapeConsts@ getConsts()` |
| `getBlob` | 12 | 8 | `CBlob@ getBlob()` |
| `getBoundingRect` | 7 | 5 | `void getBoundingRect(Vec2f&out topLeft, Vec2f&out bottomRight)` |
| `SetGravityScale` | 6 | 2 | `void SetGravityScale(float scale)` |
| `SetStatic` | 5 | 2 | `void SetStatic(bool static)` |
| `getAngleDegrees` | 4 | 4 | `float getAngleDegrees()` |
| `getCurrentScript` | 4 | 2 | `ScriptData@ getCurrentScript()` |
| `getVars` | 4 | 3 | `ShapeVars@ getVars()` |
| `getVelocity` | 4 | 2 | `Vec2f getVelocity()` |
| `isStatic` | 4 | 4 | `bool isStatic()` |
| `server_SetActive` | 4 | 2 | `void server_SetActive(bool active)` |
| `AddScript` | 2 | 2 | `bool AddScript(const string&in fileName)` |
| `getPlatformDirection` | 2 | 2 | `ShapePlatformDirection@ getPlatformDirection(int index)` |
| `getHeight` | 1 | 1 | `float getHeight()` |
| `getWidth` | 1 | 1 | `float getWidth()` |
| `hasScript` | 1 | 1 | `bool hasScript(const string&in fileName)` |

## CNet

| Method | References | Files | Published signatures |
|---|---:|---:|---|
| `getActiveCommandPlayer` | 11 | 3 | `CPlayer@ getActiveCommandPlayer()` |
| `isServer` | 4 | 3 | `bool isServer()` |

## CBitStream

| Method | References | Files | Published signatures |
|---|---:|---:|---|
| `Length` | 140 | 16 | `uint Length()` |
| `read_u16` | 40 | 1 | `uint16 read_u16()` |
| `write_u16` | 39 | 2 | `void write_u16(uint16 v)` |
| `read_f32` | 29 | 1 | `float read_f32()` |
| `write_u8` | 16 | 3 | `void write_u8(uint8 v)` |
| `saferead_u16` | 10 | 3 | `bool saferead_u16(uint16&out)` |
| `read_u8` | 9 | 2 | `uint8 read_u8()` |
| `read_string` | 6 | 4 | `string read_string()` |
| `saferead_string` | 5 | 4 | `bool saferead_string(string&out)` |
| `write_string` | 5 | 3 | `void write_string(string str)` |
| `read_s32` | 4 | 3 | `int read_s32()` |
| `read_bool` | 3 | 2 | `bool read_bool()` |
| `Reset` | 2 | 1 | `void Reset()` |
| `getBytesUsed` | 1 | 1 | `uint getBytesUsed()` |
| `isBufferEnd` | 1 | 1 | `bool isBufferEnd()` |
| `write_netid` | 1 | 1 | `void write_netid(uint16 v)` |

## CPlayer

| Method | References | Files | Published signatures |
|---|---:|---:|---|
| `get_u16` | 266 | 21 | `uint16 get_u16(const string&in)` |
| `set_bool` | 261 | 19 | `void set_bool(const string&in, bool v)` |
| `set_u16` | 218 | 14 | `void set_u16(const string&in, uint16 v)` |
| `getTeamNum` | 215 | 26 | `int getTeamNum()` |
| `get_u8` | 209 | 19 | `uint8 get_u8(const string&in)` |
| `get_bool` | 202 | 18 | `bool get_bool(const string&in)` |
| `set_u32` | 181 | 22 | `void set_u32(const string&in, uint v)` |
| `set_u8` | 172 | 18 | `void set_u8(const string&in, uint8 v)` |
| `hasTag` | 165 | 23 | `bool hasTag(const string&in name)` |
| `getNetworkID` | 144 | 19 | `uint16 getNetworkID()` |
| `get_u32` | 124 | 14 | `uint get_u32(const string&in)` |
| `set` | 120 | 17 | `void set(const string&in, ?&in)`<br>`void set(const string&in, double&in)`<br>`void set(const string&in, int64&in)` |
| `set_Vec2f` | 109 | 12 | `void set_Vec2f(const string&in, Vec2f v)` |
| `set_string` | 101 | 14 | `void set_string(const string&in, string v)` |
| `Sync` | 92 | 19 | `void Sync(const string&in name, bool relayToClients)` |
| `set_netid` | 78 | 11 | `void set_netid(const string&in, uint16 v)` |
| `get` | 73 | 13 | `bool get(const string&in, ?&out) const`<br>`bool get(const string&in, double&out) const`<br>`bool get(const string&in, int64&out) const` |
| `get_string` | 72 | 12 | `string get_string(const string&in)` |
| `Tag` | 65 | 12 | `void Tag(const string&in name)` |
| `get_Vec2f` | 54 | 10 | `Vec2f get_Vec2f(const string&in)` |
| `clear` | 49 | 12 | `void clear(const string&in)` |
| `get_netid` | 47 | 10 | `uint16 get_netid(const string&in)` |
| `set_f32` | 34 | 7 | `void set_f32(const string&in, float v)` |
| `exists` | 25 | 15 | `bool exists(const string&in)` |
| `get_f32` | 20 | 6 | `float get_f32(const string&in)` |
| `removeAt` | 14 | 6 | `void removeAt(const string&in, int index)` |
| `getBlob` | 12 | 8 | `CBlob@ getBlob()` |
| `get_s16` | 8 | 3 | `int16 get_s16(const string&in)` |
| `isMod` | 8 | 1 | `bool isMod()` |
| `set_s32` | 8 | 3 | `void set_s32(const string&in, int v)` |
| `get_s32` | 7 | 3 | `int get_s32(const string&in)` |
| `set_s16` | 7 | 3 | `void set_s16(const string&in, int16 v)` |
| `Untag` | 4 | 4 | `void Untag(const string&in name)` |
| `getUsername` | 4 | 3 | `string getUsername()` |
| `getCoins` | 3 | 2 | `int getCoins()` |
| `get_TileType` | 3 | 3 | `uint16 get_TileType(const string&in)` |
| `server_setCoins` | 3 | 1 | `void server_setCoins(int)` |
| `set_CBitStream` | 3 | 1 | `void set_CBitStream(const string&in, CBitStream&inout bs)` |
| `set_TileType` | 3 | 3 | `void set_TileType(const string&in, uint16 v)` |
| `isMyPlayer` | 2 | 2 | `bool isMyPlayer()` |
| `server_setTeamNum` | 2 | 2 | `void server_setTeamNum(uint8 team)` |
| `SyncToPlayer` | 1 | 1 | `void SyncToPlayer(const string&in name, CPlayer@ player)` |
| `get_CBitStream` | 1 | 1 | `void get_CBitStream(const string&in, CBitStream&inout bs)` |
| `push` | 1 | 1 | `void push(const string&in, ?&in)` |

## CCamera

| Method | References | Files | Published signatures |
|---|---:|---:|---|
| `getPosition` | 368 | 24 | `Vec2f getPosition()` |
| `setPosition` | 18 | 6 | `void setPosition(Vec2f pos)` |
| `setTarget` | 7 | 2 | `void setTarget(CBlob@ blob)` |

## CSprite

| Method | References | Files | Published signatures |
|---|---:|---:|---|
| `getConsts` | 17 | 8 | `SpriteConsts@ getConsts()` |
| `getBlob` | 12 | 8 | `CBlob@ getBlob()` |
| `PlaySound` | 4 | 3 | `void PlaySound(const string&in filename)`<br>`void PlaySound(const string&in filename, float volume)`<br>`void PlaySound(const string&in filename, float volume, float pitch)` |
| `SetZ` | 4 | 4 | `void SetZ(float z)` |
| `getCurrentScript` | 4 | 2 | `ScriptData@ getCurrentScript()` |
| `getVars` | 4 | 3 | `SpriteVars@ getVars()` |
| `server_SetActive` | 4 | 2 | `void server_SetActive(bool active)` |
| `AddScript` | 2 | 2 | `bool AddScript(const string&in fileName)` |
| `RotateBy` | 2 | 2 | `void RotateBy(float degrees, Vec2f around)` |
| `SetFrame` | 2 | 1 | `void SetFrame(uint16 sheetindex)` |
| `SetFacingLeft` | 1 | 1 | `void SetFacingLeft(bool left)` |
| `getZ` | 1 | 1 | `float getZ()` |
| `hasScript` | 1 | 1 | `bool hasScript(const string&in fileName)` |

## CControls

| Method | References | Files | Published signatures |
|---|---:|---:|---|
| `isKeyPressed` | 82 | 7 | `bool isKeyPressed(int keycode)` |
| `isKeyJustPressed` | 33 | 4 | `bool isKeyJustPressed(int keycode)` |
| `getMouseWorldPos` | 25 | 2 | `Vec2f getMouseWorldPos()` |
| `getMouseScreenPos` | 21 | 2 | `Vec2f getMouseScreenPos()` |
| `ActionKeyPressed` | 4 | 1 | `bool ActionKeyPressed(E_ACTIONKEYS action_key)` |
| `getActionKeyKey` | 3 | 2 | `int getActionKeyKey(E_ACTIONKEYS action_key)` |
| `getInterpMouseScreenPos` | 1 | 1 | `Vec2f getInterpMouseScreenPos()` |

## Driver

| Method | References | Files | Published signatures |
|---|---:|---:|---|
| `getScreenPosFromWorldPos` | 8 | 3 | `Vec2f getScreenPosFromWorldPos(Vec2f pos)` |
| `getScreenDimensions` | 7 | 3 | `Vec2f getScreenDimensions()` |
| `getScreenWidth` | 3 | 2 | `int getScreenWidth()` |
| `getScreenHeight` | 2 | 1 | `int getScreenHeight()` |
| `getScreenCenterPos` | 1 | 1 | `Vec2f getScreenCenterPos()` |

## SMesh

| Method | References | Files | Published signatures |
|---|---:|---:|---|
| `BuildMesh` | 4 | 1 | `void BuildMesh()` |
| `SetDirty` | 4 | 1 | `void SetDirty(SMesh::Buffer buffer)` |
| `SetIndices` | 3 | 1 | `void SetIndices(const uint16[]&in indices)` |
| `SetVertex` | 3 | 1 | `void SetVertex(const Vertex[]&in vertexs)` |
| `RenderMeshWithMaterial` | 2 | 1 | `void RenderMeshWithMaterial()` |
| `SetHardwareMapping` | 2 | 1 | `void SetHardwareMapping(SMesh::Map type)` |
| `SetMaterial` | 2 | 1 | `void SetMaterial(SMaterial@ material)` |

## SMaterial

| Method | References | Files | Published signatures |
|---|---:|---:|---|
| `SetFlag` | 3 | 1 | `void SetFlag(SMaterial::MFlag flag, bool newValue)` |
| `AddTexture` | 1 | 1 | `void AddTexture(const string&in texture)`<br>`void AddTexture(const string&in texture, uint8 layer)` |
| `DisableAllFlags` | 1 | 1 | `void DisableAllFlags()` |
| `SetMaterialType` | 1 | 1 | `void SetMaterialType(SMaterial::MType type)` |

## Most-used published global functions

| Function | References | Files |
|---|---:|---:|
| `getMap` | 262 | 19 |
| `getRules` | 248 | 25 |
| `getGameTime` | 142 | 24 |
| `Maths::Floor` | 116 | 11 |
| `Maths::Max` | 83 | 20 |
| `Maths::Min` | 76 | 21 |
| `print` | 70 | 15 |
| `isServer` | 64 | 18 |
| `getBlobsByName` | 59 | 14 |
| `Maths::Abs` | 51 | 13 |
| `server_CreateBlob` | 39 | 8 |
| `getBlobByNetworkID` | 33 | 9 |
| `getLocalPlayer` | 30 | 3 |
| `GUI::DrawRectangle` | 28 | 5 |
| `getControls` | 27 | 4 |
| `isClient` | 20 | 7 |
| `getBlobsByTag` | 18 | 6 |
| `getDriver` | 15 | 6 |
| `getNet` | 15 | 6 |
| `GUI::DrawText` | 14 | 3 |
| `GUI::DrawTextCentered` | 13 | 4 |
| `Maths::Round` | 13 | 6 |
| `Maths::Ceil` | 11 | 4 |
| `getTranslatedString` | 10 | 3 |
| `getPlayerByNetworkId` | 9 | 2 |
| `getBlobs` | 8 | 5 |
| `GUI::DrawCircle` | 7 | 3 |
| `Maths::Sin` | 7 | 2 |
| `getPlayer` | 7 | 3 |
| `getCamera` | 6 | 2 |
| `AddIconToken` | 5 | 3 |
| `Maths::Clamp` | 5 | 2 |
| `getLocalPlayerBlob` | 5 | 2 |
| `getPlayersCount` | 5 | 2 |
| `getScreenWidth` | 5 | 3 |
| `Render::addScript` | 4 | 2 |
| `GUI::DrawIcon` | 3 | 2 |
| `GUI::SetFont` | 3 | 3 |
| `Matrix::MakeIdentity` | 3 | 1 |
| `Render::RawQuads` | 3 | 1 |
| `Render::SetAlphaBlend` | 3 | 2 |
| `XORRandom` | 3 | 2 |
| `client_AddToChat` | 3 | 2 |
| `getScreenHeight` | 3 | 2 |
| `parseInt` | 3 | 1 |
| `GUI::GetTextDimensions` | 2 | 2 |
| `Render::RawTrianglesIndexed` | 2 | 1 |
| `Render::SetTransform` | 2 | 1 |
| `Texture::exists` | 2 | 2 |
| `getCurrentScriptName` | 2 | 1 |
| `getPlayerByUsername` | 2 | 1 |
| `getRenderApproximateCorrectionFactor` | 2 | 2 |
| `server_CreateBlobNoInit` | 2 | 2 |
| `tcpr` | 2 | 1 |
| `warn` | 2 | 1 |
| `AddBot` | 1 | 1 |
| `GUI::DrawArrow2D` | 1 | 1 |
| `GUI::DrawBubble` | 1 | 1 |
| `GUI::DrawIconByName` | 1 | 1 |
| `GUI::DrawLine2D` | 1 | 1 |

## Unresolved member-call names

These are usually mod-defined methods or calls on script-library types.
They are retained so a missing engine declaration is visible.

| Name | References |
|---|---:|
| `hasFlag` | 11 |
| `fCost` | 8 |
| `isPathing` | 4 |
| `serialize` | 3 |
| `addTeam` | 2 |
| `Render` | 1 |
| `SetPath` | 1 |
| `SetSuggestedAimPos` | 1 |
| `Tick` | 1 |
| `Update` | 1 |
| `consumesMouseInput` | 1 |
| `length` | 1 |
| `resizeGUI` | 1 |
