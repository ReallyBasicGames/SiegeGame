package;

import flixel.FlxGame;
import openfl.display.Sprite;

class Main extends Sprite
{
	public static var displayLayers:DisplayLayers;

	public function new()
	{
		super();

		// Standard game resolution - can be scaled to fullscreen
		addChild(new FlxGame(1280, 720, PlayState));
	}
}
