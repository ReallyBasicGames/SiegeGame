package;

import Pathfinding;
import flixel.addons.nape.FlxNapeSpace;
import flixel.addons.nape.FlxNapeSprite;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import nape.geom.Ray;
import nape.geom.Vec2;
import nape.phys.BodyType;

// AI States
enum EnemyState
{
	DIRECT_PURSUIT; // Has LOS to player, moving directly
	FOLLOWING_PATH; // Following calculated path
	SEARCHING; // Lost player, calculating new path
}

/**
 * Basic enemy with efficient state-based AI
 */
class BasicEnemy extends FlxNapeSprite
{
	// Basic properties
	private var moveSpeed:Float = 80;
	private var detectionRange:Float = 300;

	// AI State Management
	private var currentState:EnemyState = SEARCHING;
	private var losCheckTimer:Float = 0;
	private var losCheckInterval:Float = 0.25; // Check LOS 4 times per second in DIRECT_PURSUIT
	private var pathfindingCooldown:Float = 0;
	private var stuckTimer:Float = 0;
	private var lastPosition:FlxPoint;

	// Pathfinding
	private var currentPath:Array<FlxPoint> = [];
	private var currentWaypointIndex:Int = 0;
	private var pathCalculationCooldown:Float = 0;

	// LOS caching
	private var cachedLOS:Bool = false;
	private var losLastChecked:Float = 0;

	public function new(x:Float, y:Float)
	{
		super(x, y);

		// Initialize AI state
		lastPosition = FlxPoint.get(x, y);
		currentState = SEARCHING;

		// Visual appearance
		makeGraphic(16, 16, FlxColor.RED);
		updateStateColor(); // Set initial color based on starting state

		try
		{
			// Create physics body with circular shape for smoother movement
			createCircularBody(7); // Radius of 7 gives a 14-diameter circle, slightly smaller than 16x16 sprite

			// Verify body was created successfully
			if (body != null && body.shapes != null && body.shapes.length > 0)
			{
				// Set physics properties optimized for smooth movement
				body.shapes.at(0).material.elasticity = 0.0; // No bouncing
				body.shapes.at(0).material.staticFriction = 0.1; // Very low friction
				body.shapes.at(0).material.dynamicFriction = 0.1; // Very low friction
				body.allowRotation = false;

				// Set collision filters - enemy group
				for (shape in body.shapes)
				{
					if (shape != null && shape.filter != null)
					{
						shape.filter.collisionGroup = 3;
						shape.filter.collisionMask = ~0; // Collides with everything
					}
				}
				trace("Enemy physics body created successfully with circular hitbox and smooth movement properties");
			}
			else
			{
				trace("Failed to create enemy physics body");
			}
		}
		catch (e:Dynamic)
		{
			trace("Error creating enemy physics body: " + e);
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (PlayerBody.instance != null)
		{
			updateAI(elapsed);
		}
	}

	/**
	 * Main AI controller - manages state transitions and calls appropriate update functions
	 */
	private function updateAI(elapsed:Float):Void
	{
		// Update timers
		losCheckTimer += elapsed;
		pathfindingCooldown -= elapsed;
		pathCalculationCooldown -= elapsed;

		// Check if player is within detection range
		var playerCenter = FlxPoint.get(PlayerBody.instance.getCenterX(), PlayerBody.instance.getCenterY());
		var enemyCenter = FlxPoint.get(x + width * 0.5, y + height * 0.5);
		var distanceToPlayer = enemyCenter.distanceTo(playerCenter);

		if (distanceToPlayer <= detectionRange)
		{
			// Player is in range - execute state-based behavior
			switch (currentState)
			{
				case DIRECT_PURSUIT:
					updateDirectPursuit(elapsed, enemyCenter, playerCenter);

				case FOLLOWING_PATH:
					updateFollowingPath(elapsed, enemyCenter, playerCenter);

				case SEARCHING:
					updateSearching(elapsed, enemyCenter, playerCenter);
			}
		}
		else
		{
			// Player is out of range - stop moving and go to searching state
			stopMovement();
			if (currentState != SEARCHING)
			{
				currentState = SEARCHING;
				updateStateColor();
			}
		}

		// Clean up FlxPoints
		playerCenter.put();
		enemyCenter.put();

		// Update stuck detection
		updateStuckDetection(elapsed);
	}

	/**
	 * DIRECT_PURSUIT state: Has LOS to player, moving directly toward them
	 */
	private function updateDirectPursuit(elapsed:Float, enemyCenter:FlxPoint, playerCenter:FlxPoint):Void
	{
		// Check LOS frequently while in direct pursuit
		if (losCheckTimer >= losCheckInterval)
		{
			losCheckTimer = 0;

			if (!checkLineOfSight(enemyCenter, playerCenter))
			{
				// Lost LOS - transition to pathfinding
				trace("Enemy lost LOS, switching to pathfinding");
				currentState = FOLLOWING_PATH;
				updateStateColor();
				pathCalculationCooldown = 0; // Force immediate path calculation
				return;
			}
		}

		// Move directly toward player
		moveDirectlyToTarget(enemyCenter, playerCenter);
	}

	/**
	 * FOLLOWING_PATH state: Following a calculated path to player
	 */
	private function updateFollowingPath(elapsed:Float, enemyCenter:FlxPoint, playerCenter:FlxPoint):Void
	{
		// Check LOS less frequently while pathfinding
		if (losCheckTimer >= losCheckInterval * 2) // Half the frequency
		{
			losCheckTimer = 0;

			if (checkLineOfSight(enemyCenter, playerCenter))
			{
				// Regained LOS - transition to direct pursuit
				trace("Enemy regained LOS, switching to direct pursuit");
				currentState = DIRECT_PURSUIT;
				updateStateColor();
				clearCurrentPath();
				return;
			}
		}

		// Follow current path
		if (currentPath.length > 0)
		{
			followCurrentPath(enemyCenter);
		}
		else
		{
			// No path - transition to searching
			currentState = SEARCHING;
			updateStateColor();
		}
	}

	/**
	 * SEARCHING state: Lost player, needs new path calculation
	 */
	private function updateSearching(elapsed:Float, enemyCenter:FlxPoint, playerCenter:FlxPoint):Void
	{
		// First check if we have LOS
		if (checkLineOfSight(enemyCenter, playerCenter))
		{
			// Found LOS - transition directly to pursuit
			trace("Enemy found LOS while searching, switching to direct pursuit");
			currentState = DIRECT_PURSUIT;
			updateStateColor();
			return;
		}

		// Calculate new path if cooldown expired
		if (pathCalculationCooldown <= 0)
		{
			trace("Enemy calculating new path to player");
			calculatePathToTarget(enemyCenter, playerCenter);
			pathCalculationCooldown = 3.0; // Wait 3 seconds before next calculation if this fails

			if (currentPath.length > 0)
			{
				// Successfully calculated path - transition to following
				currentState = FOLLOWING_PATH;
				updateStateColor();
				currentWaypointIndex = 0;
				trace("Enemy found path with " + currentPath.length + " waypoints");
			}
		}

		// Stop movement while searching
		stopMovement();
	}

	/**
	 * Check line of sight from enemy to player using raycast
	 */
	private function checkLineOfSight(fromPos:FlxPoint, toPos:FlxPoint):Bool
	{
		if (FlxNapeSpace.space == null)
			return false;

		var fromVec:Vec2 = null;
		var toVec:Vec2 = null;
		var ray:Ray = null;

		try
		{
			fromVec = Vec2.get(fromPos.x, fromPos.y);
			toVec = Vec2.get(toPos.x, toPos.y);
			ray = Ray.fromSegment(fromVec, toVec);

			// Cast ray and check for any collisions
			var result = FlxNapeSpace.space.rayCast(ray, false);

			var hasLOS = true;
			if (result != null && result.shape != null && result.shape.filter != null)
			{
				// Check if we hit a wall (collision group 2)
				if (result.shape.filter.collisionGroup == 2)
				{
					hasLOS = false;
				}
			}

			// Cleanup before returning
			if (fromVec != null)
				fromVec.dispose();
			if (toVec != null)
				toVec.dispose();

			return hasLOS;
		}
		catch (e:Dynamic)
		{
			trace("Error in LOS raycast: " + e);
			// Cleanup on error
			if (fromVec != null)
				fromVec.dispose();
			if (toVec != null)
				toVec.dispose();
			return false;
		}
	}

	/**
	 * Move directly toward target using physics
	 */
	private function moveDirectlyToTarget(enemyCenter:FlxPoint, targetCenter:FlxPoint):Void
	{
		if (body == null || body.velocity == null)
			return;

		var direction = FlxPoint.get(targetCenter.x - enemyCenter.x, targetCenter.y - enemyCenter.y);
		var distance = direction.length;

		// If very close, just stop
		if (distance < 6.0)
		{
			body.velocity.setxy(0, 0);
			direction.put();
			return;
		}

		direction.normalize();

		// Set velocity directly
		body.velocity.setxy(direction.x * moveSpeed, direction.y * moveSpeed);

		direction.put();
	}

	/**
	 * Calculate path to target using NavMesh pathfinding system
	 */
	private function calculatePathToTarget(enemyCenter:FlxPoint, targetCenter:FlxPoint):Void
	{
		// Clear existing path
		clearCurrentPath();

		// Use NavMesh-based pathfinding system
		var path = Pathfinding.findPath(enemyCenter.x, enemyCenter.y, targetCenter.x, targetCenter.y);

		if (path != null && path.length > 0)
		{
			currentPath = path;
			currentWaypointIndex = 0;
			trace("Enemy calculated path with " + path.length + " waypoints");
		}
		else
		{
			trace("Enemy failed to find path to target");
		}
	}

	/**
	 * Follow the current calculated path
	 */
	private function followCurrentPath(enemyCenter:FlxPoint):Void
	{
		if (currentPath.length == 0 || currentWaypointIndex >= currentPath.length)
			return;

		var targetWaypoint = currentPath[currentWaypointIndex];
		var distanceToWaypoint = enemyCenter.distanceTo(targetWaypoint);

		// If close to current waypoint, move to next one
		if (distanceToWaypoint < 12)
		{
			currentWaypointIndex++;

			if (currentWaypointIndex >= currentPath.length)
			{
				// Reached end of path - transition to searching for new path
				trace("Enemy reached end of path");
				currentState = SEARCHING;
				updateStateColor();
				clearCurrentPath();
				return;
			}

			targetWaypoint = currentPath[currentWaypointIndex];
		}

		// Move toward current waypoint
		moveTowardTarget(enemyCenter, targetWaypoint);
	}

	/**
	 * Move toward a specific target point
	 */
	private function moveTowardTarget(fromPos:FlxPoint, targetPos:FlxPoint):Void
	{
		if (body == null || body.velocity == null)
			return;

		var direction = FlxPoint.get(targetPos.x - fromPos.x, targetPos.y - fromPos.y);
		var distance = direction.length;

		if (distance < 3.0)
		{
			body.velocity.setxy(0, 0);
			direction.put();
			return;
		}

		direction.normalize();
		body.velocity.setxy(direction.x * moveSpeed, direction.y * moveSpeed);
		direction.put();
	}

	/**
	 * Stop all movement
	 */
	private function stopMovement():Void
	{
		if (body != null && body.velocity != null)
		{
			body.velocity.setxy(0, 0);
		}
	}

	/**
	 * Clear the current path and reset waypoint index
	 */
	private function clearCurrentPath():Void
	{
		for (point in currentPath)
		{
			if (point != null)
				point.put();
		}
		currentPath = [];
		currentWaypointIndex = 0;
	}

	/**
	 * Basic stuck detection - if not moving for too long, force new path calculation
	 */
	private function updateStuckDetection(elapsed:Float):Void
	{
		if (lastPosition == null)
		{
			lastPosition = FlxPoint.get(x, y);
			return;
		}

		var currentPos = FlxPoint.get(x, y);
		var distanceMoved = lastPosition.distanceTo(currentPos);

		// If we're trying to move but not making progress
		if (currentState != SEARCHING && distanceMoved < 1.0)
		{
			stuckTimer += elapsed;

			if (stuckTimer > 2.0) // Stuck for more than 2 seconds
			{
				trace("Enemy stuck, forcing new path calculation");
				currentState = SEARCHING;
				updateStateColor();
				pathCalculationCooldown = 0; // Force immediate recalculation
				stuckTimer = 0;
			}
		}
		else
		{
			stuckTimer = 0; // Reset if making progress
		}

		// Update last position
		lastPosition.set(currentPos.x, currentPos.y);
		currentPos.put();
	}

	/**
	 * Update enemy color based on current AI state for visual debugging
	 */
	private function updateStateColor():Void
	{
		switch (currentState)
		{
			case DIRECT_PURSUIT:
				// Bright red - actively chasing player with LOS
				color = FlxColor.RED;

			case FOLLOWING_PATH:
				// Orange - following calculated path
				color = FlxColor.ORANGE;

			case SEARCHING:
				// Yellow - searching for player or calculating path
				color = FlxColor.YELLOW;
		}
	}

	override public function destroy():Void
	{
		// Clean up FlxPoint objects
		if (lastPosition != null)
		{
			lastPosition.put();
			lastPosition = null;
		}

		// Clean up current path
		clearCurrentPath();

		super.destroy();
	}
}
