extends UIWindow
class_name TurnUI

@export var turn_label : Label
@export var end_turn_button : Button


func _setup():
	print("GRRRRRR")
	end_turn_button.pressed.connect(call_end_turn)
	TurnManager.connect("turn_changed",TurnManager_turn_changed)
	turn_label.text = "Current Turn: " + TurnManager.current_turn.turn_name
	super._setup()



func TurnManager_turn_changed(current_turn : TurnData):
	if current_turn == null:
		return

	turn_label.text = "Current Turn: " + current_turn.turn_name
	
	if TurnManager.current_turn is TeamTurnData and not TurnManager.current_turn.team & Enums.unitTeam.PLAYER:
		end_turn_button.hide()
	else:
		end_turn_button.show()


func call_end_turn():
	if TurnManager.current_turn is TeamTurnData and TurnManager.current_turn.team & Enums.unitTeam.PLAYER:
		print("end Turn")
		TurnManager.end_turn()
		
