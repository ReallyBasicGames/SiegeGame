package;

/**
 * Entity definition for LDTK entities
 */
class EntityDef
{
	public var type:String;
	public var x:Int;
	public var y:Int;

	public function new(type:String, x:Int, y:Int)
	{
		this.type = type;
		this.x = x;
		this.y = y;
	}
}
