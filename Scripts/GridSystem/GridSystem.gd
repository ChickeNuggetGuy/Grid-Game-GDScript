@tool
extends Manager
class_name GridSystem
#region Variables
var grid_cells: Dictionary[Vector3i,GridCell]
var collected_grid_objects: Array[GridObject] = []  # New list for collected grid objects

#region Grid Validation Settings
@export var raycastCheck : bool = true
@export var raycastOffset: Vector3  = Vector3(0, 0.4,0)
@export var  raycastLength : float = 10

@export var  colliderCheck : bool = false
@export var  colliderSize : Vector3
@export var  collideroffset : Vector3

@export var grid_cell_overrides : Array[GridCellStateOverride] = []
#endregion
#endregion

#region
func _get_manager_name() -> String: return "GridSystem"

func _setup_conditions(): return true

func _setup(): 
	setup_completed.emit()

func _execute_conditions() -> bool: return true

func _execute():
	collected_grid_objects.clear()  # Clear the list before setup
	await setup_grid()
	
	# Process collected grid objects after all grid cells are setup
	await setup_collected_grid_objects()
	
	for override in get_tree().get_nodes_in_group("grid_cell_overrides"):
		if override is GridCellStateOverride:
			grid_cell_overrides.append(override)
			override.set_cell_overrides()
	
	execution_completed.emit()

func setup_grid():
	grid_cells = {}
	var map_grid_size = GameManager.managers["MeshTerrainManager"].get_map_cell_size()
	var cell_size = GameManager.managers["MeshTerrainManager"].cell_size
	var spaceState = get_tree().root.world_3d.direct_space_state

	for layer in range(map_grid_size.y):
		for x in range(map_grid_size.x):
			for z in range(map_grid_size.z):
				var position = Vector3(
					x * cell_size.x + (cell_size.x * 0.5),
					layer * cell_size.y + (cell_size.y * 0.5),
					z * cell_size.x + (cell_size.x * 0.5)
				)

				var result = determine_cell_state(spaceState, position, layer)
				
				var coords = Vector3i(x, layer, z)
				create_or_update_cell(coords, result["position"], result["cell_state"])

	print("Grid setup complete: ", grid_cells.size(), " cells")

# New function to setup collected grid objects
func setup_collected_grid_objects():
	print("Setting up ", collected_grid_objects.size(), " collected grid objects")
	
	for grid_object in collected_grid_objects:
		if grid_object == null or not is_instance_valid(grid_object):
			continue
			
		# Get the grid object's world position
		var world_pos = grid_object.global_position
		
		## Try to get the corresponding grid cell
		var result = try_get_gridCell_from_world_position(world_pos, true)
		if result["success"]:
			var grid_cell: GridCell = result["grid_cell"]
			

			var direction = Enums.facingDirection.NORTH 
			var team = Enums.unitTeam.ANY 
			grid_object._setup(grid_cell, direction,team)
			## If the grid object has methods to determine its direction/team, use those
			#if grid_object.has_method("get_facing_direction"):
				#direction = grid_object.get_facing_direction()
			#if grid_object.has_method("get_team"):
				#team = grid_object.get_team()
			#
			## Setup the grid object
			#grid_object._setup(grid_cell, direction, team)
			#print("Setup grid object at: ", grid_cell.grid_coordinates)
		#else:
			#print("Failed to find grid cell for grid object at: ", world_pos)

func is_position_obstructed(spaceState: PhysicsDirectSpaceState3D, position: Vector3) -> bool:
	var box = BoxShape3D.new()
	box.size = colliderSize
	
	var cell_size = GameManager.managers["MeshTerrainManager"].cell_size
	
	var test_points = [
		position + collideroffset,
		position + collideroffset + Vector3(cell_size.x * 0.25, 0, cell_size.x * 0.25),
		position + collideroffset + Vector3(-cell_size.x * 0.25, 0, cell_size.x * 0.25),
		position + collideroffset + Vector3(cell_size.x * 0.25, 0, -cell_size.x * 0.25),
		position + collideroffset + Vector3(-cell_size.x * 0.25, 0, -cell_size.x * 0.25)
	]
	
	var is_obstructed = false
	
	for i in range(test_points.size()):
		var test_point = test_points[i]
		
		var qp = PhysicsShapeQueryParameters3D.new()
		qp.shape = box
		qp.transform = Transform3D(Basis.IDENTITY, test_point)
		qp.collide_with_bodies = true
		qp.collide_with_areas = false
		
		var collision_mask = PhysicsLayer.TERRAIN | PhysicsLayer.OBSTACLE
		qp.collision_mask = 0xFFFFFFFF
		
		var hits = spaceState.intersect_shape(qp)
		
		# Check each hit for GridObjects
		for hit in hits:
			var collider = hit.get("collider")
			if collider != null:
				# Check if the collider or its parent is a GridObject
				var grid_object = find_grid_object_in_hierarchy(collider)
				if grid_object != null and not collected_grid_objects.has(grid_object):
					collected_grid_objects.append(grid_object)
					print("Found GridObject during collision check: ", grid_object.name)
		
		if hits.size() > 1:
			DebugDraw3D.draw_box(position, Quaternion.IDENTITY, box.size, Color.RED, true, 10)
			is_obstructed = true
	
	return is_obstructed

# Helper function to find GridObject in the node hierarchy
func find_grid_object_in_hierarchy(node: Node) -> GridObject:
	var current = node
	
	# Search up the hierarchy for a GridObject
	while current != null:
		if current is GridObject:
			return current as GridObject
		current = current.get_parent()
	
	return null

func determine_cell_state(spaceState: PhysicsDirectSpaceState3D, position: Vector3, layer: int) -> Dictionary:
	var return_value : Dictionary = {"cell_state": Enums.cellState.NONE, "position": position}
	
	if colliderCheck and is_position_obstructed(spaceState, position):
		print("Cell marked as OBSTRUCTED")
		return_value["cell_state"] = Enums.cellState.OBSTRUCTED
		return return_value
	
	# Enhanced raycast check
	if raycastCheck:
		return perform_enhanced_raycast_check(spaceState, position, layer)
	
	return return_value

func perform_enhanced_raycast_check(spaceState: PhysicsDirectSpaceState3D, position: Vector3, layer: int) -> Dictionary:
	var cell_size = GameManager.managers["MeshTerrainManager"].cell_size
	
	var return_value = {"cell_state":Enums.cellState.NONE, "position" : position}
	
	var ray_offsets = [
		Vector3(0, 0, 0),  # Center
		Vector3(cell_size.x * 0.25, 0, cell_size.x * 0.25),   # Corners
		Vector3(-cell_size.x * 0.25, 0, cell_size.x * 0.25),
		Vector3(cell_size.x * 0.25, 0, -cell_size.x * 0.25),
		Vector3(-cell_size.x * 0.25, 0, -cell_size.x * 0.25)
	]
	
	var walkable_hits = 0
	var total_rays = ray_offsets.size()
	var adjusted_position = position
	
	for offset in ray_offsets:
		var rayStart = position + offset + raycastOffset
		var rayEnd = rayStart - Vector3(0, raycastLength, 0)
		
		var rq = PhysicsRayQueryParameters3D.new()
		rq.from = rayStart
		rq.to = rayEnd
		rq.collide_with_bodies = true
		rq.collide_with_areas = true
		rq.hit_from_inside = true
		rq.collision_mask = PhysicsLayer.TERRAIN
		
		var r = spaceState.intersect_ray(rq)
		
		if r:
			var hitY = r.position.y
			var cell_bottom_y = float(layer) * cell_size.y
			var cell_top_y = float(layer + 1) * cell_size.y
			
			if hitY >= cell_bottom_y and hitY < cell_top_y:
				walkable_hits += 1
				
				if offset == Vector3.ZERO:
					adjusted_position.y = hitY
	
	# Determine state based on hit ratio
	var walkable_ratio = float(walkable_hits) / float(total_rays)
	
	if walkable_ratio >= 0.6:  # At least 60% of rays hit walkable ground
		position.y = adjusted_position.y  
		return_value["position"] = position
		return_value["cell_state"] = Enums.cellState.WALKABLE
		return return_value
	elif walkable_ratio > 0:
		position.y = adjusted_position.y  
		return_value["position"] = position
		return_value["cell_state"] = Enums.cellState.GROUND
		return return_value
	else:
		return_value["cell_state"] = Enums.cellState.AIR
		return return_value

func visualize_cell(position: Vector3, cell_state: Enums.cellState):
	var cell_size = GameManager.managers["MeshTerrainManager"].cell_size
	var color = Color.WHITE
	match cell_state:
		Enums.cellState.WALKABLE:
			color = Color.LIME_GREEN
		Enums.cellState.GROUND:
			color = Color.YELLOW
		Enums.cellState.OBSTRUCTED:
			color = Color.RED
		Enums.cellState.AIR:
			color = Color.CYAN
		_:
			color = Color.GRAY
	
	if cell_state & Enums.cellState.AIR:
		return
		
	DebugDraw3D.draw_box(position, Quaternion.IDENTITY, 
		Vector3(cell_size.x, cell_size.y, cell_size.x), color, true, 20)

func create_or_update_cell(coords: Vector3i, position: Vector3, cell_state: Enums.cellState):
	if not grid_cells.has(coords) || grid_cells[coords] == null:
		var result = InventoryManager.try_get_inventory_grid(Enums.inventoryType.GROUND)
		var ground_inventory_grid = result["inventory_grid"]
		var cell = GridCell.new(coords.x, coords.y, coords.z, position, cell_state, Enums.FogState.UNSEEN, ground_inventory_grid)
		grid_cells[coords] = cell
	else:
		grid_cells[coords].grid_cell_state = cell_state
		grid_cells[coords].worldPosition = position


# Helper function to handle raycast logic cleanly
func perform_raycast_check(spaceState: PhysicsDirectSpaceState3D, position: Vector3, layer: int) -> Enums.cellState:
	var cell_size = GameManager.managers["MeshTerrainManager"].cell_size

	
	var rayStart = position + raycastOffset
	var rayEnd = position + raycastOffset - Vector3(0, raycastLength, 0)
	var rq = PhysicsRayQueryParameters3D.new()
	rq.from = rayStart
	rq.to = rayEnd
	rq.collide_with_bodies = true
	rq.collide_with_areas = true
	rq.hit_from_inside = true
	rq.collision_mask = PhysicsLayer.TERRAIN
	var r = spaceState.intersect_ray(rq)

	if r:
		var hitY = r.position.y
		var cell_bottom_y = float(layer) * cell_size.y
		var cell_top_y = float(layer + 1) * cell_size.y

		# Check if the hit is strictly within the cell's vertical bounds
		if hitY >= cell_bottom_y and hitY < cell_top_y:
			# Update position to ground level
			position.y = hitY
			return Enums.cellState.WALKABLE
		else:
			return Enums.cellState.AIR
	else:
		return Enums.cellState.AIR


func set_cell(grid_coords : Vector3i, value: GridCell) -> void:
	
	if(value.grid_coordinates == null || value.grid_coordinates != grid_coords):
		value.grid_coordinates = grid_coords
		
	grid_cells[grid_coords] = value


func get_grid_cell(grid_coords : Vector3i,  default_value = null):
	return grid_cells.get(grid_coords, default_value)


func has_cell(grid_coords : Vector3i) -> bool:
	return grid_cells.has(grid_coords)


func remove_cell(grid_coords : Vector3i) -> void:
	grid_cells.erase(grid_coords)


func try_get_gridCell_from_world_position(worldPosition: Vector3, nullGetNearest: bool = false) -> Dictionary:
	var retVal: Dictionary = {"success": false, "grid_cell": null}


	var cell_size = GameManager.managers["MeshTerrainManager"].cell_size
	var map_grid_size = GameManager.managers["MeshTerrainManager"].get_map_cell_size()

	if (cell_size.x <= 0 or cell_size.y <= 0): 
		push_error("Either Grid cell size X or Y is set to 0! Returning")
		return retVal 

	var x_coord = int(floor(worldPosition.x / cell_size.x))
	var y_coord = int(floor(worldPosition.y / cell_size.y))
	var z_coord = int(floor(worldPosition.z / cell_size.x))

	
	x_coord = clamp(x_coord, 0, map_grid_size.x - 1)
	y_coord = clamp(y_coord, 0, map_grid_size.y - 1)
	z_coord = clamp(z_coord, 0, map_grid_size.z - 1) 
	
	var target_key = Vector3i(x_coord,y_coord, z_coord) 
	
	if grid_cells.has(target_key):
		
		retVal["grid_cell"] = grid_cells[target_key]
		retVal["success"] = true
		return retVal
	elif (!nullGetNearest):
		retVal["success"] = false
		return retVal


	var minDistanceSq = INF
	var nearest_cell: GridCell = null

	for key_coords in grid_cells.keys():
		if key_coords.layer == y_coord:
			var candidate_cell: GridCell = grid_cells[key_coords]
			var distSq: float = (candidate_cell.worldPosition - worldPosition).length_squared()
			if distSq < minDistanceSq:
				minDistanceSq = distSq
				nearest_cell = candidate_cell

	if nearest_cell != null:
		retVal["grid_cell"] = nearest_cell
		retVal["Success"] = true
		return retVal

	retVal["grid_cell"] = null
	retVal["Success"] = false
	return retVal


func get_cell_below_recursive(grid_coords : Vector3i, cell_state_filter : Enums.cellState) -> GridCell:
	if grid_cells[grid_coords] == null: return null
	
	var grid_cell : GridCell = grid_cells[grid_coords]
	var test_coords = Vector3i(grid_coords.x, grid_coords.y -1,grid_coords.z)

	
	if not grid_cells.has(test_coords): return null
	
	var test_grid_cell = grid_cells[test_coords]
		
	if  cell_state_filter != Enums.cellState.NONE and test_grid_cell.grid_cell_state != cell_state_filter:
		return get_cell_below_recursive(test_coords, cell_state_filter)
		
	else: return test_grid_cell

func try_get_grid_cell_of_state_below(grid_coords: Vector3, wanted_cell_state: Enums.cellState) -> Dictionary:
	var ret_val = {"success": false, "grid_cell": null}
	var starting_grid_cell: GridCell = get_grid_cell(grid_coords)
	
	if starting_grid_cell == null:
		return ret_val
	
	# Search downward from the cell below the starting position
	for y_level in range(starting_grid_cell.grid_coordinates.y - 1, -1, -1):
		var temp_grid_cell: GridCell = get_grid_cell(Vector3(
			starting_grid_cell.grid_coordinates.x,
			y_level,
			starting_grid_cell.grid_coordinates.z
		))
		
		if temp_grid_cell == null:
			continue
		
		elif temp_grid_cell.grid_cell_state & wanted_cell_state:
			ret_val["success"] = true
			ret_val["grid_cell"] = temp_grid_cell
			return ret_val
	
	return ret_val



func try_get_cells_in_cone(
	origin_cell: GridCell,
	forward_direction: Vector3,
	max_distance: float,
	fov_horizontal_degrees: float,
	cell_state_filter: Enums.cellState = Enums.cellState.NONE
) -> Dictionary:
	# Initialize return structure with consistent naming
	var temp_grid_cells : Dictionary[Vector3i, GridCell] = {}
	var result: Dictionary = {
		"success": false,
		"cells": temp_grid_cells
	}
	
	# Validate input parameters
	if origin_cell == null:
		push_error("try_get_cells_in_cone: origin_cell cannot be null.")
		return result
		
	if max_distance <= 0:
		push_error("try_get_cells_in_cone: max_distance must be positive.")
		return result
		
	if fov_horizontal_degrees <= 0 or fov_horizontal_degrees > 360:
		push_error("try_get_cells_in_cone: fov_horizontal_degrees must be between 0 and 360.")
		return result

	
	var cell_size = GameManager.managers["MeshTerrainManager"].cell_size
	var search_radius_cells = ceil(max_distance / cell_size.x) + 1
	var origin_coords = origin_cell.grid_coordinates
	var origin_position = origin_cell.world_position
	var normalized_forward = forward_direction.normalized()
	
	
	var half_fov_rad = deg_to_rad(fov_horizontal_degrees / 2.0)
	var cos_half_fov = cos(half_fov_rad)
	
	# Pre-calculate squared max distance for efficient comparison
	var max_distance_sq = max_distance * max_distance
	
	
	for x in range(-search_radius_cells, search_radius_cells + 1):
		for z in range(-search_radius_cells, search_radius_cells + 1):
			for y in range(-search_radius_cells, search_radius_cells + 1):
				var test_coords = Vector3i(
					origin_coords.x + x,
					origin_coords.y + y,
					origin_coords.z + z
				)
				
				# Get candidate cell
				var candidate_cell: GridCell = get_grid_cell(test_coords)
				
				# Skip if no cell exists
				if candidate_cell == null:
					continue
				
				# Get candidate position
				var candidate_position = candidate_cell.world_position
				
				# Calculate vector from origin to candidate
				var to_candidate = candidate_position - origin_position
				
				# Quick distance check using squared distance
				var distance_sq = to_candidate.length_squared()
				if distance_sq > max_distance_sq:
					continue
				
				# Check if within cone using dot product instead of angle calculation
				# This is more efficient than angle_to
				var to_candidate_normalized = to_candidate.normalized()
				var dot_product = normalized_forward.dot(to_candidate_normalized)
				
				# If dot product is less than cosine of half FOV, it's outside the cone
				if dot_product < cos_half_fov:
					continue
				
				# Apply cell state filter if specified
				if cell_state_filter != Enums.cellState.NONE:
					if not (candidate_cell.grid_cell_state & cell_state_filter):
						continue
				
				# If all checks pass, add the cell to results
				result["cells"][candidate_cell.grid_coordinates] = candidate_cell
				
			
				if debug_mode:
					DebugDraw3D.draw_box(
						candidate_position, 
						Quaternion.IDENTITY,
						Vector3(cell_size.x, cell_size.y, cell_size.x), 
						Color.MAGENTA, 
						true, 
						5
					)

	result["success"] = not result["cells"].is_empty()
	
	return result


func try_get_grid_cells_in_area(area: Area3D, cell_state_filter: Enums.cellState = Enums.cellState.NONE) -> Dictionary:
	var temp_grid_cells: Array[GridCell] = []
	var result: Dictionary = {
		"success": false,
		"grid_cells": temp_grid_cells
	}
	
	if area == null:
		push_error("try_get_cells_in_area: area cannot be null.")
		return result
	
	var cell_size = GameManager.managers["MeshTerrainManager"].cell_size
	
	var area_aabb := AABB()
	var has_shapes := false
	
	for child in area.get_children():
		if child is CollisionShape3D:
			var collision_shape := child as CollisionShape3D
			if collision_shape.shape != null:
				var shape_aabb := collision_shape.shape.get_debug_mesh().get_aabb()
				var transformed_aabb := collision_shape.global_transform * shape_aabb
				
				if not has_shapes:
					area_aabb = transformed_aabb
					has_shapes = true
				else:
					area_aabb = area_aabb.merge(transformed_aabb)
	
	if not has_shapes:
		push_error("try_get_cells_in_area: area has no valid CollisionShape3D children.")
		return result
	
	var min_coords := Vector3i(
		int(floor(area_aabb.position.x / cell_size.x)),
		int(floor(area_aabb.position.y / cell_size.y)),
		int(floor(area_aabb.position.z / cell_size.x))
	)
	
	var max_coords := Vector3i(
		int(ceil(area_aabb.end.x / cell_size.x)),
		int(ceil(area_aabb.end.y / cell_size.y)),
		int(ceil(area_aabb.end.z / cell_size.x))
	)
	
	var map_grid_size = GameManager.managers["MeshTerrainManager"].get_map_cell_size()
	min_coords.x = clamp(min_coords.x, 0, map_grid_size.x - 1)
	min_coords.y = clamp(min_coords.y, 0, map_grid_size.y - 1)
	min_coords.z = clamp(min_coords.z, 0, map_grid_size.z - 1)
	max_coords.x = clamp(max_coords.x, 0, map_grid_size.x - 1)
	max_coords.y = clamp(max_coords.y, 0, map_grid_size.y - 1)
	max_coords.z = clamp(max_coords.z, 0, map_grid_size.z - 1)
	
	for x in range(min_coords.x, max_coords.x + 1):
		for y in range(min_coords.y, max_coords.y + 1):
			for z in range(min_coords.z, max_coords.z + 1):
				var test_coords := Vector3i(x, y, z)
				var candidate_cell: GridCell = get_grid_cell(test_coords)
				
				if candidate_cell == null:
					continue
				
				
				if cell_state_filter != Enums.cellState.NONE:
					if not (candidate_cell.grid_cell_state & cell_state_filter):
						continue
				
				var cell_position := candidate_cell.world_position
				
				
				var test_sphere := SphereShape3D.new()
				test_sphere.radius = min(cell_size.x, cell_size.y) * 0.1 
				
				var space_state := area.get_world_3d().direct_space_state
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = test_sphere
				query.transform = Transform3D(Basis.IDENTITY, cell_position)
				query.collide_with_areas = true
				query.collide_with_bodies = false
				
				var intersections := space_state.intersect_shape(query)
				
				for intersection in intersections:
					if intersection.collider == area:
						result["grid_cells"].append(candidate_cell)
						break
	
	result["success"] = result["grid_cells"].size() > 0
	return result

# Returns the highest integer y‐layer in `grid`. Assumes y ≥ 0.
func get_max_height() -> int:
	var max_height := 0
	for key in grid_cells.keys():
		# if you’re using float‐y Vector3s, cast to int
		var layer := int(key.layer)
		max_height = max(max_height, layer)
	return max_height


func get_min_height() -> int:
	var min_height := 0
	for key in grid_cells.keys():
		# if you’re using float‐y Vector3s, cast to int
		var layer := int(key.layer)
		min_height = min(min_height, layer)
	return min_height


func get_grid_cell_neighbors(target_grid_cell: GridCell, cell_state_filter: Enums.cellState = Enums.cellState.NONE) -> Array[GridCell]:
	var ret_val: Array[GridCell] = []
	
	# Iterate through all 26 neighbors (including diagonals)
	for x in range(-1, 2):  # -1, 0, 1
		for y in range(-1, 2):  # -1, 0, 1
			for z in range(-1, 2):  # -1, 0, 1
				# Skip the center cell (0, 0, 0)
				if x == 0 and y == 0 and z == 0:
					continue
				
				# Calculate the neighbor's coordinates
				var test_coords = Vector3i(
					target_grid_cell.grid_coordinates.x + x,
					target_grid_cell.grid_coordinates.y + y,
					target_grid_cell.grid_coordinates.z + z
				)
				
				# Check if the neighbor exists in the grid
				if not grid_cells.has(test_coords):
					continue
				
				if (cell_state_filter != Enums.cellState.NONE and grid_cells[test_coords].grid_cell_state != cell_state_filter):
					continue
					
				ret_val.append(grid_cells[test_coords])
	
	return ret_val


func try_get_randomGrid_cell() -> Dictionary:
	
	var cell = grid_cells.values().pick_random()
	
	
	return {"success": true,"cell":cell}


func try_get_neighbors_in_radius(starting_grid_cell: GridCell,	radius: float,	grid_cell_state_filter: Enums.cellState = Enums.cellState.NONE
) -> Dictionary:
	var grid_cells_dict: Dictionary[Vector3i, GridCell] = {}
	var ret_value = {"success": false, "grid_cells": grid_cells_dict}
	
	if starting_grid_cell == null:
			return ret_value
	
	# Define the bounding box based on the radius
	var min_bound = Vector3i(-ceil(radius), -ceil(radius), -ceil(radius))
	var max_bound = Vector3i(ceil(radius), ceil(radius), ceil(radius))
	
	for x in range(min_bound.x, max_bound.x + 1):
			for y in range(min_bound.y, max_bound.y + 1):
				for z in range(min_bound.z, max_bound.z + 1):
					var offset: Vector3i = Vector3i(x, y, z)
					var test_coord: Vector3i = starting_grid_cell.grid_coordinates + offset
					var test_grid_cell: GridCell = get_grid_cell(test_coord)
					
					if test_grid_cell == null:
						continue
					
					if grid_cell_state_filter != Enums.cellState.NONE and (test_grid_cell.grid_cell_state & grid_cell_state_filter) != grid_cell_state_filter:
						continue
					
					# Check Euclidean distance for circular radius
					var distance_squared: float = offset.length_squared()
					
					if distance_squared <= radius * radius:
						ret_value["grid_cells"][test_grid_cell.grid_coordinates] = test_grid_cell
	
	ret_value["success"] = ret_value["grid_cells"].size() > 0
	return ret_value



func try_get_random_walkable_cell(team_filter: Enums.unitTeam = Enums.unitTeam.ANY) -> Dictionary:
	var ret_value: Dictionary = {"success": false, "grid_cell": null}
	var valid_grid_cells: Array[GridCell] = []
	
	for grid_cell in grid_cells.values():
		if not grid_cell:
			continue
		
		if not (grid_cell.grid_cell_state & Enums.cellState.WALKABLE):
			continue
		
		if team_filter != Enums.unitTeam.ANY and grid_cell.team_spawn != team_filter:
			continue
		
		valid_grid_cells.append(grid_cell)
	
	if valid_grid_cells.is_empty():
		return ret_value
	
	var random_grid_cell: GridCell = valid_grid_cells.pick_random()
	
	ret_value["success"] = true
	ret_value["grid_cell"] = random_grid_cell
	return ret_value

func get_distance_between_grid_cells(from_grid_cell : GridCell, to_grid_cell : GridCell) -> float:
	return from_grid_cell.world_position.distance_to(to_grid_cell.world_position)
	
#endregion
