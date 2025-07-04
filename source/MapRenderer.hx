package;

import flixel.FlxSprite;
import flixel.addons.nape.FlxNapeSprite;
import flixel.util.FlxColor;
import nape.phys.BodyType;

/**
 * Renders parsed LDTK map data to the screen
 */
class MapRenderer
{
	// Global reference to extraction point for interaction
	public static var extractionPoint:FlxSprite = null;

	// Global reference to infiltration point for interaction (stash map portal)
	public static var infiltrationPoint:FlxSprite = null;

	// Global reference to enemy spawner for enemy pathfinding
	public static var enemySpawner:FlxSprite = null;

	// Global reference to player spawn position
	public static var playerSpawnX:Float = 100; // Default fallback
	public static var playerSpawnY:Float = 100; // Default fallback

	public static function renderMap(mapData:MapData):Void
	{
		// Initialize navigation first
		initializeNavigation(mapData.backgroundGrid);

		// Render wall tiles (background grid)
		renderWalls(mapData.backgroundGrid);

		// Render entities
		renderEntities(mapData.entities);
	}

	private static function renderWalls(backgroundGrid:Array<Array<Int>>):Void
	{
		var wallCount = 0;
		for (y in 0...backgroundGrid.length)
		{
			for (x in 0...backgroundGrid[y].length)
			{
				if (backgroundGrid[y][x] == 1) // Wall tile
				{
					// Create wall with physics (static - doesn't move)
					var wall = new FlxNapeSprite(x * 16, y * 16);
					wall.makeGraphic(16, 16, FlxColor.ORANGE);

					// Create kinematic physics body (like static but handled differently)
					wall.createRectangularBody(16, 16, BodyType.KINEMATIC);

					// Verify body was created successfully
					if (wall.body != null && wall.body.shapes != null)
					{
						trace("Wall Body: " + wall.body.toString());
						trace("Wall shapes: " + wall.body.shapes.toString());
						trace("Wall position: " + wall.body.position.toString());
						// Set collision group 2 for walls
						for (shape in wall.body.shapes)
						{
							if (shape != null && shape.filter != null)
							{
								shape.filter.collisionGroup = 2;
								shape.filter.collisionMask = ~0; // Collides with everything
							}
						}

						wallCount++;
						trace("Wall created at (" + (x * 16) + ", " + (y * 16) + ") with physics body");
					}
					else
					{
						trace("Failed to create physics body for wall at " + x + "," + y);
					}
					Main.displayLayers.interactables.add(wall);
				}
			}
		}
		trace("Created " + wallCount + " kinematic wall physics bodies (non-moving)");
	}

	private static function renderEntities(entities:Array<EntityDef>):Void
	{
		for (entity in entities)
		{
			var sprite:FlxSprite = null;

			switch (entity.type)
			{
				case "EnemyBasic":
					// Create enemy with physics
					var enemy = new BasicEnemy(entity.x, entity.y);
					Main.displayLayers.characters.add(enemy);

				case "EnemySpawner":
					enemySpawner = new FlxSprite(entity.x, entity.y);
					enemySpawner.makeGraphic(16, 16, FlxColor.PINK);
					Main.displayLayers.interactables.add(enemySpawner);

				case "ExtractionPoint":
					extractionPoint = new FlxSprite(entity.x, entity.y);
					extractionPoint.makeGraphic(16, 16, FlxColor.GREEN);
					Main.displayLayers.interactables.add(extractionPoint);

				case "InfilPoint":
					infiltrationPoint = new FlxSprite(entity.x, entity.y);
					infiltrationPoint.makeGraphic(16, 16, FlxColor.CYAN);
					Main.displayLayers.interactables.add(infiltrationPoint);

				case "PlayerSpawn":
					// Store the spawn position for later use
					playerSpawnX = entity.x;
					playerSpawnY = entity.y;

					// Create the player at spawn location
					PlayerBody.create(entity.x, entity.y);
					PlayerBody.addToCharacterLayer();

					trace("MapRenderer: Created player at spawn (" + entity.x + ", " + entity.y + ")");
			}
		}
	}

	/**
	 * Initialize navigation systems
	 */
	public static function initializeNavigation(backgroundGrid:Array<Array<Int>>):Void
	{
		// Initialize NavMesh for pathfinding
		NavMesh.initialize(backgroundGrid);
		trace("MapRenderer: Navigation systems initialized");
	}
}
