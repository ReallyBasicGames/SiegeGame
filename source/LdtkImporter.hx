package;

import haxe.Json;

/**
 * LDTK (Level Designer Toolkit) importer for parsing JSON map files
 */
class LdtkImporter
{
	private static var TILE_SIZE:Int = 16; // Changed to 16 to match LDTK grid

	/**
	 * Parse LDTK JSON string into MapData
	 * @param json The LDTK JSON string to parse
	 * @return MapData containing parsed level information
	 */
	public static function parse(json:String):MapData
	{
		var mapData = new MapData();

		try
		{
			var ldtkData = Json.parse(json);

			// Get the first level (assuming single level for now)
			if (ldtkData.levels != null && ldtkData.levels.length > 0)
			{
				var level = ldtkData.levels[0];

				// Set map dimensions
				mapData.width = Std.int(level.pxWid / TILE_SIZE);
				mapData.height = Std.int(level.pxHei / TILE_SIZE);

				// Parse layers
				if (level.layerInstances != null)
				{
					var layers:Array<Dynamic> = cast level.layerInstances;
					for (layer in layers)
					{
						if (layer.__identifier == "Walls")
						{
							mapData.backgroundGrid = parseBackgroundLayer(layer, mapData.width, mapData.height);
						}
						else if (layer.__identifier == "Characters")
						{
							mapData.entities = parseEntityLayer(layer);
						}
					}
				}
			}
		}
		catch (e:Dynamic)
		{
			trace("Error parsing LDTK JSON: " + e);
		}

		return mapData;
	}

	/**
	 * Parse the background layer from LDTK data
	 */
	private static function parseBackgroundLayer(layer:Dynamic, width:Int, height:Int):Array<Array<Int>>
	{
		var grid:Array<Array<Int>> = [];

		// Initialize the 2D array
		for (y in 0...height)
		{
			grid[y] = [];
			for (x in 0...width)
			{
				grid[y][x] = 0; // Default empty tile
			}
		}

		// Parse intGridCsv if it exists
		if (layer.intGridCsv != null)
		{
			var csvData:Array<Int> = layer.intGridCsv;
			var index = 0;

			for (y in 0...height)
			{
				for (x in 0...width)
				{
					if (index < csvData.length)
					{
						grid[y][x] = csvData[index];
						index++;
					}
				}
			}
		}

		return grid;
	}

	/**
	 * Parse the entity layer from LDTK data
	 */
	private static function parseEntityLayer(layer:Dynamic):Array<EntityDef>
	{
		var entities:Array<EntityDef> = [];

		if (layer.entityInstances != null)
		{
			var entityInstances:Array<Dynamic> = cast layer.entityInstances;
			for (entityInstance in entityInstances)
			{
				var entityDef = new EntityDef(entityInstance.__identifier, entityInstance.px[0], // Use pixel coordinates directly
					entityInstance.px[1]);
				entities.push(entityDef);
			}
		}

		return entities;
	}
}
