package;

/**
 * Static class that handles all persistent player data
 * This data survives across state changes and scene transitions
 */
class PlayerData
{
	// Health system
	public static var health:Int = 100;
	public static var maxHealth:Int = 100;

	// Experience and leveling system
	public static var experience:Int = 0;
	public static var level:Int = 1;
	public static var experienceToNextLevel:Int = 100;

	// Inventory system (can be expanded later)
	// public static var inventory:Array<Item> = [];
	// Player stats that affect gameplay but not physics
	// public static var damage:Int = 10;
	// public static var armor:Int = 0;
	// public static var criticalChance:Float = 0.05;

	/**
	 * Get current health
	 */
	public static function getHealth():Int
	{
		return health;
	}

	/**
	 * Get maximum health
	 */
	public static function getMaxHealth():Int
	{
		return maxHealth;
	}

	/**
	 * Get current experience
	 */
	public static function getExperience():Int
	{
		return experience;
	}

	/**
	 * Get current level
	 */
	public static function getLevel():Int
	{
		return level;
	}

	/**
	 * Get experience needed for next level
	 */
	public static function getExperienceToNextLevel():Int
	{
		return experienceToNextLevel;
	}

	/**
	 * Apply damage to the player
	 */
	public static function takeDamage(amount:Int):Void
	{
		health = Std.int(Math.max(0, health - amount));
		trace("PlayerData: Took " + amount + " damage, health now: " + health);
	}

	/**
	 * Heal the player
	 */
	public static function heal(amount:Int):Void
	{
		health = Std.int(Math.min(maxHealth, health + amount));
		trace("PlayerData: Healed " + amount + " HP, health now: " + health);
	}

	/**
	 * Add experience and handle level ups
	 */
	public static function addExperience(amount:Int):Void
	{
		experience += amount;
		trace("PlayerData: Gained " + amount + " experience, total: " + experience);

		// Check for level up
		while (experience >= experienceToNextLevel)
		{
			experience -= experienceToNextLevel;
			level++;
			experienceToNextLevel = Std.int(experienceToNextLevel * 1.2); // 20% increase per level
			trace("PlayerData: Level up! Now level " + level);
		}
	}

	/**
	 * Reset all player data to defaults (for new game)
	 */
	public static function reset():Void
	{
		health = 100;
		maxHealth = 100;
		experience = 0;
		level = 1;
		experienceToNextLevel = 100;
		trace("PlayerData: Reset to default values");
	}

	/**
	 * Check if player is alive
	 */
	public static function isAlive():Bool
	{
		return health > 0;
	}

	/**
	 * Get health as a percentage (0.0 to 1.0)
	 */
	public static function getHealthPercentage():Float
	{
		return maxHealth > 0 ? health / maxHealth : 0.0;
	}

	/**
	 * Get experience progress to next level as a percentage (0.0 to 1.0)
	 */
	public static function getExperiencePercentage():Float
	{
		return experienceToNextLevel > 0 ? experience / experienceToNextLevel : 0.0;
	}
}
