extends Resource
class_name HexGridData

signal definitions_changed


var cell_definitions: Dictionary[Enums.HexCellDefinitionType, Array] = {}
var _dirty := false
var hex_decorator : HexGridDecorator

func _init(decorator : HexGridDecorator) -> void:
	hex_decorator = decorator
	
func add_cell_definition(
	cell_index: int,
	definition_type : Enums.HexCellDefinitionType,
	definition: HexCellDefinition,
	hex_decorator: HexGridDecorator
) -> void:
	
	if not cell_definitions.has(definition_type):
		cell_definitions[definition_type] = []
	
	cell_definitions[definition_type].append(definition)

	if hex_decorator and hex_decorator.is_inside_tree():
		hex_decorator.request_definitions_rebuild()

func add_cell_definitions_bulk(items: Dictionary) -> void:
	for it in items.keys():
		var idx: int = int(it)
		for def in items[it]:
			add_cell_definition(idx,def.definition_type, def, hex_decorator)
	_dirty = true

func add_cell_definitions_from_data_bulk(items: Dictionary) -> void:
	for def_type in items.keys():
		var definitions_array = items[def_type]

		if not definitions_array is Array:
			push_warning(
				"Expected Array for def_type %s, got %s"
				% [str(def_type), typeof(definitions_array)]
			)
			continue

		for definition_data in definitions_array:
			if not definition_data is Dictionary:
				continue

			var inst: HexCellDefinition = null
			var typed_def_type := int(def_type)

			match typed_def_type:
				Enums.HexCellDefinitionType.CITY:
					inst = CityDefinition.deserialize(definition_data)
				Enums.HexCellDefinitionType.BASE:
					inst = TeamBaseDefinition.deserialize(definition_data)
				Enums.HexCellDefinitionType.MISSION:
					inst = MissionDefinition.deserialize(definition_data)
				_:
					inst = NodeUtils.create_instance_from_data(definition_data)

			if inst == null:
				push_warning(
					"Failed to deserialize def_type=%s"
					% str(def_type)
				)
				continue

			var cell_index := int(definition_data.get("cell_index", -1))
			if cell_index != -1:
				add_cell_definition(
					cell_index,
					typed_def_type,
					inst,
					null
				)

	_dirty = true

	if hex_decorator and hex_decorator.is_inside_tree():
		hex_decorator.request_definitions_rebuild()

func get_cell_definitions(cell_index: int) -> Array:
	var result: Array = []
	
	for def_type in cell_definitions.keys():
		for definition in cell_definitions[def_type]:
			if definition.cell_index == cell_index:
				result.append(definition)
	
	return result

func get_definitions_by_type(def_type: Enums.HexCellDefinitionType) -> Array:
	if cell_definitions.has(def_type):
		return cell_definitions[def_type]
	return []

func get_all_cell_definitions(
	type_filter: Array[int] = [],
	exempt: bool = false
) -> Dictionary:
	var return_value: Dictionary = {}

	for def_type in cell_definitions.keys():
		var should_include := false

		if type_filter.is_empty():
			should_include = true
		else:
			var matches_filter = type_filter.has(int(def_type))
			should_include = not matches_filter if exempt else matches_filter

		if should_include and not cell_definitions[def_type].is_empty():
			return_value[def_type] = cell_definitions[def_type]

	return return_value


func get_defined_cell_indices() -> Array:
	var indices: Array = []
	var unique_indices: Dictionary = {}
	
	for def_type in cell_definitions.keys():
		for definition in cell_definitions[def_type]:
			if not unique_indices.has(definition.cell_index):
				unique_indices[definition.cell_index] = true
				indices.append(definition.cell_index)
	
	return indices

func is_dirty() -> bool:
	return _dirty

func clear_dirty() -> void:
	_dirty = false

func clear() -> void:
	cell_definitions.clear()
	_dirty = true
	emit_signal("definitions_changed")
