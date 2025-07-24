extends Control

var currentCellUI : Label
var ui_windows : Dictionary[String, UIWindow] ={}

func _init() -> void:
	self.set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter =Control.MOUSE_FILTER_IGNORE
	currentCellUI = Label.new()
	add_child(currentCellUI)
	currentCellUI.set_anchors_preset(Control.PRESET_CENTER_TOP)
	var interface_scene : PackedScene = load("res://Scenes/Interface.tscn")
	var interface : Control = interface_scene.instantiate()
	add_child(interface)
	interface.set_anchors_preset(Control.PRESET_FULL_RECT)


func add_ui_window(window_to_add : UIWindow):
	if ui_windows.values().has(window_to_add):
		print("UI Window already added, skipping!")
		return
	
	if ui_windows.keys().has(window_to_add.ui_name):
		print("UI Window with name '" + window_to_add.ui_name + "' already added! skipping")
		return
	
	ui_windows[window_to_add.ui_name] = window_to_add
	print("UI Window with name '" + window_to_add.ui_name + "' added!")
