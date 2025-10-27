@abstract extends GridObject
class_name Interactable

@export var costs : Dictionary[String, int] = {"time_units" : 0, "stamina" : 0}


@abstract func interact()
