extends TurnSegment
class_name EndTuenSegment


func execute(_parent_turn : TurnData):
	TurnManager.Instance.end_turn()
