class_name MissionDefinition
extends HexCellDefinition

var enemy_spawn: int

func _init(index: int = -1, _enemy_spawn: int = -1) -> void:
	if _enemy_spawn >= 0:
		enemy_spawn = _enemy_spawn
	else:
		enemy_spawn = randi_range(1, 5)
	super._init(index)

func get_class_name() -> String: return "MissionDefinition"
func get_cell_color() -> Color: return Color.RED

func serialize() -> Dictionary:
	var data := super.serialize()
	data["enemy_spawn"] = enemy_spawn
	return data

static func deserialize(data: Dictionary) -> MissionDefinition:
	var idx := int(data.get("cell_index", -1))
	var es := int(data.get("enemy_spawn", -1))
	return MissionDefinition.new(idx, es)
