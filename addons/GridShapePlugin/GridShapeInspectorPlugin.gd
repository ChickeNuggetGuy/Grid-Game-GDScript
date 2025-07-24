# grid_shape_inspector_plugin.gd
@tool
extends EditorInspectorPlugin

# Store the checkboxes so we can update them later
var _checkboxes: Array[CheckBox] = []
var _current_grid_shape: GridShape # Keep a reference to the current GridShape being edited

func _can_handle(object: Object) -> bool:
	var result = object is GridShape
	# push_warning("_CanHandle: Object type: %s, Is GridShape: %s" % [object.get_class(), result])
	return result

func _parse_property(object: Object, type: int, name: String, hint_type: int, hint_string: String, usage_flags: int, wide: bool) -> bool:
	# push_warning("_ParseProperty: Object type: %s, Property Name: '%s', Type: %s" % [object.get_class(), name, type])

	if object is GridShape:
		var grid_shape: GridShape = object
		# Store the current GridShape being edited
		_current_grid_shape = grid_shape

		# push_warning("  _ParseProperty: Object IS GridShape. Checking property name...")
		if name == "shape_grid":
			# push_warning("  _ParseProperty: MATCHED 'shape_grid'! Adding custom control.")
			var custom_control = _create_checkbox_grid_with_buttons(grid_shape) # Call new function
			add_custom_control(custom_control)
			return true
		else:
			# push_warning("  _ParseProperty: Property '%s' did NOT match 'shape_grid'." % name)
			pass
	else:
		# push_warning("  _ParseProperty: Object is NOT GridShape.")
		# Clear the reference if we're no longer handling a GridShape
		_current_grid_shape = null

	return false

# New function to create the grid with buttons
func _create_checkbox_grid_with_buttons(grid_shape: GridShape) -> Control:
	# Clear previous checkboxes before creating new ones (important when width/height changes)
	_checkboxes.clear()

	var vbox = VBoxContainer.new()

	# Create the buttons container
	var h_buttons = HBoxContainer.new()
	h_buttons.add_theme_constant_override("separation", 10) # Add some spacing

	var check_all_button = Button.new()
	check_all_button.text = "Check All"
	check_all_button.pressed.connect(Callable(self, "_on_check_all_button_pressed").bind(true))
	h_buttons.add_child(check_all_button)

	var uncheck_all_button = Button.new()
	uncheck_all_button.text = "Uncheck All"
	uncheck_all_button.pressed.connect(Callable(self, "_on_check_all_button_pressed").bind(false))
	h_buttons.add_child(uncheck_all_button)

	vbox.add_child(h_buttons)

	var grid_container = GridContainer.new()
	grid_container.columns = grid_shape.grid_width
	vbox.add_child(grid_container)

	for y in range(grid_shape.grid_height):
		for x in range(grid_shape.grid_width):
			var check_box = CheckBox.new()
			check_box.text = "(%s,%s)" % [x, y]
			check_box.button_pressed = grid_shape.get_grid_shape_cell(x, y)

			check_box.toggled.connect(
				Callable(self, "_on_checkbox_pressed").bind(grid_shape, x, y)
			)
			grid_container.add_child(check_box)
			_checkboxes.append(check_box) # Store reference to the checkbox

	# Add a spacer to push the grid up a bit visually if desired
	# var spacer = Control.new()
	# spacer.custom_minimum_size = Vector2(0, 5) # 5 pixels height
	# vbox.add_child(spacer)

	# Make sure to update the current GridShape when the property is parsed
	_current_grid_shape = grid_shape

	return vbox

func _on_checkbox_pressed(new_state: bool, grid_shape: GridShape, x: int, y: int) -> void:
	grid_shape.set_grid_shape_cell(x, y, new_state)

# New method to handle "Check All" / "Uncheck All"
func _on_check_all_button_pressed(check_value: bool) -> void:
	if _current_grid_shape == null:
		push_error("No GridShape currently selected to apply 'Check All/Uncheck All'.")
		return

	var cell_index = 0
	for y in range(_current_grid_shape.grid_height):
		for x in range(_current_grid_shape.grid_width):
			_current_grid_shape.set_grid_shape_cell(x, y, check_value)
			# Update the visual state of the corresponding checkbox
			if cell_index < _checkboxes.size():
				# Disconnect to prevent _on_checkbox_pressed from firing unnecessarily
				# and then reconnect. This avoids recursive calls or unnecessary signals.
				var checkbox_ref = _checkboxes[cell_index]
				checkbox_ref.toggled.disconnect(Callable(self, "_on_checkbox_pressed").bind(_current_grid_shape, x, y))
				checkbox_ref.button_pressed = check_value
				checkbox_ref.toggled.connect(Callable(self, "_on_checkbox_pressed").bind(_current_grid_shape, x, y))
			cell_index += 1

	# Notify the editor that the properties changed so it refreshes its view if needed
	_current_grid_shape.notify_property_list_changed()
