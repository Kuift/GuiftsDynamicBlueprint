#include "Item.as"

shared class Inventory
{
	private Item@[] items;
	private uint maxItems;
	private Item@ selectedItem;
	private float displacementSpeed;
	private uint width;
	private uint height;
	private bool hasMoved;

	private Vec2f position;
	private Vec2f cellDim(40, 40);

	private string[] itemFilter;

	Inventory(Vec2f position, array<string> filenames, uint itemsPerRow)
	{
		this.hasMoved = false;
		int nbOfItem = filenames.size();

		if(itemsPerRow == 0)
		{
			itemsPerRow = 1;
		}

		this.position = position;
		this.width = itemsPerRow;

		if(nbOfItem < itemsPerRow)
		{
			this.width = nbOfItem;
		}

		this.height = 1+(nbOfItem)/(itemsPerRow);
		this.maxItems = nbOfItem;
		this.displacementSpeed = 0.5f;

		for (uint i = 0; i < maxItems; i++)
		{
			items.push_back(Item("Bp" + i, filenames[i]));
		}
	}
	void setPosition(Vec2f newpos)
	{
		position = newpos;
	}
	void SetItemFilter(string[] names)
	{
		itemFilter = names;
	}

	bool AddItem(Item@ item)
	{
		if (items.length < maxItems && canAddItem(item))
		{
			items.push_back(item);
			print("Added item: " + item.name);
			return true;
		}
		return false;
	}

	bool AddItem(Item@ item, uint index)
	{
		if (items.length < maxItems && canAddItem(item) && index <= items.length)
		{
			items.insertAt(index, item);
			print("Added item at index: " + item.name);
			return true;
		}
		return false;
	}

	void RemoveItem(Item@ item)
	{
		for (uint i = 0; i < items.length; i++)
		{
			Item@ item2 = items[i];
			if (item2 is item)
			{
				RemoveItem(i);
				return;
			}
		}
	}

	void RemoveItem(uint x, uint y)
	{
		uint index = getIndex(x, y);
		RemoveItem(index);
	}

	void RemoveItem(uint index)
	{
		if (hasItem(index))
		{
			items.removeAt(index);
			print("Removed item");
		}
	}

	Item@ getItem(uint x, uint y)
	{
		uint index = getIndex(x, y);
		return getItem(index);
	}

	Item@ getItem(uint index)
	{
		if (hasItem(index))
		{
			return items[index];
		}
		return null;
	}

	int getItemIndex(Item@ item)
	{
		for (uint i = 0; i < items.length; i++)
		{
			Item@ item2 = items[i];
			if (item2 is item)
			{
				return i;
			}
		}
		return -1;
	}

	bool hasItem(Item@ item)
	{
		for (uint i = 0; i < items.length; i++)
		{
			Item@ item2 = items[i];
			if (item2 is item)
			{
				return true;
			}
		}
		return false;
	}

	bool hasItem(uint x, uint y)
	{
		uint index = getIndex(x, y);
		return hasItem(index);
	}

	bool hasItem(uint index)
	{
		if (index < items.length)
		{
			return items[index] !is null;
		}
		return false;
	}

	bool canAddItem(Item@ item)
	{
		return itemFilter.empty() || itemFilter.find(item.name) > -1;
	}

	string Update()
	{
		CControls@ controls = getControls();

		if (controls.isKeyJustPressed(KEY_LBUTTON) && !hasSelectedItem())
		{
			Vec2f mousePos = controls.getMouseScreenPos();
			int index = getCellAtPoint(mousePos);
			if (index > -1)
			{
				Item@ item = getItem(index);
				if (item !is null)
				{
					@selectedItem = item;
					print("Selected " + item.name);
					this.hasMoved = false;
				}
			}
		}

		if (hasSelectedItem())
		{
			Vec2f mousePos = controls.getMouseScreenPos();
			int oldIndex = getItemIndex(selectedItem);
			int index = getCellAtPoint(mousePos);
			if (oldIndex != index && index != -1)
			{
				Item item = selectedItem;
				RemoveItem(selectedItem);
				AddItem(item, Maths::Min(index, items.length));
				@selectedItem = item;
				this.hasMoved = true;
			}

			if (!controls.isKeyPressed(KEY_LBUTTON))
			{
				print("Deselected " + selectedItem.name);
				string bpPath = selectedItem.path;
				@selectedItem = null;
				if(this.hasMoved == false)
				{
					return bpPath;
				}
			}
		}
		return "";
	}

	void Render()
	{
		
		Vec2f tl = position;
		Vec2f br = tl + Vec2f(cellDim.x * width, cellDim.y * height);
		GUI::DrawRectangle(tl - Vec2f(1, 1), br + Vec2f(1, 1), SColor(0x40E6A800));

		for (uint i = 0; i < items.length; i++)
		{
			Item@ item = items[i];
			uint x = i % width;
			uint y = i / width;

			Vec2f goalPos = position + Vec2f(x * cellDim.x, y * cellDim.y);
			item.position += (goalPos - item.position) * this.displacementSpeed;
			Vec2f pos(Maths::Round(item.position.x), Maths::Round(item.position.y));

			SColor color = selectedItem is item ? SColor(255, 150, 150, 150) : color_white;
			GUI::DrawRectangle(pos + Vec2f(1, 1), pos + cellDim - Vec2f(1, 1), color);
			GUI::DrawTextCentered(item.name, pos + cellDim / 2.0f, color_black);
		}

		Vec2f mousePos = getControls().getInterpMouseScreenPos();
		int index = getCellAtPoint(mousePos);
		if (index > -1)
		{
			GUI::DrawTextCentered(""+index, mousePos - Vec2f(0, 10), SColor(255, 255, 0, 0));
		}
		
	}

	bool hasSelectedItem()
	{
		return selectedItem !is null;
	}

	int getCellAtPoint(Vec2f point)
	{
		Vec2f pos = point - position;
		int x = Maths::Floor(pos.x / cellDim.x);
		int y = Maths::Floor(pos.y / cellDim.y);
		if (x >= 0 && x < width && y >= 0 && y < height)
		{
			uint index = x + y * width;
			return index;
		}
		return -1;
	}

	private uint getIndex(uint x, uint y)
	{
		return x + y * width;
	}
}
