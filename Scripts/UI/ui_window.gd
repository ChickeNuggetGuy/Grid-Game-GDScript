extends UIElement
class_name UIWindow

#region Variables
var is_shown: bool = false

@export var start_hidden: bool = false
@export var block_inputs: bool = false
@export var input_key: Key
@export var visual: Control
@export var is_persistent_window: bool = true
@export var toggle_button: Button

var ui_elements: Array[UIElement] = []
#endregion


#region Functions
func _ready() -> void:
	add_to_group("UIWindow")

	if (
		toggle_button
		and not toggle_button.pressed.is_connected(toggle_button_pressed)
	):
		toggle_button.pressed.connect(toggle_button_pressed)


func toggle_button_pressed() -> void:
	toggle()


func show_call() -> void:
	_show()
	is_shown = true


func _show() -> void:
	if visual != null:
		visual.show()
	else:
		push_warning("Visual for UI Window is null!")

	if block_inputs:
		var ui_manager := _get_ui_manager()
		if ui_manager:
			ui_manager.try_block_input(self)


func hide_call() -> void:
	_hide()


func _hide() -> void:
	if visual == null:
		push_warning("Visual for UI Window is null!")
		return

	visual.hide()
	is_shown = false

	var ui_manager := _get_ui_manager()
	if (
		ui_manager
		and ui_manager.blocking_input
		and ui_manager.blocking_window == self
	):
		ui_manager.unblock_input()


func toggle() -> void:
	if is_shown:
		hide_call()
	else:
		show_call()


func _setup() -> void:
	print("setup: " + name)
	var ui_manager := _get_ui_manager()
	if ui_manager:
		ui_manager.add_ui_window(self)

	ui_elements.clear()
	_collect_owned_ui_elements(self)

	for element in ui_elements:
		if element != null:
			await element.setup_call()

	if start_hidden:
		hide_call()
	else:
		show_call()


func _collect_owned_ui_elements(node: Node) -> void:
	for child in node.get_children():
		if child is UIWindow:
			var child_window := child as UIWindow

			if not ui_elements.has(child_window):
				ui_elements.append(child_window)

			continue

		if child is UIElement:
			var child_element := child as UIElement

			if not ui_elements.has(child_element):
				ui_elements.append(child_element)

		_collect_owned_ui_elements(child)


func _get_ui_manager() -> UIManager:
	if GameManager == null:
		return null

	if not GameManager.managers.has("UIManager"):
		return null

	return GameManager.managers["UIManager"] as UIManager


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == input_key:
			toggle()
#endregion
