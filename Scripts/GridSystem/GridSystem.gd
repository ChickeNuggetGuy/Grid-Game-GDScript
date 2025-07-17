@tool

extends Manager

#region Varibles
var gridCells: Dictionary[GridCoords,GridCell]
@export var gridSize: Vector3i = Vector3i(20,5,20)
@export var gridCellSize: Vector2 = Vector2(1,0.5)

#region Grid Validation Settings
@export var raycastCheck : bool = true
@export var raycastOffset: Vector3  = Vector3(0,5,0)
@export var  raycastLength : float = 10

@export var  colliderCheck : bool
@export var  colliderSize : Vector3
@export var  collideroffset : Vector3
@export var  colliderLength : float
var dome: bool = false
#@export var groundInventoryPrefab: InventoryGrid;
#endregion
#endregion

#region
func _get_manager_name() -> String: return "GridSystem"

func _setup_conditions(): return

func _setup(): 
	print("HELP")
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
	print("HMMMM")
	gridCells = {}
	var spaceState = get_tree().root.world_3d.direct_space_state
	for layer in range(gridSize.y):
		for x in range(gridSize.x):
			for z in range(gridSize.z):
				var walkable = false
				var position = Vector3(
					x * gridCellSize.x + (gridCellSize.x * 0.5),
					layer * gridCellSize.y + (gridCellSize.y * 0.5),
					z * gridCellSize.x + (gridCellSize.x * 0.5)
				)

				#DebugDraw3D.draw_box(position, Quaternion.IDENTITY, Vector3(gridCellSize.x, gridCellSize.y*2, gridCellSize.x), Color.RED, true, 500)

				# Define the collision mask for both queries (only for layer 2)
				var collision_mask_for_terrain = 1 << 1 # (1 << (LayerNumber - 1)) for layer 2

				# 1) Collider check
				if colliderCheck:
					var box = BoxShape3D.new()
					box.size = colliderSize
					var qp = PhysicsShapeQueryParameters3D.new()
					qp.shape = box
					qp.transform = Transform3D(Basis.IDENTITY, position + collideroffset)
					qp.collide_with_bodies = true
					qp.collide_with_areas = true
					qp.collision_mask = collision_mask_for_terrain # <-- ADD THIS LINE
					var hits = spaceState.intersect_shape(qp)

					var collider_color = Color.BLUE if hits.size() > 0 else Color.GREEN
					DebugDraw3D.draw_box(qp.transform.origin, Quaternion.IDENTITY, box.size, collider_color, true, 500)

					if hits.size() > 0:
						#print("Cell %d,%d,%d: BLOCKED by collider. Hits: %s" % [x, z, layer, hits])
						walkable = false
					else:
						if raycastCheck:
							var rayStart = position + raycastOffset
							var rayEnd   = position + raycastOffset - Vector3(0, raycastLength, 0)
							DebugDraw3D.draw_line(rayStart, rayEnd, Color.YELLOW, 500)

							var rq = PhysicsRayQueryParameters3D.new()
							rq.from = rayStart
							rq.to = rayEnd
							rq.collide_with_bodies = true
							rq.collide_with_areas = true
							rq.hit_from_inside = true
							rq.collision_mask = collision_mask_for_terrain # <-- ADD THIS LINE
							var r = spaceState.intersect_ray(rq)

							if r:
								var hitY = r.position.y
								var cell_bottom_y = float(layer) * gridCellSize.y
								var cell_top_y = float(layer + 1) * gridCellSize.y

								DebugDraw3D.draw_sphere(r.position, 0.1, Color.CYAN, 500)

								if hitY >= cell_bottom_y and hitY <= cell_top_y:
									position.y = hitY
									walkable = true
						else:
							print("Cell %d,%d,%d: Raycast disabled, and collider passed. Cell remains unwalkable by default." % [x, z, layer])

				else: # No collider check, only raycast (if enabled)
					if raycastCheck:
						var rayStart = position + raycastOffset
						var rayEnd = position + raycastOffset - Vector3(0, raycastLength, 0)
						DebugDraw3D.draw_line(rayStart, rayEnd, Color.MAGENTA, 500)

						var rq = PhysicsRayQueryParameters3D.new()
						rq.from = rayStart
						rq.to = rayEnd
						rq.collide_with_bodies = true
						rq.collide_with_areas= true
						rq.hit_from_inside = true
						rq.collision_mask = PhysicsLayersUtility.TERRAIN
						var r = spaceState.intersect_ray(rq)

						if r:
							var hitY = r.position.y
							var cell_bottom_y = float(layer) * gridCellSize.y
							var cell_top_y = float(layer + 1) * gridCellSize.y

							DebugDraw3D.draw_sphere(r.position, 0.1, Color.CYAN, 500)

							if hitY >= cell_bottom_y and hitY <= cell_top_y:
								position.y = hitY
								walkable = true
					else:
						print("Cell %d,%d,%d: Neither collider nor raycast check enabled. Cell remains unwalkable." % [x, z, layer])

				if walkable:
					DebugDraw3D.draw_box(position, Quaternion.IDENTITY, Vector3(gridCellSize.x, gridCellSize.y, gridCellSize.x), Color.LIME_GREEN, true, 500)
				else:
					DebugDraw3D.draw_box(position, Quaternion.IDENTITY, Vector3(gridCellSize.x, gridCellSize.y, gridCellSize.x), Color.RED, true)

				var coords = GridCoords.new(x, z, layer)
				if not gridCells.has(coords) || gridCells[coords] == null:
					var cell = GridCell.new(x,z,layer, position, walkable, null, self)
					gridCells[coords] = cell
				else:
					gridCells[coords].walkable = walkable
					gridCells[coords].worldPosition = position
				
				if gridCells[coords].walkable:
					print("Wallkable")
				else:
					print("UNWallkable")
					
	await get_tree().create_timer(0.1).timeout
	print(gridCells.size())



func set_cell(x: int, z: int, y: int, value: GridCell) -> void:
	# pack coords into a key
	var key = GridCoords.new(x, z, y)
	if(value.gridCoordinates == null || value.gridCoordinates != key):
		value.gridCoordinates = key
		
	gridCells[key] = value




func get_cell(x: int, z: int, y: int, default_value = null):
	var key = Vector3(x, y, z)
	return gridCells.get(key, default_value)


func has_cell(x: int, z: int, y: int) -> bool:
	return gridCells.has(GridCoords.new(x,z,y))


func remove_cell(x: int, z: int, y: int) -> void:
	gridCells.erase(Vector3(x, y, z))


func try_get_gridCell_from_world_position(worldPosition: Vector3, nullGetNearest: bool = false) -> Dictionary:
	var retVal: Dictionary = {"Success": false, "GridCell": null}

	if (gridCellSize.x <= 0 or gridCellSize.y <= 0): return retVal # Check both dimensions

	var x_coord = int(floor(worldPosition.x / gridCellSize.x))
	var y_coord = int(floor(worldPosition.y / gridCellSize.y))
	var z_coord = int(floor(worldPosition.z / gridCellSize.x)) # Assuming Z uses X's cell size

	# Clamp coordinates to grid boundaries
	x_coord = clamp(x_coord, 0, gridSize.x - 1)
	y_coord = clamp(y_coord, 0, gridSize.y - 1)
	z_coord = clamp(z_coord, 0, gridSize.z - 1) # Assuming gridSize.z is for Z-dimension

	# Assuming GridCoords(x, z, y_layer)
	var target_key = GridCoords.new(x_coord, z_coord, y_coord) # Or Vector3i(x_coord, y_coord, z_coord) if you switch

	if gridCells.has(target_key):
		retVal["GridCell"] = gridCells[target_key]
		retVal["Success"] = true
		return retVal
	elif (!nullGetNearest):
		retVal["Success"] = false
		return retVal

	# If nullGetNearest is true, search for the nearest valid grid cell on the same LAYER
	# This part needs significant re-thinking if your grid is sparse and you're using a flat dictionary.
	# Iterating all values could be slow for large grids.
	# A spatial hash or a specialized lookup might be better for "nearest in world" queries.
	# For now, let's just consider cells on the same Y-layer.
	var minDistanceSq = INF
	var nearest_cell: GridCell = null

	for key_coords in gridCells.keys():
		if key_coords.layer == y_coord: # Check if on the same y-layer
			var candidate_cell: GridCell = gridCells[key_coords]
			var distSq: float = (candidate_cell.worldPosition - worldPosition).length_squared()
			if distSq < minDistanceSq:
				minDistanceSq = distSq
				nearest_cell = candidate_cell

	if nearest_cell != null:
		retVal["GridCell"] = nearest_cell
		retVal["Success"] = true
		return retVal

	retVal["GridCell"] = null
	retVal["Success"] = false
	return retVal

# Returns the highest integer y‐layer in `grid`. Assumes y ≥ 0.
func get_max_height() -> int:
	var max_height := 0
	for key in gridCells.keys():
		# if you’re using float‐y Vector3s, cast to int
		var layer := int(key.layer)
		max_height = max(max_height, layer)
	return max_height


func get_min_height() -> int:
	var min_height := 0
	for key in gridCells.keys():
		# if you’re using float‐y Vector3s, cast to int
		var layer := int(key.layer)
		min_height = min(min_height, layer)
	return min_height


func try_get_randomGrid_cell() -> Dictionary:
	
	var cell = gridCells.values().pick_random()
	
	
	return {"success": true,"cell":cell}
	


func is_gridcell_walkable(cell: GridCell) -> bool:
	return cell.walkable


func  try_get_random_walkable_cell() -> Dictionary:
	var cell = UtilityMethods.get_random_value_with_condition(gridCells.values(),is_gridcell_walkable)
	
	if cell == null:
		return {"success": false, "cell": null}
	else:
		return {"success": true, "cell": cell}
	
	#var randomIndex = randi_range(0, filteredArray.size())
	
	#return filteredArray[randomIndex]



#endregion
