@tool

extends Manager

#region Varibles
var grid_cells: Dictionary[Vector3i,GridCell]
@export var gridSize: Vector3i = Vector3i(20,15,20)
@export var gridCellSize: Vector2 = Vector2(1,0.5)

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

#func _ready():
	#setup_grid()
	
func _process(_delta: float) -> void:
	# Calculate the world-space center of the grid
	var grid_world_center = Vector3(
		gridSize.x * gridCellSize.x * 0.5,
		gridSize.y * gridCellSize.y * 0.5,
		gridSize.z * gridCellSize.x * 0.5 # Assuming Z uses X's cell size
	)
	# Calculate the total world-space size of the grid
	var grid_world_size = Vector3(
		gridSize.x * gridCellSize.x,
		gridSize.y * gridCellSize.y,
		gridSize.z * gridCellSize.x
	)
	DebugDraw3D.draw_box(grid_world_center, Quaternion.IDENTITY, grid_world_size, Color.AQUAMARINE, true)
	#
	#if(dome == false):
		#setup_grid()


func setup_grid():
	grid_cells = {}
	var spaceState = get_tree().root.world_3d.direct_space_state

	for layer in range(gridSize.y):
		for x in range(gridSize.x):
			for z in range(gridSize.z):
				var cell_state: Enums.cellState = Enums.cellState.NONE
				var position = Vector3(
					x * gridCellSize.x + (gridCellSize.x * 0.5),
					layer * gridCellSize.y + (gridCellSize.y * 0.5),
					z * gridCellSize.x + (gridCellSize.x * 0.5)
				)

				# Collider check
				if colliderCheck:
					var box = BoxShape3D.new()
					box.size = colliderSize
					var qp = PhysicsShapeQueryParameters3D.new()
					qp.shape = box
					qp.transform = Transform3D(Basis.IDENTITY, position + collideroffset)
					qp.collide_with_bodies = true
					qp.collide_with_areas = true
					qp.collision_mask = PhysicsLayer.TERRAIN
					var hits = spaceState.intersect_shape(qp)

					if hits.size() > 0:
						@warning_ignore("int_as_enum_without_cast")
						cell_state |= (Enums.cellState.OBSTRUCTED) as Enums.cellState
					else:
						if raycastCheck:
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
								var cell_bottom_y = float(layer) * gridCellSize.y
								var cell_top_y = float(layer + 1) * gridCellSize.y

								if hitY >= cell_bottom_y and hitY <= cell_top_y:
									position.y = hitY
									cell_state |= Enums.UnitStance.get(Enums.cellState.WALKABLE)
								else:
									cell_state |= Enums.UnitStance.get(Enums.cellState.AIR)
							else:
								cell_state |= Enums.UnitStance.get(Enums.cellState.AIR)
						else:
							print("Cell %d,%d,%d: Raycast disabled." % [x, z, layer])
				else:
					if raycastCheck:
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
							var cell_bottom_y = float(layer) * gridCellSize.y
							var cell_top_y = float(layer + 1) * gridCellSize.y

							if hitY >= cell_bottom_y and hitY <= cell_top_y:
								position.y = hitY
								@warning_ignore("int_as_enum_without_cast")
								cell_state |= (Enums.cellState.WALKABLE) 
							else:
								@warning_ignore("int_as_enum_without_cast")
								cell_state |= Enums.cellState.AIR
						else:
							@warning_ignore("int_as_enum_without_cast")
							cell_state |= Enums.cellState.AIR
					else:
						print("Cell %d,%d,%d: Neither collider nor raycast check enabled." % [x, z, layer])

				# Debug visualization
				if cell_state & Enums.cellState.WALKABLE:
					DebugDraw3D.draw_box(position, Quaternion.IDENTITY, Vector3(gridCellSize.x, gridCellSize.y, gridCellSize.x), Color.LIME_GREEN, true, 500)
				elif  cell_state & Enums.cellState.GROUND:
					DebugDraw3D.draw_box(position, Quaternion.IDENTITY, Vector3(gridCellSize.x, gridCellSize.y, gridCellSize.x), Color.RED, true, 500)

				# Update or create grid cell
				var coords = Vector3i(x, layer, z)
				if not grid_cells.has(coords) || grid_cells[coords] == null:
					var result = InventoryManager.try_get_inventory_grid(Enums.inventoryType.GROUND)
					var ground_inventory_grid = result["inventory_grid"]
					var cell = GridCell.new(x, layer, z, position, cell_state, ground_inventory_grid, self)
					grid_cells[coords] = cell
				else:
					grid_cells[coords].grid_cell_state = cell_state
					grid_cells[coords].worldPosition = position

	print(grid_cells.size())



func set_cell(x: int, z: int, y: int, value: GridCell) -> void:
	
	var key = Vector3i(x,y,z)
	if(value.gridCoordinates == null || value.gridCoordinates != key):
		value.gridCoordinates = key
		
	grid_cells[key] = value


func get_grid_cell(grid_coords : Vector3i,  default_value = null):
	return grid_cells.get(grid_coords, default_value)


func has_cell(x: int, z: int, y: int) -> bool:
	return grid_cells.has(Vector3i(x,y,z))


func remove_cell(x: int, z: int, y: int) -> void:
	grid_cells.erase(Vector3(x, y, z))


func try_get_gridCell_from_world_position(worldPosition: Vector3, nullGetNearest: bool = false) -> Dictionary:
	var retVal: Dictionary = {"success": false, "grid_cell": null}

	if (gridCellSize.x <= 0 or gridCellSize.y <= 0): 
		print("BAD")
		return retVal 

	var x_coord = int(floor(worldPosition.x / gridCellSize.x))
	var y_coord = int(floor(worldPosition.y / gridCellSize.y))
	var z_coord = int(floor(worldPosition.z / gridCellSize.x))

	
	x_coord = clamp(x_coord, 0, gridSize.x - 1)
	y_coord = clamp(y_coord, 0, gridSize.y - 1)
	z_coord = clamp(z_coord, 0, gridSize.z - 1) 
	
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


func try_get_grid_cell_of_state_below(grid_coords: Vector3, wanted_cell_state: Enums.cellState) -> Dictionary:
	var ret_val = {"success": false, "grid_cell": null}
	var starting_grid_cell: GridCell = get_grid_cell(grid_coords)
	
	if starting_grid_cell == null:
		return ret_val
	
	# Search downward from the cell below the starting position
	for y_level in range(starting_grid_cell.gridCoordinates.y - 1, -1, -1):
		var temp_grid_cell: GridCell = get_grid_cell(Vector3(
			starting_grid_cell.gridCoordinates.x,
			y_level,
			starting_grid_cell.gridCoordinates.z
		))
		
		if temp_grid_cell == null:
			continue
		
		elif temp_grid_cell.grid_cell_state & wanted_cell_state:
			ret_val["success"] = true
			ret_val["grid_cell"] = temp_grid_cell
			return ret_val
	
	return ret_val


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


func get_grid_cell_neighbors(target_grid_cell: GridCell) -> Array[GridCell]:
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
					target_grid_cell.gridCoordinates.x + x,
					target_grid_cell.gridCoordinates.y + y,
					target_grid_cell.gridCoordinates.z + z
				)
				
				# Check if the neighbor exists in the grid
				if grid_cells.has(test_coords):
					ret_val.append(grid_cells[test_coords])
	
	return ret_val


func try_get_randomGrid_cell() -> Dictionary:
	
	var cell = grid_cells.values().pick_random()
	
	
	return {"success": true,"cell":cell}


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


#endregion
