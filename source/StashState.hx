package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.nape.FlxNapeSpace;
import flixel.addons.nape.FlxNapeSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import nape.phys.BodyType;
import openfl.Assets;

/**
 * Player's base area - the Stash
 * A safe area where players can manage equipment, items, and return to missions
 */
class StashState extends FlxState
{
	private var fpsGraph:FPSGraph;
	private var debugText:FlxText;

	// Camera lookahead settings
	private var cameraLookaheadWeight:Float = 0.4;

	override public function create()
	{
		super.create();
		trace("StashState: Initializing player's stash area");

		Main.displayLayers = new DisplayLayers();

		// Initialize Nape physics world
		FlxNapeSpace.init();
		FlxNapeSpace.space.gravity.setxy(0, 0); // No gravity for top-down game
		trace("StashState: Nape space initialized");

		// Set background color to distinguish from PlayState
		FlxG.camera.bgColor = FlxColor.fromRGB(20, 30, 40); // Dark blue-gray

		// Add all display layers to this state FIRST
		Main.displayLayers.addAllToState(this);
		trace("StashState: Display layers added");

		// Load and render the stash map
		loadStashMap();

		// Add FPS graph for performance monitoring
		fpsGraph = new FPSGraph();
		add(fpsGraph);
		trace("StashState: FPS graph initialized");

		// Add debug text for PlayerBody statistics
		debugText = new FlxText(FlxG.width - 200, 10, 190, "");
		debugText.setFormat(null, 12, 0xFFFFFFFF, "right");
		debugText.scrollFactor.set(0, 0); // Keep fixed on screen
		add(debugText);
		trace("StashState: Debug text initialized");
	}

	private function loadStashMap():Void
	{
		// Load LDTK stash map
		var ldtkJson = Assets.getText("assets/data/SiegeStashJSONMap.ldtk");
		var mapData = LdtkImporter.parse(ldtkJson);
		trace("StashState: LDTK Stash Map: " + mapData.width + "x" + mapData.height + " with " + mapData.entities.length + " entities");

		// Initialize navigation systems for the stash
		NavMesh.initialize(mapData.backgroundGrid);
		trace("StashState: Navigation systems initialized");

		// Render the stash map objects (walls with physics, other objects visual only)
		trace("StashState: Starting stash map rendering");
		MapRenderer.renderMap(mapData);
		trace("StashState: Stash map rendering completed");

		// Debug: Check Nape space state after map creation
		if (FlxNapeSpace.space != null && FlxNapeSpace.space.bodies != null)
		{
			trace("StashState: Total Nape bodies in space: " + FlxNapeSpace.space.bodies.length + " (walls and objects)");
		}
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		// Update camera to follow player with mouse lookahead
		updateCameraFollow(elapsed);

		// Check for infiltration point interaction
		checkInfilPointInteraction();

		// Update debug text with PlayerBody statistics
		updateDebugText();

		// Toggle fullscreen with G key
		if (FlxG.keys.justPressed.G)
		{
			toggleFullscreen();
		}

		// Toggle FPS graph with F key
		if (FlxG.keys.justPressed.F)
		{
			if (fpsGraph != null)
			{
				fpsGraph.toggle();
			}
		}

		// Reset FPS graph with T key (moved from R to avoid conflict with resize)
		if (FlxG.keys.justPressed.T)
		{
			if (fpsGraph != null)
			{
				fpsGraph.reset();
			}
		}

		// Camera lookahead weight controls (for testing)
		if (FlxG.keys.justPressed.ONE)
		{
			cameraLookaheadWeight = 0.0;
			trace("Camera lookahead weight: " + cameraLookaheadWeight + " (follow player only)");
		}
		if (FlxG.keys.justPressed.TWO)
		{
			cameraLookaheadWeight = 0.25;
			trace("Camera lookahead weight: " + cameraLookaheadWeight);
		}
		if (FlxG.keys.justPressed.THREE)
		{
			cameraLookaheadWeight = 0.5;
			trace("Camera lookahead weight: " + cameraLookaheadWeight);
		}
		if (FlxG.keys.justPressed.FOUR)
		{
			cameraLookaheadWeight = 0.75;
			trace("Camera lookahead weight: " + cameraLookaheadWeight);
		}
		if (FlxG.keys.justPressed.FIVE)
		{
			cameraLookaheadWeight = 1.0;
			trace("Camera lookahead weight: " + cameraLookaheadWeight + " (follow exact midpoint)");
		}
	}

	/**
	 * Check if player is touching the infiltration point and handle transition to PlayState
	 */
	private function checkInfilPointInteraction():Void
	{
		if (PlayerBody.instance == null || MapRenderer.infiltrationPoint == null)
			return;

		// Check if player is touching the infiltration point using simple distance check
		var playerCenterX = PlayerBody.instance.getCenterX();
		var playerCenterY = PlayerBody.instance.getCenterY();
		var infilCenterX = MapRenderer.infiltrationPoint.x + MapRenderer.infiltrationPoint.width * 0.5;
		var infilCenterY = MapRenderer.infiltrationPoint.y + MapRenderer.infiltrationPoint.height * 0.5;

		var distance = Math.sqrt(Math.pow(playerCenterX - infilCenterX, 2) + Math.pow(playerCenterY - infilCenterY, 2));

		if (distance < 20) // Close enough to interact
		{
			// Show interaction prompt and handle infiltration
			if (FlxG.keys.justPressed.SPACE)
			{
				trace("StashState: Player infiltrating - switching to PlayState");

				// Remove all display layers from current state
				Main.displayLayers.removeAllFromState(this);

				// Kill all objects including the player (clean slate approach)
				Main.displayLayers.killAllObjects();

				// Ensure player is properly destroyed
				PlayerBody.destroyInstance();

				Main.displayLayers = null;

				FlxG.switchState(() -> new PlayState());
			}
			else
			{
				// Could add a visual prompt here later
			}
		}
	}

	/**
	 * Update camera to smoothly follow a weighted point between player and mouse cursor
	 */
	private function updateCameraFollow(elapsed:Float):Void
	{
		if (PlayerBody.instance == null)
			return;

		// Get player center position
		var playerX = PlayerBody.instance.getCenterX();
		var playerY = PlayerBody.instance.getCenterY();

		// Get mouse world position
		var mouseWorldX = FlxG.mouse.x + FlxG.camera.scroll.x;
		var mouseWorldY = FlxG.mouse.y + FlxG.camera.scroll.y;

		// Scale the lookahead weight to a practical range (0-0.5 instead of 0-1)
		var scaledWeight = cameraLookaheadWeight * 0.5;

		// Calculate the weighted lookahead point
		var lookaheadX = playerX + (mouseWorldX - playerX) * scaledWeight;
		var lookaheadY = playerY + (mouseWorldY - playerY) * scaledWeight;

		// Calculate target camera position (centered on lookahead point)
		var targetX = lookaheadX - FlxG.width * 0.5;
		var targetY = lookaheadY - FlxG.height * 0.5;

		// Fast lerp factor
		var lerpFactor = 8.0;

		// Lerp camera position towards target
		FlxG.camera.scroll.x += (targetX - FlxG.camera.scroll.x) * lerpFactor * elapsed;
		FlxG.camera.scroll.y += (targetY - FlxG.camera.scroll.y) * lerpFactor * elapsed;
	}

	private function toggleFullscreen():Void
	{
		FlxG.fullscreen = !FlxG.fullscreen;
		trace("StashState: Fullscreen toggled to " + FlxG.fullscreen);
	}

	/**
	 * Update debug text with PlayerBody creation statistics
	 */
	private function updateDebugText():Void
	{
		if (debugText != null)
		{
			debugText.text = "PlayerBody Debug:\n" + "Times Created: " + PlayerBody.timesCreated + "\n" + "Times New: " + PlayerBody.timesNew;
		}
	}
}
