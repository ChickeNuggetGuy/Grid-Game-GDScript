@tool
class_name GridSystem

extends Manager

#region Varibles
var gridCells: Dictionary[GridCoords,GridCell]
@export var gridSize: Vector3i
@export var gridCellSize: Vector2

#region Grid Validation Settings
@export var raycastCheck : bool
@export var raycastOffset: Vector3 
@export var  raycastLength : float

@export var  colliderCheck : bool
@export var  colliderSize : Vector3
@export var  collideroffset : Vector3
@export var  colliderLength : float
#@export var groundInventoryPrefab: InventoryGrid;
#endregion
#endregion

#region
func _get_manager_name() -> String: return "GridSystem"

func _setup_conditions(): return

func _setup(): return

func _execute_conditions() -> bool: return false

func _execute():
	setup_grid()

#func _ready():
	#setup_grid()
	
#func _process(_delta: float) -> void:
		#DebugDraw3D.draw_box(Vector3.ZERO, Quaternion.IDENTITY,Vector3(10,10,10),Color.AQUAMARINE, 10)

func setup_grid():
	# Ensure default grid size
	if gridSize == Vector3i.ZERO:
		gridSize.x = 10
		gridSize.y = 10
		gridSize.z = 10
	
	var spaceState = get_tree().root.world_3d.direct_space_state
	for layer in range(gridSize.y):
		for x in range(gridSize.x):
			for z in range(gridSize.z):
				var walkable = false
				var position = Vector3(x * gridCellSize.x + 0.5,
					layer * gridCellSize.y,
					z * gridCellSize.x + 0.5
				)
				var boxCenter = position + Vector3(0, colliderSize.y * 0.5, 0)
				# Added 'true' for persistent drawing and a duration of 500 seconds
				DebugDraw3D.draw_box(position,Quaternion.IDENTITY, Vector3(2,2,2),Color.RED, true, 500)

				# 1) Collider check
				if colliderCheck:
					var box = BoxShape3D.new()
					box.size = colliderSize
					var qp = PhysicsShapeQueryParameters3D.new()
					qp.shape = box
					qp.transform = Transform3D(Basis.IDENTITY, boxCenter)
					qp.collide_with_bodies = true
					qp.collide_with_areas = true
					var hits = spaceState.intersect_shape(qp)
					if hits.size() > 0:
						# blocked by collider → leave walkable = false
						pass
					else:
						# pass collider test → try raycast next
						if raycastCheck:
							var rayStart = boxCenter + Vector3(0, raycastLength * 0.5, 0)
							var rayEnd   = boxCenter - Vector3(0, raycastLength * 0.5, 0)
							# Added a duration of 500 seconds
							DebugDraw3D.draw_line(rayStart, rayEnd,Color.GREEN, 500)
							var rq = PhysicsRayQueryParameters3D.new()
							rq.from = rayStart
							rq.to = rayEnd
							rq.collide_with_bodies = true
							rq.collide_with_areas = true
							rq.hit_from_inside = true
							var r = spaceState.intersect_ray(rq)
							if r:
								var hitY = r.position.y
								var minY = layer * gridCellSize.y
								var maxY = minY + gridCellSize.y
								if hitY >= minY and hitY <= maxY:
									position.y = hitY
								walkable = true
				else:
					# no collider check → raycast only
					if raycastCheck:
						var rayStart = boxCenter + Vector3(0, colliderSize.y * 0.5, 0)
						var rayEnd = boxCenter - Vector3(0, colliderSize.y * 0.5, 0)
						var rq = PhysicsRayQueryParameters3D.new()
						rq.from = rayStart
						rq.to = rayEnd
						rq.collide_with_bodies = true
						rq.collide_with_areas= true
						rq.hit_from_inside = true
						var r = spaceState.intersect_ray(rq)
						# Added a duration of 10.0 seconds (consistent with your original value)
						DebugDraw3D.draw_line(rayStart, rayEnd,Color.ORANGE,10.0)
						if r:
							var hitY = r.position.y
							var minY = layer * gridCellSize.y
							var maxY = minY + gridCellSize.y
							if hitY >= minY and hitY <= maxY:
								position.y = hitY
								walkable = true

				# Cell creation
				var coords = GridCoords.new(x, z, layer)
				if not gridCells.has(coords) || gridCells[coords] == null:
					var cell = GridCell.new(x,z,layer, position, walkable, null, self)
					print(cell)
					gridCells[coords] = cell


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
	
	# Ensure cellSize is not zero to prevent division errors
	if (gridCellSize.x <= 0): return retVal
	
	# Convert world position to grid coordinates by dividing by cellSize and flooring the result
	var x = int(floor(worldPosition.x / gridCellSize.x))
	var y = int(floor(worldPosition.y / gridCellSize.y))
	var z = int(floor(worldPosition.z / gridCellSize.x))

	# Clamp Y first since gridCells.Count determines the valid range for Y
	y = clamp(y, 0, gridCells.keys().max().y	 - 1);
	if (y < 0 || y >= get_max_height()):
		retVal["Success"] = false
		retVal["GridCell"] = null
		return retVal

	# Attempt to retrieve the grid cell from the gridCells list
	retVal["GridCell"] = get_cell(x,z,y)
	if (retVal["GridCell"] != null):
		retVal["Success"] = true
		return retVal
	elif (!nullGetNearest):
		retVal["Success"] = false;
		return retVal

	# If nullGetNearest is true, search for the nearest valid grid cell on the same layer based on world position
	var minDistance = INF
	var nearest: GridCell = null;
	var rows = gridCells[y].GetLength(0)
	var cols = gridCells[y].GetLength(1)
	for i in rows:
		for j in cols:
			var candidate: GridCell = get_cell(i,j,y)
			if (candidate != null):
				#Compute the squared distance between the candidate's world position and the given worldPosition
				var distSq: float = (candidate.worldPosition - worldPosition).LengthSquared()
				if distSq < minDistance:
					minDistance = distSq
					nearest = candidate

	if nearest != null:
		retVal["GridCell"] = nearest
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

#endregion
