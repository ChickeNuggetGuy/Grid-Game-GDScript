extends Manager

var turns : Array[TurnData]
var current_turn : TurnData
var is_busy = false
func _get_manager_name() -> String: return "Turn Manager"


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


func _execute_conditions() -> bool: return true


func _execute():
	execute_current_turn()
	execution_completed.emit()
	return;



func execute_current_turn():
	if current_turn == null and (turns == null or turns.size() < 1):
		push_error("Current turn null")
		return
	else: if current_turn == null:
		current_turn = turns[0]
	
	print(current_turn.turn_name)
	current_turn.execute_turn_segments()
	
	current_turn.connect("turn_execution_finished",current_turn_turn_execution_finished)

func current_turn_turn_execution_finished():
	end_turn()


func _sort_by_priority(a: TurnData, b: TurnData) -> bool:
	return a.turn_priority < b.turn_priority


func end_turn():
	if current_turn == null:
		push_error("Turn end function called when current turn is null!")
		return
	current_turn = get_next_turn(current_turn)
	is_busy = true
	

func get_next_turn(turn : TurnData) -> TurnData:
	if not turns.has(turn):
		push_error("Turn is not is turns array")
		return
	
	var turn_index = turns.find(turn)
	if turn_index == -1:
		push_error("Turn was not found in turns array")
		return
	
	var next_turn = turns.get(turn_index + 1)
	
	if next_turn == null:
		#at the end of the turns array, cycle the list to the first index
		next_turn = turns[0]
	
	if next_turn == null:
		push_error("There was an error finding next turn!")
		return
	else:
		return next_turn
