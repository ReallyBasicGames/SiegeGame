package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;

/**
 * Navigation node for the NavMesh system
 */
class NavNode
{
	public var id:Int;
	public var gridX:Int;
	public var gridY:Int;
	public var worldX:Float;
	public var worldY:Float;
	public var connections:Array<Int>; // IDs of connected nodes
	public var isWalkable:Bool = true;

	public function new()
	{
		connections = [];
	}
}

/**
 * Advanced Navigation Mesh system for efficient pathfinding
 * Converts tile-based maps into connected navigation nodes with 8-directional movement
 */
class NavMesh
{
	// Navigation mesh data
	private static var nodes:Array<NavNode> = [];
	private static var nodeGrid:Array<Array<Int>> = []; // Maps grid positions to node indices (-1 = no node)
	private static var mapWidth:Int = 0;
	private static var mapHeight:Int = 0;
	private static var tileSize:Int = 16;
	private static var enemyRadius:Int = 8; // Margin for enemy movement (slightly larger than enemy radius of 7)

	// Localized update system
	private static var updateQueue:Array<FlxPoint> = [];
	private static var updateTimer:Float = 0;
	private static var updateInterval:Float = 2.0; // Update every 2 seconds
	private static var isUpdating:Bool = false;

	// Debug visualization
	public static var showDebugNodes:Bool = false;
	private static var debugNodes:Array<FlxSprite> = [];

	// 8-directional movement offsets
	private static var directions:Array<Array<Int>> = [
		[-1, -1],
		[0, -1],
		[1, -1], // Top row
		[-1, 0],
		[1, 0], // Middle row
		[-1, 1],
		[0, 1],
		[1, 1] // Bottom row
	];

	/**
	 * Initialize the navigation mesh from a tile grid
	 */
	public static function initialize(wallGrid:Array<Array<Int>>):Void
	{
		trace("NavMesh: Initializing navigation mesh...");

		mapHeight = wallGrid.length;
		mapWidth = wallGrid[0].length;

		// Clear existing data
		nodes = [];
		nodeGrid = [];
		updateQueue = [];
		clearDebugVisualization();

		// Initialize node grid
		for (y in 0...mapHeight)
		{
			nodeGrid[y] = [];
			for (x in 0...mapWidth)
			{
				nodeGrid[y][x] = -1; // No node
			}
		}

		// Generate navigation nodes
		generateNodes(wallGrid);

		// Connect adjacent nodes using 8-directional movement
		connectNodes();

		trace("NavMesh: Generated " + nodes.length + " navigation nodes");
		trace("NavMesh: Initialization complete");

		if (showDebugNodes)
		{
			createDebugVisualization();
		}
	}

	/**
	 * Update localized mesh areas every few seconds
	 */
	public static function update(elapsed:Float):Void
	{
		updateTimer += elapsed;

		if (updateTimer >= updateInterval && updateQueue.length > 0 && !isUpdating)
		{
			updateTimer = 0;
			processLocalizedUpdates();
		}
	}

	/**
	 * Queue a localized mesh update at a specific world position
	 * Used for doors, breakable walls, etc.
	 */
	public static function queueLocalizedUpdate(worldX:Float, worldY:Float, radius:Int = 2):Void
	{
		var gridX = Math.floor(worldX / tileSize);
		var gridY = Math.floor(worldY / tileSize);

		// Add surrounding area to update queue
		for (dy in -radius...radius + 1)
		{
			for (dx in -radius...radius + 1)
			{
				var updateX = gridX + dx;
				var updateY = gridY + dy;

				if (isValidGridPosition(updateX, updateY))
				{
					var updatePoint = FlxPoint.get(updateX, updateY);

					// Check if already in queue
					var alreadyQueued = false;
					for (queuedPoint in updateQueue)
					{
						if (queuedPoint.x == updateX && queuedPoint.y == updateY)
						{
							alreadyQueued = true;
							break;
						}
					}

					if (!alreadyQueued)
					{
						updateQueue.push(updatePoint);
					}
					else
					{
						updatePoint.put(); // Clean up if not used
					}
				}
			}
		}

		trace("NavMesh: Queued localized update at (" + gridX + ", " + gridY + ") with radius " + radius);
	}

	/**
	 * Force immediate localized update (expensive, use sparingly)
	 */
	public static function forceLocalizedUpdate(wallGrid:Array<Array<Int>>, worldX:Float, worldY:Float, radius:Int = 2):Void
	{
		var gridX = Math.floor(worldX / tileSize);
		var gridY = Math.floor(worldY / tileSize);

		trace("NavMesh: Force updating area around (" + gridX + ", " + gridY + ")");

		// Update nodes in the affected area
		for (dy in -radius...radius + 1)
		{
			for (dx in -radius...radius + 1)
			{
				var updateX = gridX + dx;
				var updateY = gridY + dy;

				if (isValidGridPosition(updateX, updateY))
				{
					updateNodeAtPosition(wallGrid, updateX, updateY);
				}
			}
		}

		// Reconnect affected nodes
		reconnectArea(gridX - radius, gridY - radius, gridX + radius, gridY + radius);

		if (showDebugNodes)
		{
			updateDebugVisualization();
		}
	}

	/**
	 * Generate navigation nodes from walkable areas with enemy radius consideration
	 */
	private static function generateNodes(wallGrid:Array<Array<Int>>):Void
	{
		var nodeIndex = 0;

		for (y in 0...mapHeight)
		{
			for (x in 0...mapWidth)
			{
				if (isWalkableWithMargin(wallGrid, x, y))
				{
					// Create navigation node
					var node = new NavNode();
					node.id = nodeIndex;
					node.gridX = x;
					node.gridY = y;
					node.worldX = x * tileSize + (tileSize * 0.5);
					node.worldY = y * tileSize + (tileSize * 0.5);
					node.connections = [];
					node.isWalkable = true;

					nodes.push(node);
					nodeGrid[y][x] = nodeIndex;
					nodeIndex++;
				}
			}
		}
	}

	/**
	 * Check if a tile is walkable with enemy radius margin
	 * This prevents enemies from trying to path through spaces they can't fit
	 */
	private static function isWalkableWithMargin(wallGrid:Array<Array<Int>>, centerX:Int, centerY:Int):Bool
	{
		// Check if the center tile itself is walkable
		if (!isValidGridPosition(centerX, centerY) || wallGrid[centerY][centerX] != 0)
		{
			return false;
		}

		// Calculate margin in tiles based on enemy radius (8 pixels) and tile size (16 pixels)
		var marginTiles = Math.ceil(enemyRadius / tileSize); // This gives us 1 tile margin

		// Check all tiles within the margin radius
		for (dy in -marginTiles...marginTiles + 1)
		{
			for (dx in -marginTiles...marginTiles + 1)
			{
				// Skip the center tile (already checked)
				if (dx == 0 && dy == 0)
					continue;

				var checkX = centerX + dx;
				var checkY = centerY + dy;

				// Calculate distance from center
				var distance = Math.sqrt(dx * dx + dy * dy);

				// If within margin radius and it's a wall, this position is not safe
				if (distance <= marginTiles && isValidGridPosition(checkX, checkY) && wallGrid[checkY][checkX] != 0)
				{
					return false;
				}
			}
		}

		return true;
	}

	/**
	 * Connect nodes using 8-directional movement
	 */
	private static function connectNodes():Void
	{
		for (node in nodes)
		{
			if (!node.isWalkable)
				continue;

			// Check all 8 directions for connections
			for (dir in directions)
			{
				var neighborX = node.gridX + dir[0];
				var neighborY = node.gridY + dir[1];

				if (isValidGridPosition(neighborX, neighborY))
				{
					var neighborNodeId = nodeGrid[neighborY][neighborX];

					if (neighborNodeId >= 0 && nodes[neighborNodeId].isWalkable)
					{
						// Add bidirectional connection
						if (node.connections.indexOf(neighborNodeId) == -1)
						{
							node.connections.push(neighborNodeId);
						}
					}
				}
			}
		}
	}

	/**
	 * Process queued localized updates
	 */
	private static function processLocalizedUpdates():Void
	{
		if (updateQueue.length == 0)
			return;

		isUpdating = true;
		trace("NavMesh: Processing " + updateQueue.length + " localized updates");

		// Get current wall grid from MapRenderer (you'll need to expose this)
		// For now, we'll skip the actual update and just clear the queue
		// In a real implementation, you'd need access to the current wall state

		// Clear the queue
		for (point in updateQueue)
		{
			point.put();
		}
		updateQueue = [];

		isUpdating = false;
		trace("NavMesh: Localized updates complete");
	}

	/**
	 * Update a single node at a grid position
	 */
	private static function updateNodeAtPosition(wallGrid:Array<Array<Int>>, gridX:Int, gridY:Int):Void
	{
		var currentNodeId = nodeGrid[gridY][gridX];
		var shouldHaveNode = isWalkableWithMargin(wallGrid, gridX, gridY);

		if (shouldHaveNode && currentNodeId == -1)
		{
			// Create new node
			var node = new NavNode();
			node.id = nodes.length;
			node.gridX = gridX;
			node.gridY = gridY;
			node.worldX = gridX * tileSize + (tileSize * 0.5);
			node.worldY = gridY * tileSize + (tileSize * 0.5);
			node.connections = [];
			node.isWalkable = true;

			nodes.push(node);
			nodeGrid[gridY][gridX] = node.id;
		}
		else if (!shouldHaveNode && currentNodeId >= 0)
		{
			// Remove existing node
			if (currentNodeId < nodes.length)
			{
				nodes[currentNodeId].isWalkable = false;
				// Clear connections to this node from other nodes
				for (otherNode in nodes)
				{
					var connectionIndex = otherNode.connections.indexOf(currentNodeId);
					if (connectionIndex >= 0)
					{
						otherNode.connections.splice(connectionIndex, 1);
					}
				}
			}
			nodeGrid[gridY][gridX] = -1;
		}
	}

	/**
	 * Reconnect nodes in a specific area
	 */
	private static function reconnectArea(minX:Int, minY:Int, maxX:Int, maxY:Int):Void
	{
		for (y in minY...maxY + 1)
		{
			for (x in minX...maxX + 1)
			{
				if (isValidGridPosition(x, y))
				{
					var nodeId = nodeGrid[y][x];
					if (nodeId >= 0 && nodes[nodeId].isWalkable)
					{
						var node = nodes[nodeId];
						node.connections = []; // Clear existing connections

						// Reconnect to neighbors
						for (dir in directions)
						{
							var neighborX = x + dir[0];
							var neighborY = y + dir[1];

							if (isValidGridPosition(neighborX, neighborY))
							{
								var neighborNodeId = nodeGrid[neighborY][neighborX];

								if (neighborNodeId >= 0 && nodes[neighborNodeId].isWalkable)
								{
									node.connections.push(neighborNodeId);
								}
							}
						}
					}
				}
			}
		}
	}

	/**
	 * Get the closest node to a world position
	 */
	public static function getClosestNode(worldX:Float, worldY:Float):Int
	{
		var gridX = Math.floor(worldX / tileSize);
		var gridY = Math.floor(worldY / tileSize);

		// First try the exact grid position
		if (isValidGridPosition(gridX, gridY))
		{
			var nodeId = nodeGrid[gridY][gridX];
			if (nodeId >= 0 && nodes[nodeId].isWalkable)
			{
				return nodeId;
			}
		}

		// If no node at exact position, search in expanding circles
		for (radius in 1...5)
		{
			for (dy in -radius...radius + 1)
			{
				for (dx in -radius...radius + 1)
				{
					if (Math.abs(dx) == radius || Math.abs(dy) == radius) // Only check circle edge
					{
						var checkX = gridX + dx;
						var checkY = gridY + dy;

						if (isValidGridPosition(checkX, checkY))
						{
							var nodeId = nodeGrid[checkY][checkX];
							if (nodeId >= 0 && nodes[nodeId].isWalkable)
							{
								return nodeId;
							}
						}
					}
				}
			}
		}

		return -1; // No node found
	}

	/**
	 * Get node by ID
	 */
	public static function getNode(nodeId:Int):NavNode
	{
		if (nodeId >= 0 && nodeId < nodes.length)
		{
			return nodes[nodeId];
		}
		return null;
	}

	/**
	 * Get all nodes (for pathfinding algorithm)
	 */
	public static function getAllNodes():Array<NavNode>
	{
		return nodes;
	}

	/**
	 * Check if grid position is valid
	 */
	private static function isValidGridPosition(x:Int, y:Int):Bool
	{
		return x >= 0 && x < mapWidth && y >= 0 && y < mapHeight;
	}

	/**
	 * Create debug visualization of navigation nodes
	 */
	private static function createDebugVisualization():Void
	{
		clearDebugVisualization();

		for (node in nodes)
		{
			if (node.isWalkable)
			{
				var debugSprite = new FlxSprite(node.worldX - 2, node.worldY - 2);
				debugSprite.makeGraphic(4, 4, FlxColor.CYAN);
				debugNodes.push(debugSprite);
				Main.displayLayers.ui.add(debugSprite);
			}
		}

		trace("NavMesh: Created debug visualization for " + debugNodes.length + " nodes");
	}

	/**
	 * Update debug visualization
	 */
	private static function updateDebugVisualization():Void
	{
		if (showDebugNodes)
		{
			createDebugVisualization();
		}
	}

	/**
	 * Clear debug visualization
	 */
	private static function clearDebugVisualization():Void
	{
		for (sprite in debugNodes)
		{
			sprite.destroy();
		}
		debugNodes = [];
	}

	/**
	 * Toggle debug visualization
	 */
	public static function toggleDebugVisualization():Void
	{
		showDebugNodes = !showDebugNodes;

		if (showDebugNodes)
		{
			createDebugVisualization();
		}
		else
		{
			clearDebugVisualization();
		}
	}

	/**
	 * Get debug information
	 */
	public static function getDebugInfo():String
	{
		var walkableNodes = 0;
		var totalConnections = 0;

		for (node in nodes)
		{
			if (node.isWalkable)
			{
				walkableNodes++;
				totalConnections += node.connections.length;
			}
		}

		var avgConnections = walkableNodes > 0 ? Math.round((totalConnections / walkableNodes) * 100) / 100 : 0;

		return "NavMesh: "
			+ walkableNodes
			+ " walkable nodes, avg "
			+ avgConnections
			+ " connections per node, "
			+ updateQueue.length
			+ " queued updates";
	}
}
