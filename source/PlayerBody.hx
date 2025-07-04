package;

import flixel.FlxG;
import flixel.addons.nape.FlxNapeSprite;
import lime.system.Display;
import nape.geom.Vec2;
import nape.phys.Body;
import nape.phys.BodyType;

/**
 * Physical representation of the player character
 * Handles movement, physics, sprite rendering, and collision
 * This object is destroyed and recreated on state changes
 */
class PlayerBody extends FlxNapeSprite
{
	// Global instance reference
	public static var instance:PlayerBody;

	public static var timesCreated = 0;

	public static var timesNew = 0;

	// Movement settings
	private static var maxSpeed:Float = 200;

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);
		// Create a simple colored rectangle for the player
		makeGraphic(16, 16, 0xFF0080FF); // Blue player - 16x16 to match game grid

		// Initialize physics body
		initializePhysics();

		instance = this;

		timesNew++;

		trace("PlayerBody: Created new instance at (" + x + ", " + y + ")");
	}

	/**
	 * Completely destroy the current player instance
	 */
	public static function destroyInstance():Void
	{
		if (instance != null)
		{
			trace("PlayerBody: Destroying existing instance");

			// Clear physics body velocity before destruction
			if (instance.body != null && instance.body.velocity != null)
			{
				instance.body.velocity.setxy(0, 0);
				instance.body.angularVel = 0;
			}

			// Kill and destroy the sprite
			instance.kill();
			instance.destroy();
			instance = null;
		}
	}

	public static function create(x:Float, y:Float):PlayerBody
	{
		// Destroy existing instance if it exists
		if (instance != null)
		{
			destroyInstance();
		}

		instance = new PlayerBody(x, y);
		// Set the global instance
		return instance;
	}

	private function initializePhysics():Void
	{
		try
		{
			// Set up Nape physics body with circular shape for smoother movement
			createCircularBody(7); // Radius of 7 gives a 14-diameter circle, slightly smaller than 16x16 sprite

			// Verify body was created successfully
			if (body != null && body.shapes != null && body.shapes.length > 0)
			{
				// Set physics properties
				body.shapes.at(0).material.elasticity = 0.1;
				body.shapes.at(0).material.staticFriction = 0.5;
				body.shapes.at(0).material.dynamicFriction = 0.3;

				// Prevent rotation
				body.allowRotation = false;

				// Set collision filters - player should collide with walls

				if (body.shapes.at(0) != null && body.shapes.at(0).filter != null)
				{
					body.shapes.at(0).filter.collisionGroup = 1;
					body.shapes.at(0).filter.collisionMask = ~0; // Collides with everything including walls
				}

				trace("PlayerBody: Physics body created successfully");

				// Ensure the body starts with zero velocity
				body.velocity.setxy(0, 0);
				body.angularVel = 0;
			}
			else
			{
				trace("PlayerBody: Failed to create physics body");
			}
		}
		catch (e:Dynamic)
		{
			trace("PlayerBody: Error creating physics body: " + e);
		}
	}

	/**
	 * Add player instance to the character display layer
	 */
	public static function addToCharacterLayer():Void
	{
		if (instance != null && Main.displayLayers.characters != null)
		{
			// add this object to the characters of displayLayers in the current state
			trace("PlayerBody: Adding instance to character layer");
			Main.displayLayers.characters.add(instance);
		}
	}

	private static var frameCounter:Int = 0;

	override public function update(elapsed:Float):Void
	{
		handleInput();
		frameCounter++;
		trace("Frame " + frameCounter);
		super.update(elapsed);
	}

	private function handleInput():Void
	{
		// Safety check for physics body and space validity
		if (body == null || body.velocity == null || body.space == null)
		{
			trace("PlayerBody: Physics body invalid, skipping input handling");
			return;
		}

		try
		{
			var inputX = 0.0;
			var inputY = 0.0;

			// WASD movement - collect input direction
			if (FlxG.keys.pressed.W || FlxG.keys.pressed.UP)
				inputY = -1.0;
			if (FlxG.keys.pressed.S || FlxG.keys.pressed.DOWN)
				inputY = 1.0;
			if (FlxG.keys.pressed.A || FlxG.keys.pressed.LEFT)
				inputX = -1.0;
			if (FlxG.keys.pressed.D || FlxG.keys.pressed.RIGHT)
				inputX = 1.0;

			// Normalize diagonal movement
			if (inputX != 0 && inputY != 0)
			{
				var length = Math.sqrt(inputX * inputX + inputY * inputY);
				inputX /= length;
				inputY /= length;
			}

			// Set velocity directly instead of applying impulse to avoid accumulation
			if (inputX != 0 || inputY != 0)
			{
				body.velocity.setxy(inputX * maxSpeed, inputY * maxSpeed);
			}
			else
			{
				// Apply strong drag when no input to stop quickly
				body.velocity.setxy(body.velocity.x * 0.8, body.velocity.y * 0.8);
			}
		}
		catch (e:Dynamic)
		{
			trace("Error in player input handling: " + e);
		}

		// Limit maximum velocity
		limitVelocity();
	}

	private function limitVelocity():Void
	{
		// Safety check for physics body and space validity
		if (body == null || body.velocity == null || body.space == null)
		{
			return;
		}

		try
		{
			var vel = body.velocity;
			var speed = vel.length;

			if (speed > maxSpeed)
			{
				vel.normalise();
				vel.muleq(maxSpeed);
				body.velocity = vel;
			}
		}
		catch (e:Dynamic)
		{
			trace("Error in player velocity limiting: " + e);
		}
	}

	/**
	 * Get the center position of the player body
	 */
	public function getCenterX():Float
	{
		return x + width * 0.5;
	}

	/**
	 * Get the center position of the player body
	 */
	public function getCenterY():Float
	{
		return y + height * 0.5;
	}
}
