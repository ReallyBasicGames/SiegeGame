package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.nape.FlxNapeSpace;
import flixel.text.FlxText;
import openfl.Assets;

class PlayState extends FlxState
{
	private var fpsGraph:FPSGraph;
	private var debugText:FlxText;

	// Camera lookahead settings
	private var cameraLookaheadWeight:Float = 0.4; // 0 = follow player only, 1 = follow exact midpoint

	override public function create()
	{
		super.create();
		trace("PlayState: Initializing basic Nape physics for player only");

		Main.displayLayers = new DisplayLayers();

		// Initialize Nape physics world (minimal setup for player only)
		FlxNapeSpace.init();
		FlxNapeSpace.space.gravity.setxy(0, 0); // No gravity for top-down game

		trace("PlayState: Nape space initialized for player movement only");

		// Add all display layers to this state
		Main.displayLayers.addAllToState(this);
		trace("PlayState: Display layers added");

		// Test map loading
		var testMap = SiegeMapLoader.Load("assets/data/test_map.json");
		trace("Loaded map with " + testMap.tiles.length + " tiles and " + testMap.spawns.length + " spawns");

		// Test LDTK importer and render map
		var ldtkJson = Assets.getText("assets/data/SiegeProjectJSONMapTest.ldtk");
		var mapData = LdtkImporter.parse(ldtkJson);
		trace("LDTK Map: " + mapData.width + "x" + mapData.height + " with " + mapData.entities.length + " entities");

		// Render the map objects (walls with physics, other objects visual only)
		trace("PlayState: Starting map rendering");
		MapRenderer.renderMap(mapData);
		trace("PlayState: Map rendering completed");

		// Debug: Check Nape space state after map creation
		if (FlxNapeSpace.space != null && FlxNapeSpace.space.bodies != null)
		{
			trace("PlayState: Total Nape bodies in space: " + FlxNapeSpace.space.bodies.length + " (walls + 1 player)");
		}

		// Add FPS graph for performance monitoring
		fpsGraph = new FPSGraph();
		add(fpsGraph);
		trace("PlayState: FPS graph initialized");

		// Add debug text for PlayerBody statistics
		debugText = new FlxText(FlxG.width - 200, 10, 190, "");
		debugText.setFormat(null, 12, 0xFFFFFFFF, "right");
		debugText.scrollFactor.set(0, 0); // Keep fixed on screen
		add(debugText);
		trace("PlayState: Debug text initialized");
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
		// FlxNapeSpace automatically steps the world during super.update()
		// Only player physics should be active now

		// Update NavMesh for localized updates
		NavMesh.update(elapsed);

		// Update camera to follow player with mouse lookahead
		updateCameraFollow(elapsed);

		// Check for extraction point interaction
		checkExtractionPointInteraction();

		// Update debug text with PlayerBody statistics
		updateDebugText();

		// Toggle FPS graph with F key
		if (FlxG.keys.justPressed.F)
		{
			if (fpsGraph != null)
			{
				fpsGraph.toggle();
			}
		}

		// Toggle fullscreen with G key
		if (FlxG.keys.justPressed.G)
		{
			toggleFullscreen();
		}

		// Reset FPS graph with T key
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

		// Update debug text with PlayerBody stats
		updateDebugText();
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

	/**
	 * Check if player is touching the extraction point and handle transition to StashState
	 */
	private function checkExtractionPointInteraction():Void
	{
		if (PlayerBody.instance == null || MapRenderer.extractionPoint == null)
			return;

		// Check if player is touching the extraction point using simple distance check
		var playerCenterX = PlayerBody.instance.getCenterX();
		var playerCenterY = PlayerBody.instance.getCenterY();
		var extractionCenterX = MapRenderer.extractionPoint.x + MapRenderer.extractionPoint.width * 0.5;
		var extractionCenterY = MapRenderer.extractionPoint.y + MapRenderer.extractionPoint.height * 0.5;

		var distance = Math.sqrt(Math.pow(playerCenterX - extractionCenterX, 2) + Math.pow(playerCenterY - extractionCenterY, 2));

		if (distance < 20) // Close enough to interact
		{
			// Show interaction prompt and handle extraction
			if (FlxG.keys.justPressed.SPACE)
			{
				trace("PlayState: Player extracting - switching to StashState");

				// Remove all display layers from current state
				Main.displayLayers.removeAllFromState(this);

				// Kill all objects including the player (clean slate approach)
				Main.displayLayers.killAllObjects();

				// Ensure player is properly destroyed
				PlayerBody.destroyInstance();

				Main.displayLayers = null; // ensure the display layers are no longer used, just in case there are any objects that weren't removed

				FlxG.switchState(() -> new StashState());
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
		// This prevents the camera from becoming unplayable at high values
		var scaledWeight = cameraLookaheadWeight * 0.5;

		// Calculate the weighted lookahead point
		// When weight = 0: follows player exactly
		// When weight = 1: follows at 0.5 distance from player toward mouse (practical maximum)
		var lookaheadX = playerX + (mouseWorldX - playerX) * scaledWeight;
		var lookaheadY = playerY + (mouseWorldY - playerY) * scaledWeight;

		// Calculate target camera position (centered on lookahead point)
		var targetX = lookaheadX - FlxG.width * 0.5;
		var targetY = lookaheadY - FlxG.height * 0.5;

		// Fast lerp factor (higher = more responsive, lower = smoother)
		var lerpFactor = 8.0; // Adjust this value to change camera responsiveness

		// Lerp camera position towards target
		FlxG.camera.scroll.x += (targetX - FlxG.camera.scroll.x) * lerpFactor * elapsed;
		FlxG.camera.scroll.y += (targetY - FlxG.camera.scroll.y) * lerpFactor * elapsed;
	}

	private function toggleFullscreen():Void
	{
		FlxG.fullscreen = !FlxG.fullscreen;
		trace("PlayState: Fullscreen toggled to " + FlxG.fullscreen);
	}
}
