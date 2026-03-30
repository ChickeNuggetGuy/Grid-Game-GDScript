@tool
extends Node

# Path to your JSON file
@export_file("*.json") var source_json_path: String = "res://RawData/cities_filtered.json"
# Path to save the image
@export_file("*.png") var output_texture_path: String = "res://Textures/MapData/cities_data_map.png"

@export var map_width: int = 4096
@export var map_height: int = 2048

@export_group("Adjustments")
## Slide the dots left/right. 0.5 shifts the map by 180 degrees.
@export var texture_offset: Vector2 = Vector2(0.0, 0.0) 

# Button to trigger baking
@export var bake_now: bool = false:
	set(value):
		if value:
			_run_debug_bake()
		bake_now = false

func _run_debug_bake():
	print("\n=== STARTING DEBUG BAKE ===")
	
	if not FileAccess.file_exists(source_json_path):
		push_error("❌ FAIL: JSON file not found at: " + source_json_path)
		return
	
	var file = FileAccess.open(source_json_path, FileAccess.READ)
	var content = file.get_as_text()
	var json = JSON.parse_string(content)
	
	if json == null:
		push_error("❌ FAIL: JSON could not be parsed.")
		return

	var cities_array = []
	if json is Dictionary and json.has("cities"):
		cities_array = json["cities"]
	elif json is Array:
		cities_array = json
	else:
		push_error("❌ FAIL: Unexpected JSON structure.")
		return

	print("✅ JSON Loaded. Found %d city entries." % cities_array.size())

	var img = Image.create(map_width, map_height, false, Image.FORMAT_RGBA8)
	
	# Background: Clear black (Alpha 0) so it layers correctly
	img.fill(Color(0, 0, 0, 0)) 
	
	var success_count = 0
	
	for i in range(cities_array.size()):
		var city = cities_array[i]
		var lat = 0.0
		var lon = 0.0
		var found_coords = false

		if city.has("coordinates"):
			var c = city["coordinates"]
			if c is Dictionary and c.has("lat") and c.has("lon"):
				lat = float(c["lat"])
				lon = float(c["lon"])
				found_coords = true
		elif city.has("lat") and city.has("lon"):
			lat = float(city["lat"])
			lon = float(city["lon"])
			found_coords = true

		if not found_coords:
			continue

		# --- FIXED MAPPING LOGIC ---
		
		# 1. Base Map (Standard Equirectangular)
		var u = (lon + 180.0) / 360.0
		var v = 1.0 - ((lat + 90.0) / 180.0)
		
		# 2. Apply Manual Offset (Slides the map)
		u += texture_offset.x
		v += texture_offset.y
		
		# 3. Wrap Logic (Fixes the edge clamping issue)
		# fmod wraps the value, e.g., 1.1 becomes 0.1
		u = fmod(u, 1.0)
		v = fmod(v, 1.0)
		
		# Handle negative wrapping (e.g., -0.1 becomes 0.9)
		if u < 0.0: u += 1.0
		if v < 0.0: v += 1.0

		var x = int(u * (map_width - 1))
		var y = int(v * (map_height - 1))
		
		# Draw City Pixel (Red channel = Population/Density marker)
		# We add to existing color instead of setting it, to handle overlapping cities
		var existing = img.get_pixel(x, y)
		var strength = min(existing.r + 0.2, 1.0) # Accumulate intensity
		
		img.set_pixel(x, y, Color(strength, 0, 0, 1))
		
		# Draw larger dot for visibility
		_draw_dot(img, x, y, Color.WHITE)
		
		success_count += 1

	print("✅ Processing Complete. Plotted: %d" % success_count)

	var err = img.save_png(output_texture_path)
	if err != OK:
		push_error("❌ FAIL: Could not save PNG. Error code: " + str(err))
	else:
		print("✅ SUCCESS: Saved texture to ", output_texture_path)
		if Engine.is_editor_hint():
			var fs = EditorInterface.get_resource_filesystem()
			fs.scan()
			
func _draw_dot(img: Image, x: int, y: int, col: Color):
	var w = img.get_width()
	var h = img.get_height()
	# 3x3 Brush
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			# Wrap X for drawing (so a dot on the edge appears on the other side)
			var nx = posmod(x + dx, w)
			var ny = clamp(y + dy, 0, h - 1) # Don't wrap Y (Poles)
			img.set_pixel(nx, ny, col)
