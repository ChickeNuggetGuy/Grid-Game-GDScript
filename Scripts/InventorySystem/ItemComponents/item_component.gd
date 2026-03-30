@abstract
class_name ItemComponent
extends  Resource
var parent_item

func setup_call(item : Item) -> void:
	parent_item = item
	setup()

@abstract func get_class_name()

@abstract func setup()
