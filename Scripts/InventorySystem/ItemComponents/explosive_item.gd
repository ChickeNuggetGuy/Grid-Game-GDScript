class_name ExplosiveComponent
extends ItemComponent

@export var turn_timer : int = 1
var primed : bool = false
@export var costs : Dictionary[Enums.Stat, int] ={}


func get_class_name(): return "ExplosiveComponent"

func _init() -> void:
	turn_timer = 1


func setup():
	pass



func prime():
	primed = true
	GameManager.managers["TurnManager"].turn_changed.connect(turn_manager_turn_changed)
	pass


func turn_manager_turn_changed(_current_turn : TurnData):
	if not primed:
		return
	turn_timer -= 1
	if turn_timer <= 0:
		print("explode")
