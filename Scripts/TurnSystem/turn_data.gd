extends Resource
class_name TurnData

@export var turn_name : String
@export var turn_segments : Array[TurnSegment]
@export var repeatable : bool = false
@export var turn_priority : int = 0
@export var auto_complete : bool = false
signal turn_execution_started()
signal turn_execution_finished()


	
func execute_turn_segments():
	if turn_segments == null or turn_segments.size() < 1:
		push_error("Turn segments array is invalid!")
		return
	turn_execution_started.emit()
	
	for segment in turn_segments:
		if GameManager.current_scene_type != GameManager.sceneType.BATTLESCENE:
			break
		if GameManager.managers["TurnManager"].game_over == true:
			break
		await  segment.execute(self)
	
	if auto_complete:
		turn_execution_finished.emit()
