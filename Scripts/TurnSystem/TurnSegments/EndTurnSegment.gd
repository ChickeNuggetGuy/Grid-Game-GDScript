extends TurnSegment
class_name EndTuenSegment


func execute(parent_turn : TurnData):
	TurnManager.end_turn()
