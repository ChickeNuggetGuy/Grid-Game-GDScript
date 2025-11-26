extends GridObjectComponent
class_name GridObjectWorldTarget

@export var targets : Dictionary[String, Node3D]

func  _setup( _extra_params : Dictionary,loading_data : bool):
	return


func save_data() -> Dictionary:
	
	var target_dict = {"targets" : {}}
	
	for target_key in targets.keys():
		target_dict["targets"][target_key] = { 
			"path" :  targets[target_key].get_path(),
			"position" : targets[target_key].position,
			"rotation" : targets[target_key].rotation
		}
	return target_dict

func load_data(data : Dictionary):
	printerr("Not implemented")
