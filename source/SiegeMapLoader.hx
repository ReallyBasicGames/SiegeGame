package;

import haxe.Json;
import openfl.Assets;

/**
 * Utility class for loading and parsing siege map files
 */
class SiegeMapLoader
{
	/**
	 * Load a siege map from a JSON file
	 * @param path The path to the JSON map file (relative to assets folder)
	 * @return SiegeMap containing parsed tile and spawn data
	 */
	public static function Load(path:String):SiegeMap
	{
		var map = new SiegeMap();

		try
		{
			// Load the JSON file as text
			var jsonText = Assets.getText(path);

			// Parse the JSON
			var jsonData = Json.parse(jsonText);

			// Extract tiles and spawns arrays
			if (jsonData.tiles != null)
			{
				map.tiles = jsonData.tiles;
			}

			if (jsonData.spawns != null)
			{
				map.spawns = jsonData.spawns;
			}
		}
		catch (e:Dynamic)
		{
			trace("Error loading map file: " + path + " - " + e);
			// Return empty map on error
		}

		return map;
	}
}
