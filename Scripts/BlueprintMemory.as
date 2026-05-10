class RuntimeBlueprint
{
	string path;
	int16 width;
	int16 height;
	uint16[][] data;

	RuntimeBlueprint() {}

	RuntimeBlueprint(const string &in blueprintPath, int16 blueprintWidth, int16 blueprintHeight)
	{
		path = blueprintPath;
		width = blueprintWidth;
		height = blueprintHeight;
		uint16[][] empty(width, uint16[](height, 0));
		data = empty;
	}
}
