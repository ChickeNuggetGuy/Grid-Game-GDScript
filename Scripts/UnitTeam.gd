class_name UnitTeam
extends Node

@export var gridObjects : Array[GridObject]
@export var team : Enums.unit_team

func _init(gridObjects : Array[GridObject], team : Enums.unit_team) -> void:
		self.gridObjects = gridObjects
		self.team = team
