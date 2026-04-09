extends Node
class_name GlobeTeamHolder

@export var team: Enums.unitTeam
@export var _current_funds : int
@export var base_indicies: Array[int ] = []


signal on_current_funds_changed(current_funds : int)

func _init(t : Enums.unitTeam, funds : int, bases: Array[int]) -> void:
	team = t
	_current_funds = funds
	base_indicies = bases


func get_current_funds() -> int:
	return _current_funds


func set_current_funds(value : int):
	_current_funds = value
	on_current_funds_changed.emit(_current_funds)


func add_funds(value : int):
	_current_funds += value
	on_current_funds_changed.emit(_current_funds)


func remove_funds(value : int):
	_current_funds -= value
	on_current_funds_changed.emit(_current_funds)


func add_base_index(index : int):
	if not base_indicies.has(index):
		base_indicies.append(index)

#region save/load functions

func serialize() -> Dictionary[String, Variant]:
	var return_value : Dictionary[String, Variant] = {
		"team": team,
		"_current_funds" : _current_funds,
		"base_indicies" : base_indicies
		}
	
	return return_value
	


static func deserialize(data: Dictionary) -> GlobeTeamHolder:
	var raw_bases: Array = data.get("base_indicies", [])
	var bases: Array[int] = []
	
	for value in raw_bases:
		bases.append(int(value))
	
	var instance := GlobeTeamHolder.new(
		int(data.get("team", -1)),
		int(data.get("_current_funds", 0)),
		bases
	)
	return instance
#endregion
