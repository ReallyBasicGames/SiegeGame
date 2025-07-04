package;

/**
 * Map data structure for parsed LDTK levels
 */
class MapData
{
	public var width:Int;
	public var height:Int;
	public var backgroundGrid:Array<Array<Int>>;
	public var entities:Array<EntityDef>;

	public function new()
	{
		width = 0;
		height = 0;
		backgroundGrid = [];
		entities = [];
	}
}
