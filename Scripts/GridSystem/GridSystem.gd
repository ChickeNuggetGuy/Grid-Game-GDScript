@tool
extends Manager
class_name GridSystem
#region Variables
var grid_cells: Dictionary[Vector3i,GridCell]
var collected_grid_objects: Array[GridObject] = [] 



@export var connect_vertical: bool = true
@export var connect_diagonals: bool = true
@export var prevent_corner_cutting: bool = true
@export var max_step_height_ratio: float = 0.6

@export var connection_use_raycast: bool = false
@export var connection_raycast_height_offset: float = 0.35
@export var connection_collision_mask: int = PhysicsLayer.OBSTACLE

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
	collected_grid_objects.clear()
	await _wait_for_physics_ready()
	await setup_grid()
	await setup_collected_grid_objects()

	grid_cell_overrides.clear()
	for override in get_tree().get_nodes_in_group("grid_cell_overrides"):
		if override is GridCellStateOverride:
			grid_cell_overrides.append(override)
			if not override.is_connected(
				"overrides_applied",
				Callable(self, "_on_overrides_applied")
			):
				override.connect(
					"overrides_applied",
					Callable(self, "_on_overrides_applied")
				)
			# Apply initial overrides before building connections
			override.set_cell_overrides()

	setup_grid_connections()

	execution_completed.emit()



func _on_overrides_applied(changed_coords: Array[Vector3i]) -> void:
	rebuild_connections_for_cells(changed_coords)

func _wait_for_physics_ready(frames: int = 2) -> void:
	# Give the scene one process frame and a couple physics steps
	await get_tree().process_frame
	for i in range(frames):
		await get_tree().physics_frame



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


func generate_connections_for_cell(
	cell: GridCell,
	space_state: PhysicsDirectSpaceState3D
) -> int:
	var neighbor_offsets := _generate_halfspace_offsets()
	var edges := 0
	
	if cell == null:
		return 0
	
	# Allow connection generation for occupied cells (units need to move out)
	# but not for AIR cells
	if bool(cell.grid_cell_state & Enums.cellState.AIR):
		return 0

	for off in neighbor_offsets:
		var b_coords = cell.grid_coordinates + off
		if not grid_cells.has(b_coords):
			continue

		var b: GridCell = grid_cells[b_coords]
		if b == null:
			continue
			
		# Can connect TO walkable cells from occupied cells
		if not _is_cell_walkable(b):
			continue

		if _can_connect_cells(cell, b, off, space_state):
			_add_connection_bidirectional(cell, b)
			edges += 1

	return edges


func setup_grid_connections():
	for c in grid_cells.values():
		if c != null:
			c.grid_cell_connections.clear()

	var space_state := get_tree().root.world_3d.direct_space_state

	var edges_built := 0

	for cell in grid_cells.values():
		if cell == null:
			continue
		edges_built += generate_connections_for_cell(cell, space_state)

	print("Grid connections complete: ", edges_built, " edges")

func _generate_halfspace_offsets() -> Array[Vector3i]:
	var arr: Array[Vector3i] = []
	for dx in range(-1,2):
		for dy in range(-1,2):
			for dz in range(-1,2):
				if dx == 0 and dy == 0 and dz == 0:
					continue
				if dx < 0:
					continue
				if dx == 0 and dy < 0:
					continue
				if dx == 0 and dy == 0 and dz < 0:
					continue
				if not connect_vertical and dy != 0:
					continue
				var k = _count_non_zero(Vector3i(dx, dy, dz))
				if not connect_diagonals and k > 1:
					continue
				arr.append(Vector3i(dx, dy, dz))
	return arr



func _count_non_zero(off: Vector3i) -> int:
	var k := 0
	if off.x != 0:
		k += 1
	if off.y != 0:
		k += 1
	if off.z != 0:
		k += 1
	return k




func _all_neighbor_offsets() -> Array[Vector3i]:
	var arr: Array[Vector3i] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				if dx == 0 and dy == 0 and dz == 0:
					continue
				if not connect_vertical and dy != 0:
					continue
				var k = _count_non_zero(Vector3i(dx, dy, dz))
				if not connect_diagonals and k > 1:
					continue
				arr.append(Vector3i(dx, dy, dz))
	return arr

func rebuild_connections_for_cells(coords_list: Array[Vector3i]) -> void:
	if coords_list.is_empty():
		return

	var space_state := get_tree().root.world_3d.direct_space_state
	var scope := {}

	var neighbor_offsets := _all_neighbor_offsets()
	for c in coords_list:
		if not grid_cells.has(c):
			continue
		scope[c] = true
		for off in neighbor_offsets:
			var nc := c + off
			if grid_cells.has(nc):
				scope[nc] = true

	for coords in scope.keys():
		var cell: GridCell = grid_cells.get(coords, null)
		if cell == null:
			continue
		for n in cell.grid_cell_connections.duplicate():
			n.grid_cell_connections.erase(cell)
		cell.grid_cell_connections.clear()

	for coords in scope.keys():
		var cell: GridCell = grid_cells.get(coords, null)
		if cell != null:
			generate_connections_for_cell(cell, space_state)


func setup_collected_grid_objects():
	print("Setting up ", collected_grid_objects.size(), " collected grid objects")
	
	for grid_object in collected_grid_objects:
		if grid_object == null or not is_instance_valid(grid_object):
			continue
			
		# Get the grid object's world position
		var world_pos = grid_object.grid_position_data.global_position
		
		## Try to get the corresponding grid cell
		var result = try_get_gridCell_from_world_position(world_pos, true)
		if result["success"]:
			var grid_cell: GridCell = result["grid_cell"]
			

			var direction = Enums.facingDirection.NORTH 
			var team = Enums.unitTeam.ANY 
			grid_object._setup(grid_cell, direction,team)

func is_position_obstructed(spaceState: PhysicsDirectSpaceState3D, position: Vector3) -> bool:
	var cell_size = GameManager.managers["MeshTerrainManager"].cell_size
	
	var box := BoxShape3D.new()
	var probe_size := colliderSize
	if probe_size == Vector3.ZERO:
		probe_size = Vector3(cell_size.x * 0.9, cell_size.y * 0.9, cell_size.x * 0.9)
	box.size = probe_size
	
	var test_points := [
		position + collideroffset,
		position + collideroffset + Vector3(cell_size.x * 0.25, 0, cell_size.x * 0.25),
		position + collideroffset + Vector3(-cell_size.x * 0.25, 0, cell_size.x * 0.25),
		position + collideroffset + Vector3(cell_size.x * 0.25, 0, -cell_size.x * 0.25),
		position + collideroffset + Vector3(-cell_size.x * 0.25, 0, -cell_size.x * 0.25),
	]
	
	var qp := PhysicsShapeQueryParameters3D.new()
	qp.shape = box
	qp.collide_with_bodies = true
	qp.collide_with_areas = false
	qp.collision_mask = ~PhysicsLayer.OBSTACLE
	
	for test_point in test_points:
		qp.transform = Transform3D(Basis.IDENTITY, test_point)
		var hits := spaceState.intersect_shape(qp)
		
		if hits.size() > 0:
			for hit in hits:
				var collider = hit.get("collider")
				if collider != null:
					var grid_object := find_grid_object_in_hierarchy(collider)
					if grid_object != null and not collected_grid_objects.has(grid_object):
						collected_grid_objects.append(grid_object)
			
			
			if hits.size() > 1:
				DebugDraw3D.draw_box(position, Quaternion.IDENTITY, box.size, Color.RED, true, 10)
				return true
	
	return false



func find_grid_object_in_hierarchy(node: Node) -> GridObject:
	var current = node
	
	while current != null:
		if current is GridObject:
			return current as GridObject
		current = current.get_parent()
	
	return null

func determine_cell_state(spaceState: PhysicsDirectSpaceState3D, position: Vector3, layer: int) -> Dictionary:
	var return_value : Dictionary = {"cell_state": Enums.cellState.NONE, "position": position}
	
	if colliderCheck and is_position_obstructed(spaceState, position):
		return_value["cell_state"] = Enums.cellState.OBSTRUCTED
		return return_value
	
	if raycastCheck:
		return perform_enhanced_raycast_check(spaceState, position, layer)
	
	return return_value

func perform_enhanced_raycast_check(spaceState: PhysicsDirectSpaceState3D, position: Vector3, layer: int) -> Dictionary:
	var cell_size = GameManager.managers["MeshTerrainManager"].cell_size
	
	var return_value = {"cell_state":Enums.cellState.NONE, "position" : position}
	
	var ray_offsets = [
		Vector3(0, 0, 0), 
		Vector3(cell_size.x * 0.25, 0, cell_size.x * 0.25),  
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


	var walkable_ratio = float(walkable_hits) / float(total_rays)
	
	if walkable_ratio >= 0.6: 
		position.y = adjusted_position.y  
		return_value["position"] = position
		
		return_value["cell_state"] = Enums.cellState.GROUND | Enums.cellState.WALKABLE
		return return_value
	elif walkable_ratio > 0:
		position.y = adjusted_position.y  
		return_value["position"] = position
		# Just GROUND, not walkable enough
		return_value["cell_state"] = Enums.cellState.GROUND
		return return_value
	else:
		return_value["cell_state"] = Enums.cellState.AIR
		return return_value

func visualize_cell(grid_coordinates: Vector3i):
	var cell: GridCell = grid_cells.get(grid_coordinates, null)
	if not cell:
		return

	var cell_size = GameManager.managers["MeshTerrainManager"].cell_size
	var color = Color.WHITE
	var state_flags: Array[String] = []
	
	
	if bool(cell.grid_cell_state & Enums.cellState.AIR):
		state_flags.append("AIR")
	if bool(cell.grid_cell_state & Enums.cellState.GROUND):
		state_flags.append("GROUND")
	if bool(cell.grid_cell_state & Enums.cellState.WALKABLE):
		state_flags.append("WALKABLE")
	if bool(cell.grid_cell_state & Enums.cellState.OBSTRUCTED):
		state_flags.append("OBSTRUCTED")
		
		
	if state_flags.has("OBSTRUCTED"):
		color = Color.RED
	elif state_flags.has("WALKABLE") and state_flags.has("GROUND"):
		color = Color.LIME_GREEN
	elif state_flags.has("WALKABLE"):
		color = Color.GREEN
	elif state_flags.has("GROUND"):
		color = Color.YELLOW
	elif state_flags.has("AIR"):
		color = Color.CYAN
	else:
		color = Color.GRAY


	if not bool(cell.grid_cell_state & Enums.cellState.AIR):
		DebugDraw3D.draw_box(
			cell.world_position,
			Quaternion.IDENTITY,
			Vector3(cell_size.x, cell_size.y, cell_size.x),
			color,
			true,
			20
		)

	for connected_cell in cell.grid_cell_connections:
		if connected_cell != null:
			DebugDraw3D.draw_line(
				cell.world_position,
				connected_cell.world_position,
				Color.BLUE,
				20
			)

func create_or_update_cell(coords: Vector3i, position: Vector3, cell_state: Enums.cellState):
	if not grid_cells.has(coords) || grid_cells[coords] == null:
		var result = InventoryManager.try_get_inventory_grid(Enums.inventoryType.GROUND)
		var ground_inventory_grid = result["inventory_grid"]
		var cell = GridCell.new(coords.x, coords.y, coords.z, position, cell_state, Enums.FogState.UNSEEN, ground_inventory_grid)
		grid_cells[coords] = cell
	else:
		grid_cells[coords].grid_cell_state = cell_state
		grid_cells[coords].world_position = position



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


		if hitY >= cell_bottom_y and hitY < cell_top_y:
			
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
	
	var target_key = Vector3i(x_coord, y_coord, z_coord)
	
	if grid_cells.has(target_key):
		retVal["grid_cell"] = grid_cells[target_key]
		retVal["success"] = true
		return retVal
	elif not nullGetNearest:
		retVal["success"] = false
		return retVal
	
	var minDistanceSq := INF
	var nearest_cell: GridCell = null
	
	for key_coords in grid_cells.keys():
		if key_coords.y == y_coord:
			var candidate_cell: GridCell = grid_cells[key_coords]
			var dist_sq: float = (
				candidate_cell.world_position - worldPosition
			).length_squared()
			if dist_sq < minDistanceSq:
				minDistanceSq = dist_sq
				nearest_cell = candidate_cell
	
	if nearest_cell != null:
		retVal["grid_cell"] = nearest_cell
		retVal["success"] = true
		return retVal
	
	retVal["grid_cell"] = null
	retVal["success"] = false
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

func try_get_grid_cell_of_state_below(
	grid_coords: Vector3i,
	wanted_cell_state: Enums.cellState
) -> Dictionary:
	var ret_val := {"success": false, "grid_cell": null}
	var starting_grid_cell: GridCell = get_grid_cell(grid_coords)

	if starting_grid_cell == null:
		return ret_val

	for y_level in range(starting_grid_cell.grid_coordinates.y - 1, -1, -1):
		var temp_grid_cell: GridCell = get_grid_cell(
			Vector3i(
				starting_grid_cell.grid_coordinates.x,
				y_level,
				starting_grid_cell.grid_coordinates.z
			)
		)
		if temp_grid_cell == null:
			continue

		if temp_grid_cell.grid_cell_state & wanted_cell_state:
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
	
	var temp_grid_cells : Dictionary[Vector3i, GridCell] = {}
	var result: Dictionary = {
		"success": false,
		"cells": temp_grid_cells
	}
	
	
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
	
	
	var max_distance_sq = max_distance * max_distance
	
	
	for x in range(-search_radius_cells, search_radius_cells + 1):
		for z in range(-search_radius_cells, search_radius_cells + 1):
			for y in range(-search_radius_cells, search_radius_cells + 1):
				var test_coords = Vector3i(
					origin_coords.x + x,
					origin_coords.y + y,
					origin_coords.z + z
				)
				
				var candidate_cell: GridCell = get_grid_cell(test_coords)
				
				if candidate_cell == null:
					continue
				
				var candidate_position = candidate_cell.world_position
				
				
				var to_candidate = candidate_position - origin_position
				
				
				var distance_sq = to_candidate.length_squared()
				if distance_sq > max_distance_sq:
					continue
				
				var to_candidate_normalized = to_candidate.normalized()
				var dot_product = normalized_forward.dot(to_candidate_normalized)
				
				
				if dot_product < cos_half_fov:
					continue
				
				
				if cell_state_filter != Enums.cellState.NONE:
					if not (candidate_cell.grid_cell_state & cell_state_filter):
						continue
				
				
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


func get_max_height() -> int:
	var max_height := 0
	for key in grid_cells.keys():
		var layer := int(key.y)
		max_height = max(max_height, layer)
	return max_height

func get_min_height() -> int:
	var min_height := 0
	for key in grid_cells.keys():
		var layer := int(key.y)
		min_height = min(min_height, layer)
	return min_height


func get_grid_cell_neighbors(target_grid_cell: GridCell, cell_state_filter: Enums.cellState = Enums.cellState.NONE) -> Array[GridCell]:
	var ret_val: Array[GridCell] = []
	
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				if x == 0 and y == 0 and z == 0:
					continue
				
				var test_coords = Vector3i(
					target_grid_cell.grid_coordinates.x + x,
					target_grid_cell.grid_coordinates.y + y,
					target_grid_cell.grid_coordinates.z + z
				)
				
				if not grid_cells.has(test_coords):
					continue
				
				if (cell_state_filter != Enums.cellState.NONE and not bool(grid_cells[test_coords].grid_cell_state & cell_state_filter)):
					continue
					
				ret_val.append(grid_cells[test_coords])
	
	return ret_val


func try_get_randomGrid_cell() -> Dictionary:
	
	var cell = grid_cells.values().pick_random()
	
	
	return {"success": true,"cell":cell}


func try_get_neighbors_in_radius(
	starting_grid_cell: GridCell,
	radius: float,
	grid_cell_state_filter: Enums.cellState = Enums.cellState.NONE
) -> Dictionary:
	var grid_cells : Array[GridCell] = []
	var result: Dictionary = {
		"success": false,
		"grid_cells": grid_cells  
	}
	
	if starting_grid_cell == null:
		push_warning("try_get_neighbors_in_radius: Starting cell is NULL.")
		return result
	
	var cell_size = GameManager.managers["MeshTerrainManager"].cell_size
	if cell_size == Vector2.ZERO:
		push_error("Cell size invalid.")
		return result

	# Convert world radius to number of grid cells (using horizontal X/Z only or sqrt(3) diagonal safety)
	var search_range := int(ceil(radius / min(cell_size.x, cell_size.x))) + 1
	var radius_squared := radius * radius
	var origin_position := starting_grid_cell.world_position

	for dx in range(-search_range, search_range + 1):
		for dy in range(-search_range, search_range + 1):
			for dz in range(-search_range, search_range + 1):
				var test_coords := starting_grid_cell.grid_coordinates + Vector3i(dx, dy, dz)
				var test_cell = get_grid_cell(test_coords)

				if not test_cell:
					continue

				if grid_cell_state_filter != Enums.cellState.NONE:
					if not (test_cell.grid_cell_state & grid_cell_state_filter):
						continue

				var dist_sq = test_cell.world_position.distance_squared_to(origin_position)
				if dist_sq <= radius_squared:
					result["grid_cells"].append(test_cell)

	result["success"] = not result["grid_cells"].is_empty()
	return result



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


func _is_cell_walkable(cell: GridCell) -> bool:
	if cell == null:
		return false
	
	# Not walkable if obstructed
	if bool(cell.grid_cell_state & Enums.cellState.OBSTRUCTED):
		return false
	
	# Not walkable if it's just air
	if bool(cell.grid_cell_state & Enums.cellState.AIR) and not bool(cell.grid_cell_state & Enums.cellState.GROUND):
		return false
		
	# Walkable if it has WALKABLE flag OR if it's GROUND without OBSTRUCTED
	return bool(cell.grid_cell_state & Enums.cellState.WALKABLE) or \
		   (bool(cell.grid_cell_state & Enums.cellState.GROUND) and not bool(cell.grid_cell_state & Enums.cellState.OBSTRUCTED))


func _add_connection_bidirectional(a: GridCell, b: GridCell) -> void:
	# Avoid duplicates
	if not a.grid_cell_connections.has(b):
		a.grid_cell_connections.append(b)
	if not b.grid_cell_connections.has(a):
		b.grid_cell_connections.append(a)


func _can_connect_cells(
	a: GridCell,
	b: GridCell,
	off: Vector3i,
	space_state: PhysicsDirectSpaceState3D
) -> bool:
	var cell_size = GameManager.managers["MeshTerrainManager"].cell_size
	var step_limit = cell_size.y * max_step_height_ratio
	if absf(a.world_position.y - b.world_position.y) > step_limit:
		return false

	var k := _count_non_zero(off)
	if k > 1 and prevent_corner_cutting:
		for unit_off in _axis_unit_offsets(off):
			var mid_coords := a.grid_coordinates + unit_off
			var mid = get_grid_cell(mid_coords)
			if not _is_cell_walkable(mid):
				return false

	if connection_use_raycast and \
		not _has_clear_connection_line(a.world_position, b.world_position, space_state):
		return false

	return true


func _axis_unit_offsets(off: Vector3i) -> Array[Vector3i]:
	var arr: Array[Vector3i] = []
	if off.x != 0:
		arr.append(Vector3i(sign(off.x), 0, 0))
	if off.y != 0:
		arr.append(Vector3i(0, sign(off.y), 0))
	if off.z != 0:
		arr.append(Vector3i(0, 0, sign(off.z)))
	return arr

func _has_clear_connection_line(
	a_pos: Vector3,
	b_pos: Vector3,
	space_state: PhysicsDirectSpaceState3D
) -> bool:
	var start := a_pos + Vector3(0, connection_raycast_height_offset, 0)
	var end := b_pos + Vector3(0, connection_raycast_height_offset, 0)

	var rq := PhysicsRayQueryParameters3D.new()
	rq.from = start
	rq.to = end
	rq.collide_with_bodies = true
	rq.collide_with_areas = false
	rq.hit_from_inside = true
	rq.collision_mask = connection_collision_mask

	var hit := space_state.intersect_ray(rq)
	return not hit
#endregion
