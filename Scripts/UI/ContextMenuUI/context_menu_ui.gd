extends UIWindow
class_name ContextMenuUI

static var intance : ContextMenuUI
var context_menu_buttons : Array[ContextMenuButton]
@export var context_button_scene : PackedScene
@export var context_button_holder : VBoxContainer


func _init() -> void:
	intance = self


func _setup():
	super._setup()


func _show():
	var viewport_size = get_viewport_rect().size
	var mouse_position = get_viewport().get_mouse_position()
	var menu_size = visual.size # Make sure this returns correct size

	# Default position
	position = mouse_position

	# Adjust X axis if menu goes off right edge
	if position.x + menu_size.x > viewport_size.x:
		position.x = viewport_size.x - menu_size.x

	# Adjust Y axis if menu goes off bottom edge
	if position.y + menu_size.y > viewport_size.y:
		position.y = viewport_size.y - menu_size.y

	# Ensure it doesn't go negative (just in case)
	position.x = max(0, position.x)
	position.y = max(0, position.y)

	super._show()

func generate_context_buttons(focused_object : Object):
	
	if context_button_holder.get_child_count() != 0:
		for child in context_button_holder.get_children():
			child.queue_free()
		context_menu_buttons.clear()
	
	if not focused_object.has_method("get_context_items"):
		print("Is not Context item! returning")
		return
	
	var context_items = focused_object.get_context_items()
	for key in context_items.keys():
		var context_item = context_items[key]
		
		var context_button : ContextMenuButton = context_button_scene.instantiate()
		context_menu_buttons.append(context_button)
		context_button_holder.add_child(context_button)
		context_button.initialize(context_item, key)
	
	show_call()
