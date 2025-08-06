class_name UnitTeamHolder
extends Node

@export var gridObjects : Array[GridObject]
@export var team : Enums.unitTeam

func _init(gridObject_array : Array[GridObject], unit_team : Enums.unitTeam) -> void:
		self.gridObjects = gridObject_array
		self.team = unit_team
