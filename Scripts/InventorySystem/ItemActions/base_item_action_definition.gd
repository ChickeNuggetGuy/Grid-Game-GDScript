@abstract extends  BaseActionDefinition
class_name BaseItemActionDefinition

var parent_item : Item
var starting_inventory : InventoryGrid


func instantiate(parameters : Dictionary) -> Action:
	if action_script == null:
		load_action_script()
	
	parameters["item"] = parent_item
	parameters["starting_inventory"] = starting_inventory
	var a: Action = action_script.new(parameters)
	a.action_name  = self.resource_name
	return a
