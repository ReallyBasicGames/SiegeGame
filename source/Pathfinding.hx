package;

import flixel.math.FlxPoint;

/**
 * NavMesh-based pathfinding using A* algorithm
 * Operates on navigation nodes instead of individual tiles for better performance
 */
class Pathfinding
{
	/**
	 * Find path between two world positions using NavMesh
	 */
	public static function findPath(startX:Float, startY:Float, endX:Float, endY:Float):Array<FlxPoint>
	{
		// Get closest nodes to start and end positions
		var startNodeId = NavMesh.getClosestNode(startX, startY);
		var endNodeId = NavMesh.getClosestNode(endX, endY);

		if (startNodeId == -1 || endNodeId == -1)
		{
			trace("Pathfinding: Could not find start or end nodes");
			return [];
		}

		if (startNodeId == endNodeId)
		{
			// Already at destination
			var endNode = NavMesh.getNode(endNodeId);
			return [FlxPoint.get(endNode.worldX, endNode.worldY)];
		}

		// Use A* algorithm on the navigation mesh
		var path = aStar(startNodeId, endNodeId);

		if (path.length == 0)
		{
			trace("Pathfinding: No path found between nodes " + startNodeId + " and " + endNodeId);
			return [];
		}

		// Convert node path to world coordinates
		var worldPath:Array<FlxPoint> = [];
		for (nodeId in path)
		{
			var node = NavMesh.getNode(nodeId);
			if (node != null)
			{
				worldPath.push(FlxPoint.get(node.worldX, node.worldY));
			}
		}

		return worldPath;
	}

	/**
	 * A* pathfinding algorithm on navigation mesh
	 */
	private static function aStar(startNodeId:Int, endNodeId:Int):Array<Int>
	{
		var allNodes = NavMesh.getAllNodes();
		var openSet:Array<Int> = [startNodeId];
		var closedSet:Array<Int> = [];
		var cameFrom:Map<Int, Int> = new Map();
		var gScore:Map<Int, Float> = new Map();
		var fScore:Map<Int, Float> = new Map();

		// Initialize scores
		for (node in allNodes)
		{
			if (node.isWalkable)
			{
				gScore[node.id] = Math.POSITIVE_INFINITY;
				fScore[node.id] = Math.POSITIVE_INFINITY;
			}
		}

		gScore[startNodeId] = 0;
		fScore[startNodeId] = heuristic(startNodeId, endNodeId);

		while (openSet.length > 0)
		{
			// Find node with lowest fScore
			var current = openSet[0];
			var currentFScore = fScore[current];

			for (nodeId in openSet)
			{
				if (fScore[nodeId] < currentFScore)
				{
					current = nodeId;
					currentFScore = fScore[nodeId];
				}
			}

			if (current == endNodeId)
			{
				// Found path - reconstruct it
				return reconstructPath(cameFrom, current);
			}

			// Move current from open to closed set
			openSet.remove(current);
			closedSet.push(current);

			// Check all neighbors
			var currentNode = NavMesh.getNode(current);
			if (currentNode != null)
			{
				for (neighborId in currentNode.connections)
				{
					if (closedSet.indexOf(neighborId) >= 0)
					{
						continue; // Skip nodes in closed set
					}

					var neighborNode = NavMesh.getNode(neighborId);
					if (neighborNode == null || !neighborNode.isWalkable)
					{
						continue;
					}

					var tentativeGScore = gScore[current] + getDistance(current, neighborId);

					if (openSet.indexOf(neighborId) == -1)
					{
						openSet.push(neighborId); // Discover new node
					}
					else if (tentativeGScore >= gScore[neighborId])
					{
						continue; // Not a better path
					}

					// This is the best path so far
					cameFrom[neighborId] = current;
					gScore[neighborId] = tentativeGScore;
					fScore[neighborId] = gScore[neighborId] + heuristic(neighborId, endNodeId);
				}
			}
		}

		return []; // No path found
	}

	/**
	 * Reconstruct path from A* algorithm
	 */
	private static function reconstructPath(cameFrom:Map<Int, Int>, current:Int):Array<Int>
	{
		var path:Array<Int> = [current];

		while (cameFrom.exists(current))
		{
			current = cameFrom[current];
			path.unshift(current);
		}

		return path;
	}

	/**
	 * Heuristic function for A* (Euclidean distance)
	 */
	private static function heuristic(nodeId1:Int, nodeId2:Int):Float
	{
		return getDistance(nodeId1, nodeId2);
	}

	/**
	 * Get distance between two nodes
	 */
	private static function getDistance(nodeId1:Int, nodeId2:Int):Float
	{
		var node1 = NavMesh.getNode(nodeId1);
		var node2 = NavMesh.getNode(nodeId2);

		if (node1 == null || node2 == null)
		{
			return Math.POSITIVE_INFINITY;
		}

		var dx = node1.worldX - node2.worldX;
		var dy = node1.worldY - node2.worldY;

		return Math.sqrt(dx * dx + dy * dy);
	}

	/**
	 * Get debug information
	 */
	public static function getDebugInfo():String
	{
		return "NavMesh Pathfinding: " + NavMesh.getDebugInfo();
	}
}
