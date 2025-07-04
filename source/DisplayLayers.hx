package;

import flixel.group.FlxGroup;

class DisplayLayers
{
	public var background:FlxGroup;
	public var interactables:FlxGroup;
	public var characters:FlxGroup;
	public var bullets:FlxGroup;
	public var vfx:FlxGroup;
	public var ui:FlxGroup;

	public function new()
	{
		init();
	}

	public function init():Void
	{
		background = new FlxGroup();
		interactables = new FlxGroup();
		characters = new FlxGroup();
		bullets = new FlxGroup();
		vfx = new FlxGroup();
		ui = new FlxGroup();
	}

	public function addAllToState(state:flixel.FlxState):Void
	{
		state.add(background);
		state.add(interactables);
		state.add(characters);
		state.add(bullets);
		state.add(vfx);
		state.add(ui);
	}

	public function removeAllFromState(state:flixel.FlxState):Void
	{
		state.remove(background);
		state.remove(interactables);
		state.remove(characters);
		state.remove(bullets);
		state.remove(vfx);
		state.remove(ui);
	}

	public function killAllObjects():Void
	{
		// Kill all objects in all groups
		if (background != null)
		{
			background.killMembers();
		}
		if (interactables != null)
		{
			interactables.killMembers();
		}
		if (characters != null)
		{
			characters.killMembers();
		}
		if (bullets != null)
		{
			bullets.killMembers();
		}
		if (vfx != null)
		{
			vfx.killMembers();
		}
		if (ui != null)
		{
			ui.killMembers();
		}

		trace("DisplayLayers: All objects killed");
	}
}
