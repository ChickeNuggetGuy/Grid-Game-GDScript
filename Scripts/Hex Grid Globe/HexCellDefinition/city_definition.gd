extends HexCellDefinition
class_name CityDefinition

var city_name: String = ""
var population: int = 0
var country_code: String = ""

func _init(index: int = -1, _city_name: String = "", _population: int = 0, _country_code: String = "") -> void:
	city_name = _city_name
	population = _population
	country_code = _country_code
	super._init(index)

func get_class_name() -> String: 
	return "CityDefinition"

func get_cell_color() -> Color:
	return Color.YELLOW

func serialize() -> Dictionary:
	return {
		"class_name": get_class_name(),
		"cell_index": cell_index,
		"city_name": city_name,
		"population": population,
		"country_code": country_code
	}

static func deserialize(data: Dictionary) -> CityDefinition:
	var instance = CityDefinition.new(
		data.get("cell_index", -1),
		data.get("city_name", ""),
		data.get("population", 0),
		data.get("country_code", "")
	)
	return instance
