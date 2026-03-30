extends TurnSegment
class_name EndTuenSegment


func execute(_parent_turn : TurnData):
	GameManager.managers["TurnManager"].end_turn()
