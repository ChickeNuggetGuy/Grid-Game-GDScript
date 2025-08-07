extends BaseItemActionDefinition
class_name RangedAttackActionDefinition

@export var attack_count : int

func _init() -> void:
	action_name = "Ranged Attack"
	script_path = "res://Scripts/InventorySystem/ItemActions/RangedAttackAction.gd"
	super._init()
	
func get_valid_grid_cells(starting_grid_cell : GridCell) -> Array[GridCell]:
	var walkable_empty_filter = Enums.cellState.NONE
	var result = GridSystem.try_get_neighbors_in_radius(starting_grid_cell, Vector2i(8,5), walkable_empty_filter)
	
	if result["success"] == false:
		push_error(" no grid cells found that satisfy the current filter")
	
	return result["grid_cell_array"]


func _get_AI_action_scores(starting_grid_cell : GridCell) -> Dictionary[GridCell, float]:
	var ret_value = {}
	
	var grid_system : GridSystem = GridSystem
	for grid_cell in get_valid_grid_cells(starting_grid_cell):
		var distance_between_cells  = grid_system.get_distance_between_grid_cells(starting_grid_cell,grid_cell)
		var normalized_distance : float = clamp(distance_between_cells / 100, 0.0, 1.0)
		ret_value[grid_cell] = normalized_distance
	
	return ret_value


func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_value = {"success" : false, "cost" : 0}
	var temp_cost = 12
	
	var result = RotationHelperFunctions.get_rotation_info(parameters["unit"].grid_position_data.direction,
		parameters["unit"].grid_position_data.grid_cell, parameters["target_grid_cell"])
		
	if result["needs_rotation"] == true:
		temp_cost +=  1 * result["rotation_steps"]
	
	var world = parameters["unit"].get_tree().current_scene.get_world_3d()
	var space_state = world.direct_space_state
	
	var rayStart = parameters["start_grid_cell"].world_position + Vector3(0, 1, 0)
	var rayEnd = parameters["target_grid_cell"].world_position + Vector3(0, 1, 0)
	var rq = PhysicsRayQueryParameters3D.new()
	rq.from = rayStart
	rq.to = rayEnd
	rq.collide_with_bodies = true
	rq.collide_with_areas = true
	rq.hit_from_inside = false
	rq.collision_mask = PhysicsLayer.TERRAIN
	var r = space_state.intersect_ray(rq)
	
	if r:
		return ret_value
	else:
		ret_value["success"] = true
		ret_value["cost"] = temp_cost
		return ret_value
