@abstract extends GridObject
class_name Interactable

@export var costs : Dictionary[Enums.Stat, int] = {Enums.Stat.TIMEUNITS : 0, Enums.Stat.STAMINA : 0}


@abstract func interact()
