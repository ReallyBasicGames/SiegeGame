package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.Vector;

/**
 * Simple FPS graph and monitor for performance testing
 */
class FPSGraph extends FlxGroup
{
	// Graph settings
	private static inline var GRAPH_WIDTH:Int = 400;
	private static inline var GRAPH_HEIGHT:Int = 100;
	private static inline var MAX_SAMPLES:Int = 200; // Number of FPS samples to store
	private static inline var TARGET_FPS:Float = 60.0;

	// Visual components
	private var background:FlxSprite;
	private var fpsText:FlxText;
	private var avgText:FlxText;
	private var minText:FlxText;
	private var graphPixels:Vector<UInt>;

	// FPS tracking
	private var fpsSamples:Array<Float> = [];
	private var currentSample:Int = 0;
	private var updateTimer:Float = 0;
	private var updateInterval:Float = 0.1; // Update graph 10 times per second

	public function new()
	{
		super();

		// Position at bottom of screen
		var startX = FlxG.width - GRAPH_WIDTH - 10;
		var startY = FlxG.height - GRAPH_HEIGHT - 40;

		// Create background
		background = new FlxSprite(startX, startY);
		background.makeGraphic(GRAPH_WIDTH, GRAPH_HEIGHT, FlxColor.BLACK);
		background.alpha = 0.7;
		background.scrollFactor.set(0, 0); // Stay fixed on screen
		add(background);

		// Create FPS text display
		fpsText = new FlxText(startX + 5, startY - 30, GRAPH_WIDTH, "FPS: 60");
		fpsText.setFormat(null, 12, FlxColor.WHITE, "left");
		fpsText.scrollFactor.set(0, 0);
		add(fpsText);

		// Create average FPS text
		avgText = new FlxText(startX + 100, startY - 30, GRAPH_WIDTH, "Avg: 60");
		avgText.setFormat(null, 12, FlxColor.YELLOW, "left");
		avgText.scrollFactor.set(0, 0);
		add(avgText);

		// Create minimum FPS text
		minText = new FlxText(startX + 180, startY - 30, GRAPH_WIDTH, "Min: 60");
		minText.setFormat(null, 12, FlxColor.RED, "left");
		minText.scrollFactor.set(0, 0);
		add(minText);

		// Initialize graph pixel array
		graphPixels = new Vector<UInt>(GRAPH_WIDTH * GRAPH_HEIGHT);
		for (i in 0...(GRAPH_WIDTH * GRAPH_HEIGHT))
		{
			graphPixels[i] = FlxColor.BLACK;
		}

		// Initialize FPS samples array
		for (i in 0...MAX_SAMPLES)
		{
			fpsSamples[i] = TARGET_FPS;
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		updateTimer += elapsed;

		if (updateTimer >= updateInterval)
		{
			updateTimer = 0;
			updateFPSGraph();
		}
	}

	private function updateFPSGraph():Void
	{
		// Get current FPS
		var currentFPS = 1.0 / FlxG.elapsed;
		if (currentFPS > 200)
			currentFPS = 200; // Cap at 200 for display

		// Store FPS sample
		fpsSamples[currentSample] = currentFPS;
		currentSample = (currentSample + 1) % MAX_SAMPLES;

		// Calculate statistics
		var totalFPS:Float = 0;
		var minFPS:Float = 999;
		var validSamples:Int = 0;

		for (sample in fpsSamples)
		{
			if (sample > 0)
			{
				totalFPS += sample;
				if (sample < minFPS)
					minFPS = sample;
				validSamples++;
			}
		}

		var avgFPS = validSamples > 0 ? totalFPS / validSamples : 60;
		if (minFPS == 999)
			minFPS = 60;

		// Update text displays
		fpsText.text = "FPS: " + Math.round(currentFPS);
		avgText.text = "Avg: " + Math.round(avgFPS * 10) / 10;
		minText.text = "Min: " + Math.round(minFPS);

		// Update FPS text color based on performance
		if (currentFPS >= TARGET_FPS * 0.9)
			fpsText.color = FlxColor.GREEN;
		else if (currentFPS >= TARGET_FPS * 0.7)
			fpsText.color = FlxColor.YELLOW;
		else
			fpsText.color = FlxColor.RED;

		// Redraw graph
		redrawGraph();
	}

	private function redrawGraph():Void
	{
		// Clear graph
		for (i in 0...graphPixels.length)
		{
			graphPixels[i] = FlxColor.BLACK;
		}

		// Draw grid lines
		drawHorizontalLine(GRAPH_HEIGHT - 1, FlxColor.GRAY); // Bottom line
		drawHorizontalLine(Math.floor(GRAPH_HEIGHT * 0.5), FlxColor.GRAY); // Middle line (30 FPS)
		drawHorizontalLine(Math.floor(GRAPH_HEIGHT * 0.25), FlxColor.GRAY); // 45 FPS line

		// Draw target FPS line (60 FPS)
		var targetY = Math.floor(GRAPH_HEIGHT - (TARGET_FPS / 120.0 * GRAPH_HEIGHT));
		drawHorizontalLine(targetY, FlxColor.GREEN);

		// Draw FPS samples
		var samplesPerPixel = Math.ceil(MAX_SAMPLES / GRAPH_WIDTH);

		for (x in 0...GRAPH_WIDTH)
		{
			var sampleIndex = Math.floor(x * MAX_SAMPLES / GRAPH_WIDTH);
			var fps = fpsSamples[sampleIndex];

			if (fps > 0)
			{
				// Convert FPS to Y position (0-120 FPS range)
				var normalizedFPS = FlxMath.bound(fps / 120.0, 0, 1);
				var y = Math.floor(GRAPH_HEIGHT - (normalizedFPS * GRAPH_HEIGHT));

				// Choose color based on FPS
				var color = FlxColor.GREEN;
				if (fps < TARGET_FPS * 0.9)
					color = FlxColor.YELLOW;
				if (fps < TARGET_FPS * 0.7)
					color = FlxColor.RED;

				// Draw vertical line for this sample
				for (lineY in y...GRAPH_HEIGHT)
				{
					setPixel(x, lineY, color);
				}
			}
		}

		// Apply pixels to background sprite
		background.pixels.setVector(background.pixels.rect, graphPixels);
	}

	private function drawHorizontalLine(y:Int, color:UInt):Void
	{
		if (y < 0 || y >= GRAPH_HEIGHT)
			return;

		for (x in 0...GRAPH_WIDTH)
		{
			setPixel(x, y, color);
		}
	}

	private function setPixel(x:Int, y:Int, color:UInt):Void
	{
		if (x < 0 || x >= GRAPH_WIDTH || y < 0 || y >= GRAPH_HEIGHT)
			return;

		var index = y * GRAPH_WIDTH + x;
		if (index >= 0 && index < graphPixels.length)
		{
			graphPixels[index] = color;
		}
	}

	/**
	 * Toggle visibility of the FPS graph
	 */
	public function toggle():Void
	{
		visible = !visible;
	}

	/**
	 * Reset FPS tracking
	 */
	public function reset():Void
	{
		for (i in 0...MAX_SAMPLES)
		{
			fpsSamples[i] = TARGET_FPS;
		}
		currentSample = 0;
	}
}
