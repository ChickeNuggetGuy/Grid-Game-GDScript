class_name GlobeViewUI
extends UIWindow

@export var funds_text : Label
@export var ship_selection_ui : ShipSelectionUI
@export var send_ship_button : Button

@export var bases_button_holder : VBoxContainer
@export var monthly_score_label : Label


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
		
		team_holder.bases_changed.connect(team_holder_bases_changed)
		team_holder_bases_changed(team_holder.base_indicies, team_holder)
		
		team_holder.monthly_score_chnaged.connect(team_holder_score_changed)
		team_holder_score_changed(team_holder._monthly_score)
	
	if send_ship_button and not send_ship_button.pressed.is_connected(_on_send_mission_button_pressed):
		send_ship_button.pressed.connect(_on_send_mission_button_pressed)
	


func team_holder_score_changed(value : int):
	monthly_score_label.text = "Monthly Score: " + str(value)

func team_holder_bases_changed(bases : Array[int], team_holder : GlobeTeamHolder):
	for child in bases_button_holder.get_children():
		child.queue_free()
	
	var globe_manager : GlobeManager = GameManager.get_manager("GlobeManager")
	var camera : GlobeCameraController = globe_manager.camera_controller
	
	for base_index in bases:
		var base : TeamBaseDefinition = globe_manager.hex_grid_data.get_cell_definitions(base_index)[0]
		var base_button : Button = Button.new()
		base_button.text =  base.base_name
		
		base_button.pressed.connect(Callable(globe_manager,"open_base_scene" ).bind(base))
		bases_button_holder.add_child(base_button)
		


func build_base_on_button_pressed() -> void:
	GameManager.managers["GlobeManager"].build_base_mode = true


func globe_manager_funds_changed(current_funds):
	funds_text.text = "$" + str(current_funds)


func update_visuals(current_funds : int ):
	funds_text.text =  "$" + str(current_funds)


func _on_send_mission_button_pressed() -> void:
	ship_selection_ui.toggle()
