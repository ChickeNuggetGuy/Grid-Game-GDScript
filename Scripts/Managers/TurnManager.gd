extends Manager
class_name TurnManager


var turns : Array[TurnData]
var current_turn : TurnData
var is_busy = false

signal  turn_changed(current_turn : TurnData)


func _get_manager_name() -> String: return "TurnManager"


func _setup_conditions() -> bool: return true


func _setup():
	
	var array : Array = UtilityMethods.load_files_of_type_from_directory("res://Data/Turns/","TeamTurnData")
	print("init array count : " + str(array.size()))
	for child in array:
		if child is not TurnData:
			continue
		turns.append(child)
	
	if turns == null or turns.size() < 1:
		push_error("No turn Data resources found! returning")
		return
	
	turns.sort_custom(Callable(self, "_sort_by_priority"))
	

	current_turn = turns[0]
	
	setup_completed.emit()
	return



func save_data() -> Dictionary:
	var save_dict = {
		"filename" : get_scene_file_path(),
		"parent" : get_parent().get_path(),
	}
	return save_dict


func _execute_conditions() -> bool: return true


func _execute():
	
	for turn in turns:
		if turn is TeamTurnData:
			var team_turn : TeamTurnData = turn as TeamTurnData
			team_turn.team_holder = GameManager.managers["UnitManager"].UnitTeams[team_turn.team]
	
	execute_current_turn()
	execution_completed.emit()
	return;


func on_scene_changed(_new_scene: Node):
	if not GameManager.current_scene_name == "BattleScene":
		queue_free()

func _on_exit_tree() -> void:
	return

func execute_current_turn():
	if current_turn == null and (turns == null or turns.size() < 1):
		push_error("Current turn null")
		return
	else: if current_turn == null:
		current_turn = turns[0]
	
	print(current_turn.turn_name)
	current_turn.execute_turn_segments()
	
	if not current_turn.is_connected("turn_execution_finished", current_turn_turn_execution_finished):
		current_turn.connect("turn_execution_finished",current_turn_turn_execution_finished)

func current_turn_turn_execution_finished():
	end_turn()


func _sort_by_priority(a: TurnData, b: TurnData) -> bool:
	return a.turn_priority < b.turn_priority


func end_turn():
	if current_turn == null:
		push_error("Turn end function called when current turn is null!")
		return
	
	if current_turn.is_connected("turn_execution_finished", current_turn_turn_execution_finished):
		current_turn.disconnect("turn_execution_finished", current_turn_turn_execution_finished)
	current_turn = get_next_turn(current_turn)
	turn_changed.emit(current_turn)
	execute_manager_flow()
	is_busy = true
	


func get_next_turn(currentTurn : TurnData) -> TurnData:
	var current_index = turns.find(currentTurn)
	
	# If current turn not found in array, return empty dictionary
	if current_index == -1:
		return null
	
	var array_size = turns.size()
	
	# If array is empty, return empty dictionary
	if array_size == 0:
		return null
	
	# Loop through the array starting from next position to find the next valid turn
	for i in range(1, array_size + 1):
		var check_index = (current_index + i) % array_size
		var turn = turns[check_index]
		
		if turn == null or not turn.repeatable:
			continue
			
		return turn
	
	# If no valid turn found after checking all possibilities, return null
	return null
