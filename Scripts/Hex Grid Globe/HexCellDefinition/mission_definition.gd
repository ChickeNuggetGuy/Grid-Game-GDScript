class_name MissionDefinition
extends HexCellDefinition

var enemy_spawn: int
var on_route_craft : Craft = null
var mission_status : Enums.MissionStatus = Enums.MissionStatus.UNVISITED

var completed_point_gain : int = 250
var failed_point_loss : int = 300
var expired_point_loss : int = 250

func _init(index: int = -1, _enemy_spawn: int = -1) -> void:
	definition_type = Enums.HexCellDefinitionType.MISSION
	if _enemy_spawn >= 0:
		enemy_spawn = _enemy_spawn
	else:
		enemy_spawn = randi_range(1, 5)
	super._init(index)

func get_class_name() -> String: return "MissionDefinition"
func get_cell_color() -> Color: return Color.RED


func send_craft_home(remove_mission_def : bool):
	if not on_route_craft:
		return 
	
	var mission_manager : GlobeMissionManager = GameManager.get_manager("GlobeMissionManager")
	var globe_manager : GlobeManager = GameManager.get_manager("GlobeManager")

	if not mission_manager or not globe_manager:
		return
	
	mission_manager.send_ship_to_cell(cell_index, on_route_craft.home_cell_index, on_route_craft)
	
	if remove_mission_def:
		globe_manager.hex_grid_data.remove_cell_definition(cell_index, Enums.HexCellDefinitionType.MISSION)


func serialize() -> Dictionary:
	var data := super.serialize()
	data["enemy_spawn"] = enemy_spawn
	data["mission_status"] = int(mission_status)    
	if on_route_craft:
		data["onroute_craft"] = on_route_craft.serialize()
	return data

static func deserialize(data: Dictionary) -> MissionDefinition:
	var idx := int(data.get("cell_index", -1))
	var es := int(data.get("enemy_spawn", -1))
	var inst := MissionDefinition.new(idx, es)
	if data.has("onroute_craft"):
		inst.on_route_craft = Craft.deserialize(data.get("onroute_craft", {}))
	inst.mission_status = int(data.get("mission_status", Enums.MissionStatus.UNVISITED))
	return inst
