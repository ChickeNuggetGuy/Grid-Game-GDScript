class_name GameSavesUI
extends UIWindow

@export var save_game_list: ItemList
@export var new_save_button: Button
@export var load_save_button: Button
@export var delete_save_button: Button
@export var text_edit_field: TextEdit
@export var save_icon: Texture2D
@export var load_new_saves := false

@export var new_game_scene_type: int = 3


func _setup() -> void:
	await super._setup()
	SavesManager.create_save_directory()

	if not SavesManager.save_games_changed.is_connected(refresh_save_list):
		SavesManager.save_games_changed.connect(refresh_save_list)

	if (
		new_save_button
		and not new_save_button.pressed.is_connected(_on_save_button_pressed)
	):
		new_save_button.pressed.connect(_on_save_button_pressed)

	if (
		load_save_button
		and not load_save_button.pressed.is_connected(
			_on_load_save_button_pressed
		)
	):
		load_save_button.pressed.connect(_on_load_save_button_pressed)

	if (
		delete_save_button
		and not delete_save_button.pressed.is_connected(
			_on_delete_button_pressed
		)
	):
		delete_save_button.pressed.connect(_on_delete_button_pressed)


func _show() -> void:
	refresh_save_list()
	super._show()


func refresh_save_list() -> void:
	if save_game_list == null:
		push_warning("Save game list is null")
		return

	save_game_list.clear()

	var result := SavesManager.try_load_save_game_files()

	if not result.get("success", false):
		push_warning(
			"Failed to scan save directory: "
			+ ProjectSettings.globalize_path(SavesManager.save_directory)
		)
		return

	var save_files: Array = result.get("save_files", [])
	print(
		"Found "
		+ str(save_files.size())
		+ " save files in "
		+ ProjectSettings.globalize_path(SavesManager.save_directory)
	)

	for save_game in save_files:
		save_game_list.add_item(str(save_game), save_icon)
func _on_save_button_pressed() -> void:
	
	var save_name : String = ""
	if save_game_list.get_selected_items().size() > 0:
		save_name = save_game_list.get_item_text(save_game_list.get_selected_items()[0])
	
	elif text_edit_field != null:
		save_name = text_edit_field.text.strip_edges()


	if save_name.is_empty():
		print("Please enter a save name")
		return

	if load_new_saves:
		await _create_new_game(save_name)
		return

	save_name = _normalize_save_name(save_name)
	SavesManager.current_save_file = save_name

	var data_to_save := SavesManager.get_current_scene_data(
		SceneManager.current_scene_type
	)

	await SavesManager.save_game_data(data_to_save, save_name, false)


func _on_delete_button_pressed() -> void:
	if save_game_list == null:
		push_warning("Save game list is null")
		return

	if save_game_list.is_anything_selected():
		var selected_items = save_game_list.get_selected_items()
		for index in selected_items:
			var file_name := save_game_list.get_item_text(index)
			SavesManager.delete_save_file_absolute(file_name)


func _on_load_save_button_pressed() -> void:
	if save_game_list == null:
		push_warning("Save game list is null")
		return

	if not save_game_list.is_anything_selected():
		print("No save selected")
		return

	var selected_index := save_game_list.get_selected_items()[0]
	var file_name := save_game_list.get_item_text(selected_index)

	SavesManager.current_save_file = file_name
	await SavesManager.load_game_data(file_name)


func _create_new_game(save_name: String) -> void:
	save_name = _normalize_save_name(save_name)

	var success := await SavesManager.create_new_game(
		save_name,
		new_game_scene_type,
		{}
	)

	if not success:
		push_warning("Failed to create new game: " + save_name)
		return



func _normalize_save_name(save_name: String) -> String:
	save_name = save_name.strip_edges()

	if not save_name.ends_with(".json"):
		save_name += ".json"

	return save_name


func _select_save_in_list(file_name: String) -> void:
	if save_game_list == null:
		return

	for i in range(save_game_list.item_count):
		if save_game_list.get_item_text(i) == file_name:
			save_game_list.select(i)
			return
