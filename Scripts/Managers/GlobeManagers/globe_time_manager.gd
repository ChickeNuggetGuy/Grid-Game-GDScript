extends Manager
class_name GlobeTimeManager

@export var time_speed: int = 1
@export var current_time_ui: Label

@export_group("Sun / Day-Night")
@export var sun_light: DirectionalLight3D
@export_range(0.0, 45.0, 0.01) var axial_tilt_degrees: float = 23.44
@export_range(-180.0, 180.0, 0.1) var sun_time_offset_degrees: float = 0.0
@export_range(0.0, 20.0, 0.01) var sun_follow: float = 6.0

var current_year: int = 2001
var current_month: int = Enums.Month.SEPTEMBER
var current_day_of_month: int = 5
var current_day_of_year: int = 0
var current_day: int = Enums.Day.WEDNESDAY

var current_hour: int = 12
var current_minute: int = 26
var current_seconds: int = 1

const SECONDS_PER_DAY: int = 24 * 60 * 60

const MONTH_ORDER: Array[int] = [
	Enums.Month.JANUARY,
	Enums.Month.FEBUARY,
	Enums.Month.MARCH,
	Enums.Month.APRIL,
	Enums.Month.MAY,
	Enums.Month.JUNE,
	Enums.Month.JULY,
	Enums.Month.AUGUST,
	Enums.Month.SEPTEMBER,
	Enums.Month.OCTOBER,
	Enums.Month.NOVEMBER,
	Enums.Month.DECEMBER,
]

const DAY_ORDER: Array[int] = [
	Enums.Day.MONDAY,
	Enums.Day.TUESDAY,
	Enums.Day.WEDNESDAY,
	Enums.Day.THURSDAY,
	Enums.Day.FRIDAT,
	Enums.Day.SATURDAY,
	Enums.Day.SUNDAY,
]

const MONTH_NAMES := {
	Enums.Month.JANUARY: "January",
	Enums.Month.FEBUARY: "February",
	Enums.Month.MARCH: "March",
	Enums.Month.APRIL: "April",
	Enums.Month.MAY: "May",
	Enums.Month.JUNE: "June",
	Enums.Month.JULY: "July",
	Enums.Month.AUGUST: "August",
	Enums.Month.SEPTEMBER: "September",
	Enums.Month.OCTOBER: "October",
	Enums.Month.NOVEMBER: "November",
	Enums.Month.DECEMBER: "December",
}

const DAY_NAMES := {
	Enums.Day.MONDAY: "Monday",
	Enums.Day.TUESDAY: "Tuesday",
	Enums.Day.WEDNESDAY: "Wednesday",
	Enums.Day.THURSDAY: "Thursday",
	Enums.Day.FRIDAT: "Friday",
	Enums.Day.SATURDAY: "Saturday",
	Enums.Day.SUNDAY: "Sunday",
}

var days_in_month := {
	Enums.Month.JANUARY: 31,
	Enums.Month.FEBUARY: 28,
	Enums.Month.MARCH: 31,
	Enums.Month.APRIL: 30,
	Enums.Month.MAY: 31,
	Enums.Month.JUNE: 30,
	Enums.Month.JULY: 31,
	Enums.Month.AUGUST: 31,
	Enums.Month.SEPTEMBER: 30,
	Enums.Month.OCTOBER: 31,
	Enums.Month.NOVEMBER: 30,
	Enums.Month.DECEMBER: 31,
}

var timer: Timer
var seconds_of_day: int = 0

signal date_changed(year: int, month: int, day_of_month: int, day: int)
signal time_changed(hour: int, minute: int, second: int)
signal day_changed(day_of_year: int, day_of_month: int, day: int)
signal month_changed(month: int)
signal year_changed(year: int)


func _get_manager_name() -> String:
	return "GlobeTimeManager"


func save_data() -> Dictionary:
	return {
		"time_speed": time_speed,
		"current_year": current_year,
		"current_month": current_month,
		"current_day_of_month": current_day_of_month,
		"current_day": current_day,
		"current_hour": current_hour,
		"current_minute": current_minute,
		"current_seconds": current_seconds,
	}


func _setup_conditions() -> bool:
	return true


func _execute_conditions() -> bool:
	return true


func _setup() -> void:
	is_busy = true

	_apply_loaded_data()
	_recompute_derived_date_fields()
	seconds_of_day = (
		(current_hour * 3600) + (current_minute * 60) + current_seconds
	)

	if is_instance_valid(timer):
		if timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.disconnect(_on_timer_timeout)
		timer.queue_free()

	timer = Timer.new()
	timer.wait_time = 0.05
	timer.one_shot = false
	timer.autostart = false
	timer.paused = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

	_update_ui()

	is_busy = false
	setup_completed.emit()


func _execute() -> void:
	is_busy = true

	if is_instance_valid(timer):
		timer.paused = false
		timer.start()

	is_busy = false
	execution_completed.emit()


func _exit_tree() -> void:
	if is_instance_valid(timer):
		if timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.disconnect(_on_timer_timeout)
		timer.stop()


func _process(delta: float) -> void:
	_update_sun_light(delta)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if (
			key_event.pressed
			and not key_event.echo
			and key_event.keycode == Key.KEY_O
		):
			print(
				"Current Date is %s/%02d/%d\nCurrent Time: %02d:%02d:%02d"
				% [
					_month_to_string(current_month),
					current_day_of_month,
					current_year,
					current_hour,
					current_minute,
					current_seconds,
				]
			)


func _on_timer_timeout() -> void:
	var add: int = max(0, time_speed)
	_advance_time_by_seconds(add)

	_update_ui()
	time_changed.emit(current_hour, current_minute, current_seconds)


func _advance_time_by_seconds(seconds_to_add: int) -> void:
	if seconds_to_add <= 0:
		return

	var total: int = seconds_of_day + seconds_to_add
	var days_to_advance: int = total / SECONDS_PER_DAY
	seconds_of_day = total % SECONDS_PER_DAY

	if days_to_advance > 0:
		_advance_date_by_days(days_to_advance)

	current_hour = seconds_of_day / 3600
	current_minute = (seconds_of_day % 3600) / 60
	current_seconds = seconds_of_day % 60


func _advance_date_by_days(days: int) -> void:
	if days <= 0:
		return

	_advance_day_of_week(days)

	var did_month_change: bool = false
	var did_year_change: bool = false

	while days > 0:
		var dim: int = int(days_in_month[current_month])
		var remaining_in_month: int = dim - current_day_of_month

		if days <= remaining_in_month:
			current_day_of_month += days
			days = 0
		else:
			days -= remaining_in_month + 1
			current_day_of_month = 1

			if current_month == Enums.Month.DECEMBER:
				current_month = Enums.Month.JANUARY
				current_year += 1
				did_month_change = true
				did_year_change = true
			else:
				current_month = _get_next_month(current_month)
				did_month_change = true

	_recompute_derived_date_fields()

	day_changed.emit(current_day_of_year, current_day_of_month, current_day)
	date_changed.emit(
		current_year,
		current_month,
		current_day_of_month,
		current_day
	)

	if did_month_change:
		month_changed.emit(current_month)

	if did_year_change:
		year_changed.emit(current_year)


func _advance_day_of_week(days: int) -> void:
	var index: int = DAY_ORDER.find(current_day)
	if index == -1:
		index = 0

	current_day = DAY_ORDER[(index + (days % DAY_ORDER.size())) % DAY_ORDER.size()]


func _recompute_derived_date_fields() -> void:
	var doy: int = 0

	for month_value in MONTH_ORDER:
		if month_value == current_month:
			break
		doy += int(days_in_month[month_value])

	current_day_of_year = doy + current_day_of_month


func _update_ui() -> void:
	if current_time_ui == null:
		return

	current_time_ui.text = (
		"Current Time: %02d:%02d:%02d\nDate: %s %02d, %d"
		% [
			current_hour,
			current_minute,
			current_seconds,
			_month_to_string(current_month),
			current_day_of_month,
			current_year,
		]
	)


func _update_sun_light(delta: float) -> void:
	if sun_light == null:
		return

	var day01: float = float(seconds_of_day) / float(SECONDS_PER_DAY)
	var target_y: float = -(day01 * TAU) + deg_to_rad(sun_time_offset_degrees)

	var speed: float = sun_follow * max(1.0, float(time_speed))
	var t: float = 1.0 - exp(-speed * delta)

	var rot: Vector3 = sun_light.rotation
	rot.x = deg_to_rad(axial_tilt_degrees)
	rot.y = lerp_angle(rot.y, target_y, t)
	rot.z = 0.0
	sun_light.rotation = rot


func set_time_speed(amount: int) -> void:
	time_speed = amount


func try_get_day_of_month(day_of_year: int) -> Dictionary:
	if day_of_year < 1 or day_of_year > 365:
		return {
			"success": false,
			"day_of_month": -1,
			"month": Enums.Month.JANUARY,
		}

	var remaining: int = day_of_year

	for month_value in MONTH_ORDER:
		var dim: int = int(days_in_month[month_value])

		if remaining <= dim:
			return {
				"success": true,
				"day_of_month": remaining,
				"month": month_value,
			}

		remaining -= dim

	return {
		"success": false,
		"day_of_month": -1,
		"month": Enums.Month.JANUARY,
	}


func _apply_loaded_data() -> void:
	if load_data.is_empty():
		return

	time_speed = int(load_data.get("time_speed", time_speed))
	current_year = int(load_data.get("current_year", current_year))
	current_month = int(load_data.get("current_month", current_month))
	current_day_of_month = int(
		load_data.get("current_day_of_month", current_day_of_month)
	)
	current_day = int(load_data.get("current_day", current_day))
	current_hour = int(load_data.get("current_hour", current_hour))
	current_minute = int(load_data.get("current_minute", current_minute))
	current_seconds = int(load_data.get("current_seconds", current_seconds))


func _get_next_month(month_value: int) -> int:
	var index: int = MONTH_ORDER.find(month_value)
	if index == -1:
		return Enums.Month.JANUARY

	return MONTH_ORDER[(index + 1) % MONTH_ORDER.size()]


func _month_to_string(month_value: int) -> String:
	return String(MONTH_NAMES.get(month_value, "Unknown"))


func _day_to_string(day_value: int) -> String:
	return String(DAY_NAMES.get(day_value, "Unknown"))
