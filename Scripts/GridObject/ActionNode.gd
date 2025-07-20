extends Node
class_name ActionNode

@export_category("Core")
@export var action_script: Script
@export_category("Core")
@export var cost: int

# any other designer‐tweakable fields here...
# e.g. for a “UseItem” action you might @export var item_id: String

# factory method: builds a fresh Action instance
func instantiate(owner: GridObject, optionalVar ) -> Action:
	var a: Action = action_script.new(optionalVar)
	a.owner = owner
	a.name  = name
	a.cost  = cost
	# if your Actions have extra data fields you can copy them here,
	# or expose them on this Resource and assign into `a`.
	return a
