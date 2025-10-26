extends InventoryGridUI
class_name MouseHeldInventoryUI

@export var inventory_holder : InventoryGridHolder

func _ready() -> void:
	for child in UtilityMethods.get_all_children(self, true):
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	inventory_holder._setup()
	inventory_grid = inventory_holder.inventory_grid
	super._ready()



func _process(_delta):
	if not is_shown:
		return
	var mouse_pos = get_global_mouse_position() + Vector2(5,5)
	# Constrain to viewport
	mouse_pos.x = clamp(mouse_pos.x, 0, get_viewport_rect().size.x - size.x)
	mouse_pos.y = clamp(mouse_pos.y, 0, get_viewport_rect().size.y - size.y)
	position = mouse_pos
