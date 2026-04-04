@abstract
extends Control
class_name UIElement

signal setup_finished()

@export var ui_name: String

var _is_setup: bool = false
var _is_setting_up: bool = false


func setup_call() -> void:
	if _is_setup:
		return

	if _is_setting_up:
		await setup_finished
		return

	_is_setting_up = true


	await _setup()

	_is_setup = true
	_is_setting_up = false
	setup_finished.emit()


func reset_setup_state() -> void:
	_is_setup = false
	_is_setting_up = false


@abstract func _setup() -> void
