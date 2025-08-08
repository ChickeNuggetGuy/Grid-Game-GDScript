class_name UnitTeamHolder
extends Node

@export var gridObjects : Array[GridObject]
@export var team : Enums.unitTeam

func _init() -> void:
	gridObjects = []
