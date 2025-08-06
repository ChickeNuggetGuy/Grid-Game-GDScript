extends Resource
class_name TurnData

@export var turn_name : String
@export var turn_segments : Array[TurnSegment]

signal turn_execution_started()
signal turn_execution_finished()

func execute_turn_segments():
	if turn_segments == null or turn_segments.size() < 1:
		push_error("Turn segments array is invalid!")
		return
	turn_execution_started.emit()
	
	for segment in turn_segments:
		await  segment.execute()
	
	turn_execution_finished.emit()
