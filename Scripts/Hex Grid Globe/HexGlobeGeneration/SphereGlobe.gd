# In SphereGlobe.gd
@tool
class_name SphereGlobe
extends MeshInstance3D

@export var radius: float = 1.0:
	set = set_radius
@export var rings: int = 32
@export var radial_segments: int = 64
@export var globe_texture: Texture2D:
	set = set_globe_texture
@export var globe_material: Material

# Cache the decompressed image for performance
var _cached_image: Image = null

func _ready() -> void:
	_rebuild_mesh()
	_apply_material()

func set_radius(r: float) -> void:
	radius = max(0.001, r)
	if is_inside_tree():
		_rebuild_mesh()
		_apply_material()

func set_globe_texture(tex: Texture2D) -> void:
	globe_texture = tex
	_cached_image = null  # Clear cache when texture changes
	if is_inside_tree():
		_rebuild_mesh()
		_apply_material()


func _rebuild_mesh() -> void:
	var m := SphereMesh.new()
	m.radius = max(0.001, radius)
	m.height = m.radius * 2.0
	m.rings = max(8, rings)
	m.radial_segments = max(8, radial_segments)
	mesh = m
	# Keep the node transform at identity so children are not scaled again.
	transform = Transform3D()



func _apply_material() -> void:
	if globe_material:
		material_override = globe_material
	elif globe_texture:
		# Create a material with the texture if none is provided
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = globe_texture
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material_override = mat

func _get_sphere_radius() -> float:
	return radius

# Get or create the decompressed image
func _get_decompressed_image() -> Image:
	if _cached_image != null:
		return _cached_image
	
	if globe_texture == null:
		return null
	
	var image := globe_texture.get_image()
	if image == null:
		return null
	
	# Decompress if needed
	if image.is_compressed():
		print("Decompressing globe texture for pixel access...")
		image.decompress()
	
	_cached_image = image
	return _cached_image



# New function to get color at specific lat/lon coordinates
func get_color_at_coordinates(latitude: float, longitude: float) -> Color:
	var image := _get_decompressed_image()
	if image == null:
		return Color(1.0, 1.0, 1.0, 1.0)  # Default white if no texture
	
	# Normalize longitude to -180 to 180 range
	while longitude > 180.0:
		longitude -= 360.0
	while longitude < -180.0:
		longitude += 360.0
	
	# Clamp latitude to valid range
	latitude = clamp(latitude, -90.0, 90.0)
	
	# Convert lat/lon to UV coordinates
	# Standard equirectangular mapping
	var u := fmod((longitude + 180.0) / 360.0 + 1.0, 1.0)  # Wrap U coordinate
	var v := (90.0 - latitude) / 180.0  # V from top to bottom
	
	# Get texture size
	var texture_size := image.get_size()
	if texture_size.x <= 0 or texture_size.y <= 0:
		return Color(1.0, 1.0, 1.0, 1.0)
	
	# Convert UV to pixel coordinates with proper wrapping
	var pixel_x := int(u * texture_size.x) % int(texture_size.x)
	var pixel_y := int(v * texture_size.y)
	
	# Handle edge cases with clamping
	if pixel_x < 0:
		pixel_x += int(texture_size.x)
	if pixel_x >= texture_size.x:
		pixel_x = int(texture_size.x) - 1
		
	pixel_y = clampi(pixel_y, 0, int(texture_size.y) - 1)
	
	return image.get_pixel(pixel_x, pixel_y)


func _get_texture_color_from_position(pos: Vector3, sphere_globe: SphereGlobe) -> Color:
	var n := pos.normalized()
	
	# The issue is the longitude needs to be negated to match the texture
	var lat := asin(clamp(n.y, -1.0, 1.0))
	var lon := atan2(n.z, n.x)  # Standard calculation
	
	# Convert to degrees
	var latitude := rad_to_deg(lat)
	var longitude := -rad_to_deg(lon)  # Negate longitude to flip east/west
	
	return sphere_globe.get_color_at_coordinates(latitude, longitude)
