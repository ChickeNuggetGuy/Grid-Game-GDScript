extends Resource
class_name HexGridData

signal definitions_changed


var cell_definitions: Dictionary = {}
var _dirty := false
var hex_decorator : HexGridDecorator

func _init(decorator : HexGridDecorator) -> void:
	hex_decorator = decorator
	
func add_cell_definition(
	cell_index: int,
	definition: HexCellDefinition,
	hex_decorator: HexGridDecorator
) -> void:
	var def_type = definition.get_class_name()
	
	if not cell_definitions.has(def_type):
		cell_definitions[def_type] = []
	
	cell_definitions[def_type].append(definition)

	if hex_decorator and hex_decorator.is_inside_tree():
		hex_decorator.request_definitions_rebuild()

func add_cell_definitions_bulk(items: Dictionary) -> void:
	for it in items.keys():
		var idx: int = int(it)
		for def in items[it]:
			add_cell_definition(idx, def, hex_decorator)
	_dirty = true


func add_cell_definitions_from_data_bulk(items: Dictionary) -> void:
	for def_type in items.keys():
		for def_data in items[def_type]:
			var inst: HexCellDefinition = null
			match def_type:
				"CityDefinition":
					inst = CityDefinition.deserialize(def_data)
				"TeamBaseDefinition":
					inst = TeamBaseDefinition.deserialize(def_data)
				"MissionDefinition":
					inst = MissionDefinition.deserialize(def_data)
				_:
					# Fallback to NodeUtils for any other defs
					inst = NodeUtils.create_instance_from_data(def_data)

			if inst == null:
				push_warning(
					"Failed to deserialize def_type=%s (class_name=%s)" % [
						def_type,
						str(def_data.get("class_name", "?"))
					]
				)
				continue

			var cell_index := int(def_data.get("cell_index", -1))
			if cell_index != -1:
				add_cell_definition(cell_index, inst, hex_decorator)
	_dirty = true

func get_cell_definitions(cell_index: int) -> Array:
	var result: Array = []
	
	for def_type in cell_definitions.keys():
		for definition in cell_definitions[def_type]:
			if definition.cell_index == cell_index:
				result.append(definition)
	
	return result

func get_definitions_by_type(def_type: String) -> Array:
	if cell_definitions.has(def_type):
		return cell_definitions[def_type]
	return []

func get_all_cell_definitions(type_filter: Array[String] = [], exempt: bool = false) -> Dictionary:
	var return_value: Dictionary = {}
	
	for def_type in cell_definitions.keys():
		var should_include: bool = false
		
		if type_filter.is_empty():
			# No filter, include all definitions
			should_include = true
		else:
			# Apply filter
			var matches_filter = type_filter.has(def_type)
			if exempt:
				# Include if NOT in filter (exempt from filter)
				should_include = not matches_filter
			else:
				# Include if IS in filter
				should_include = matches_filter
		
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
