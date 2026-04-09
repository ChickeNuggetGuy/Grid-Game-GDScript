class_name GlobeViewUI
extends UIWindow

@export var funds_text : Label
@export var ship_selection_ui : ShipSelectionUI
@export var send_ship_button : Button



func _setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE 
	super._setup()
	
	var globe_team_manager : GlobeTeamManager = GameManager.get_manager("GlobeTeamManager")
	if not globe_team_manager:
		return
	
	var team_holder : GlobeTeamHolder = globe_team_manager.get_team_holder(Enums.unitTeam.PLAYER)
	if team_holder:
		team_holder.on_current_funds_changed.connect(globe_manager_funds_changed)
		update_visuals(team_holder.get_current_funds())
		
	if send_ship_button and not send_ship_button.pressed.is_connected(_on_send_mission_button_pressed):
		send_ship_button.pressed.connect(_on_send_mission_button_pressed)



func build_base_on_button_pressed() -> void:
	GameManager.managers["GlobeManager"].build_base_mode = true


func globe_manager_funds_changed(current_funds):
	funds_text.text = "$" + str(current_funds)


func update_visuals(current_funds : int ):
	funds_text.text =  "$" + str(current_funds)


func _on_send_mission_button_pressed() -> void:
	ship_selection_ui.toggle()
