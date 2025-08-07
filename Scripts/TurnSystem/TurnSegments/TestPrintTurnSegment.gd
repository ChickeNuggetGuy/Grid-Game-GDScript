extends TurnSegment
class_name TestPrintTurnSegment
@export var print_string : String


func execute(_parent_turn : TurnData):
	print(print_string)
