class_name GameSavesUI
extends UIWindow

@export var save_game_list : ItemList
@export var new_save_button : Button
@export var load_save_button : Button
@export var delete_save_button : Button
@export var text_edit_field : TextEdit
@export var save_icon : Texture2D


func _setup():
	GameManager.create_save_directory()
	if not GameManager.save_games_changed.is_connected(refresh_save_list):
		GameManager.save_games_changed.connect(refresh_save_list)

func _show():
	refresh_save_list()
	super._show()

func refresh_save_list():
	save_game_list.clear()
	var result = GameManager.try_load_save_game_files()
	
	if result["success"]:
		print("Loading: " + str(result["save_files"].size()) + " save files")
		for save_game in result["save_files"]:
			save_game_list.add_item(save_game, save_icon)
	else:
		print("Loading Failed")

func _on_save_button_pressed() -> void:
	var save_name = text_edit_field.text.strip_edges()
	if save_name.is_empty():
		print("Please enter a save name")
		return
	
	if not save_name.ends_with(".json"):
		save_name += ".json"
	
	GameManager.current_save_file = save_name
	GameManager.current_scene_type = GameManager.sceneType.GLOBE
	GameManager.save_game_data(GameManager.get_current_scene_data(), save_name, true)


func _on_delete_button_pressed() -> void:
	if save_game_list.is_anything_selected():
		var selected_items = save_game_list.get_selected_items()
		for index in selected_items:
			var file_name = save_game_list.get_item_text(index)
			GameManager.delete_save_file_absolute(file_name)


func load_save_data(file_name: String) -> Dictionary:
	var path = GameManager.save_directory.path_join(file_name)
	var file = FileAccess.open(path, FileAccess.READ)
	
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			return {"success": true, "data": json.data}
		else:
			print("Error parsing JSON: ", json.get_error_message())
			return {"success": false, "data": {}}
	else:
		print("Error opening file: ", path)
		return {"success": false, "data": {}}

func _on_load_save_button_pressed() -> void:
	if save_game_list.is_anything_selected():
		var selected_index = save_game_list.get_selected_items()[0]
		var file_name = save_game_list.get_item_text(selected_index)
		var result = load_save_data(file_name)
		
		if result["success"]:
			apply_save_data(result["data"])
		else:
			print("Failed to load save file")

func apply_save_data(data: Dictionary):
	print("Loading save data: ", data)


func _on_load_button_2_pressed() -> void:
	if not save_game_list.get_selected_items().is_empty():
		GameManager.current_save_file = save_game_list.get_item_text(save_game_list.get_selected_items()[0])
		GameManager.load_game_data(GameManager.current_save_file)
