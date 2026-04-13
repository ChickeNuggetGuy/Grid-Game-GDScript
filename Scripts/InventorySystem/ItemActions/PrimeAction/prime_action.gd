extends Action

var item : ItemData
var explosive_component : ExplosiveComponent 

func _init(parameters : Dictionary) -> void:
	action_name = "Prime"
	costs = {Enums.Stat.TIMEUNITS :8, Enums.Stat.STAMINA: 2}
	owner = parameters["unit"]
	target_grid_cell = parameters["target_grid_cell"]
	start_grid_cell = parameters["start_grid_cell"]
	item = parameters.get("item")
	explosive_component = parameters["explosive_component"]



func _setup() -> void:
	return



func _execute() -> bool:
	explosive_component.prime()
	print ("Primed Item!")
	
	return true


func _action_complete():
	pass


func action_cancel():
	return
