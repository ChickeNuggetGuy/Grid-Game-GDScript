extends Node
class_name InventoryGridHolder

@export var inventory_grid_type : Enums.inventoryType

var inventory_grid : InventoryGrid

func _setup() -> void:
	inventory_grid = InventoryManager.try_get_inventory_grid(Enums.inventoryType.MOUSEHELD)["inventory_grid"]
