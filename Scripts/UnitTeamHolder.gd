class_name UnitTeamHolder
extends Node

@export var gridObjects : Array[GridObject]
@export var team : Enums.unitTeam

func _init(gridObjects : Array[GridObject], team : Enums.unitTeam) -> void:
		self.gridObjects = gridObjects
		self.team = team
