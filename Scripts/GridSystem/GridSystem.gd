@tool
extends Manager
class_name GridSystem
#region Varibles
var grid_cells: Dictionary[Vector3i,GridCell]

#region Grid Validation Settings
@export var raycastCheck : bool = true
@export var raycastOffset: Vector3  = Vector3(0, 0.4,0)
@export var  raycastLength : float = 10

@export var  colliderCheck : bool = false
@export var  colliderSize : Vector3
@export var  collideroffset : Vector3
@export var  colliderLength : float

#@export var groundInventoryPrefab: InventoryGrid;
#endregion
#endregion

#region
func _get_manager_name() -> String: return "GridSystem"

func _setup_conditions(): return true


func _setup(): 
	setup_completed.emit()

func _execute_conditions() -> bool: return true

func _execute():
	await setup_grid()
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

				# Debug visualization
				#visualize_cell(position, cell_state)

				# Create/update grid cell
				var coords = Vector3i(x, layer, z)
				create_or_update_cell(coords, result["position"], result["cell_state"])

	print("Grid setup complete: ", grid_cells.size(), " cells")


func get_passable_data() -> Dictionary:
	return {}



func determine_cell_state(spaceState: PhysicsDirectSpaceState3D, position: Vector3, layer: int) -> Dictionary:
	var return_value : Dictionary = {"cell_state": Enums.cellState.NONE, "position": position}
	
	# Multi-point collision detection for better hill detection
	if colliderCheck and is_position_obstructed(spaceState, position):
		return_value["cell_state"] = Enums.cellState.OBSTRUCTED
		return return_value
	
	# Enhanced raycast check
	if raycastCheck:
		return perform_enhanced_raycast_check(spaceState, position, layer)
	
	return return_value

func is_position_obstructed(spaceState: PhysicsDirectSpaceState3D, position: Vector3) -> bool:
	var box = BoxShape3D.new()
	box.size = colliderSize
	
	var cell_size = GameManager.managers["MeshTerrainManager"].Instance.cell_size
	# Test multiple points within the cell for better hill detection
	var test_points = [
		position + collideroffset,  # Center
		position + collideroffset + Vector3(cell_size.x * 0.25, 0, cell_size.x * 0.25),  # Corner
		position + collideroffset + Vector3(-cell_size.x * 0.25, 0, cell_size.x * 0.25), # Corner
		position + collideroffset + Vector3(cell_size.x * 0.25, 0, -cell_size.x * 0.25), # Corner
		position + collideroffset + Vector3(-cell_size.x * 0.25, 0, -cell_size.x * 0.25) # Corner
	]
	
	for test_point in test_points:
		var qp = PhysicsShapeQueryParameters3D.new()
		qp.shape = box
		qp.transform = Transform3D(Basis.IDENTITY, test_point)
		qp.collide_with_bodies = true
		qp.collide_with_areas = true
		qp.collision_mask = PhysicsLayer.TERRAIN
		
		var hits = spaceState.intersect_shape(qp)
		if hits.size() > 0:
			return true
	
	return false

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

	# Cache frequently used values
	var cell_size = GameManager.managers["MeshTerrainManager"].cell_size
	var search_radius_cells = ceil(max_distance / cell_size.x) + 1
	var origin_coords = origin_cell.grid_coordinates
	var origin_position = origin_cell.world_position
	var normalized_forward = forward_direction.normalized()
	
	# Pre-calculate cosine of half FOV angle for efficiency
	var half_fov_rad = deg_to_rad(fov_horizontal_degrees / 2.0)
	var cos_half_fov = cos(half_fov_rad)
	
	# Pre-calculate squared max distance for efficient comparison
	var max_distance_sq = max_distance * max_distance
	
	# Iterate through potential cells in a more optimized way
	for x in range(-search_radius_cells, search_radius_cells + 1):
		for z in range(-search_radius_cells, search_radius_cells + 1):
			for y in range(-search_radius_cells, search_radius_cells + 1):
				# Calculate test coordinates
				var test_coords = Vector3i(
					origin_coords.x + x,
					origin_coords.y + y,
					origin_coords.z + z
				)
				
				# Get candidate cell
				var candidate_cell: GridCell = get_grid_cell(test_coords)
				
				# Skip if no cell exists or it's the origin cell
				if candidate_cell == null or candidate_cell == origin_cell:
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
				
				# Optional debug visualization (consider making this conditional)
#				DebugDraw3D.draw_box(
#					candidate_position, 
#					Quaternion.IDENTITY,
#					Vector3(cell_size.x, cell_size.y, cell_size.x), 
#					Color.MAGENTA, 
#					true, 
#					5
#				)

	# Update success flag based on whether we found any cells
	result["success"] = not result["cells"].is_empty()
	
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


func is_gridcell_walkable(cell: GridCell) -> bool:
	return cell.grid_cell_state & Enums.cellState.WALKABLE


func  try_get_random_walkable_cell() -> Dictionary:
	var cell = UtilityMethods.get_random_value_with_condition(grid_cells.values(),is_gridcell_walkable)
	
	if cell == null:
		return {"success": false, "cell": null}
	else:
		return {"success": true, "cell": cell}
	
	#var randomIndex = randi_range(0, filteredArray.size())
	
	#return filteredArray[randomIndex]


func get_distance_between_grid_cells(from_grid_cell : GridCell, to_grid_cell : GridCell) -> float:
	return from_grid_cell.world_position.distance_to(to_grid_cell.world_position)
	
#endregion
