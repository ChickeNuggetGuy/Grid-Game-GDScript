extends Control

var currentCellUI : Label

func _init() -> void:
	self.set_anchors_preset(Control.PRESET_VCENTER_WIDE)
	currentCellUI = Label.new()
	add_child(currentCellUI)
	currentCellUI.set_anchors_preset(Control.PRESET_CENTER_TOP)
