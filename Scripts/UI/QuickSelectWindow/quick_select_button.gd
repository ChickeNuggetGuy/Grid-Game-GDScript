extends UIElement
class_name QuickSelectButton

@export var name_label : Label
@export var unit_icon : TextureRect
@export var stat_progress_bars : Dictionary[Enums.Stat, StatProgressBar] ={}
@export var button : Button

var _unit : Unit

func _setup() -> void:
	pass


func set_unit(new_unit : Unit):
	
	if not button.pressed.is_connected(button_on_pressed):
		button.pressed.connect(button_on_pressed)
		
	_unit = new_unit
	
	if name_label:
		name_label.text = _unit.data.name
	
	if unit_icon and _unit.data.icon:
		unit_icon.texture = _unit.data.icon
	
	
	for stat_key in stat_progress_bars:
		var stat_progress_bar : StatProgressBar = stat_progress_bars[stat_key]
		if not stat_progress_bar:
			continue
		
		stat_progress_bar.setup(_unit,)
	
	


func button_on_pressed():
	if not _unit:
		push_error("Unit not assigned to quick select button!")
		return
	
	var unit_manager : UnitManager = GameManager.get_manager("UnitManager")
	
	if not unit_manager:
		push_error("Cannot find unit manager!")
		return
	
	
	unit_manager.set_selected_unit(_unit)
