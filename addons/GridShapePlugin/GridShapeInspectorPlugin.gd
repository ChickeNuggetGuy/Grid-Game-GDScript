# GridShapeInspectorPlugin.gd
@tool
extends EditorInspectorPlugin

# We now directly edit the 'shape_grid' property of the GridShape.
# We no longer need to store _current_grid_shape_being_edited here globally for the UI
# as the UI is tied to the 'shape_grid' property which is given to _create_checkbox_grid.
var _checkboxes: Array[CheckBox] = []
var _custom_grid_control: Control = null # Reference to the currently displayed custom control

func _can_handle(object: Object) -> bool:
	# The plugin still 'can handle' a GridShape resource.
	# But its _parse_property will only act on specific properties *within* it.
	return object is GridShape

func _parse_property(object: Object, type: int, name: String, hint_type: int, hint_string: String, usage_flags: int, wide: bool) -> bool:
	# We want this plugin to specifically handle the 'shape_grid' property of a GridShape.
	# Godot will draw 'grid_width' and 'grid_height' by default.
	if object is GridShape and name == "shape_grid":
		var current_shape: GridShape = object # The object is the GridShape itself

		# Check for invalid dimensions of the GridShape before trying to draw the custom editor
		if current_shape.grid_width <= 0 or current_shape.grid_height <= 0:
			push_warning("GridShapeInspectorPlugin: GridShape '%s' has invalid dimensions (%d,%d). Cannot display custom editor for shape_grid." % [current_shape.resource_path, current_shape.grid_width, current_shape.grid_height])
			return false # Don't handle this property if dimensions are invalid

		# We need to decide if we reuse the existing control or create a new one.
		# A simple check: if the control exists AND its current dimensions match the shape's, reuse.
		# Otherwise, recreate. This helps with dynamic resizing.
		var needs_rebuild = false
		if _custom_grid_control != null and is_instance_valid(_custom_grid_control):
			if _custom_grid_control.get_meta("_grid_shape_width", 0) != current_shape.grid_width or \
			   _custom_grid_control.get_meta("_grid_shape_height", 0) != current_shape.grid_height:
				needs_rebuild = true # Dimensions changed, must rebuild
		else:
			needs_rebuild = true # No control exists, need to build

		if needs_rebuild:
			# If there's an old control, remove and free it before creating a new one.
			if _custom_grid_control != null and is_instance_valid(_custom_grid_control):
				_custom_grid_control.queue_free()
			_custom_grid_control = null # Clear reference

			_custom_grid_control = _create_checkbox_grid_with_buttons(current_shape)
			
			# Store dimensions as meta-data on the control for later checks
			_custom_grid_control.set_meta("_grid_shape_width", current_shape.grid_width)
			_custom_grid_control.set_meta("_grid_shape_height", current_shape.grid_height)
			
			# Add the custom control to the inspector for the "shape_grid" property
			add_custom_control(_custom_grid_control)
		
		# Always ensure display is updated after potential rebuild or on refresh
		call_deferred("_update_checkbox_display", current_shape) # Pass current_shape to update
		return true # We handled the 'shape_grid' property

	return false # We did not handle this property (e.g., it's grid_width, grid_height, or a different object)

func _create_checkbox_grid_with_buttons(shape_to_edit: GridShape) -> Control:
	_checkboxes.clear()

	var vbox = VBoxContainer.new()
	vbox.set_name("GridShapeCustomEditor") # Set a name for easier identification if needed

	var h_buttons = HBoxContainer.new()
	h_buttons.add_theme_constant_override("separation", 10)

	var check_all_button = Button.new()
	check_all_button.text = "Check All"
	check_all_button.pressed.connect(Callable(self, "_on_check_all_button_pressed").bind(shape_to_edit, true))
	h_buttons.add_child(check_all_button)

	var uncheck_all_button = Button.new()
	uncheck_all_button.text = "Uncheck All"
	uncheck_all_button.pressed.connect(Callable(self, "_on_check_all_button_pressed").bind(shape_to_edit, false))
	h_buttons.add_child(uncheck_all_button)

	vbox.add_child(h_buttons)

	var grid_container = GridContainer.new()
	grid_container.columns = shape_to_edit.grid_width
	vbox.add_child(grid_container)

	for y in range(shape_to_edit.grid_height):
		for x in range(shape_to_edit.grid_width):
			var check_box = CheckBox.new()
			check_box.text = "(%s,%s)" % [x, y]
			check_box.button_pressed = shape_to_edit.get_grid_shape_cell(x, y)
			check_box.toggled.connect(Callable(self, "_on_checkbox_pressed").bind(shape_to_edit, x, y))

			grid_container.add_child(check_box)
			_checkboxes.append(check_box)

	return vbox

func _on_checkbox_pressed(new_state: bool, shape: GridShape, x: int, y: int) -> void:
	if shape == null:
		push_error("GridShapeInspectorPlugin: _on_checkbox_pressed: Shape is null.")
		return
	shape.set_grid_shape_cell(x, y, new_state)
	shape.notify_property_list_changed()

func _on_check_all_button_pressed(shape: GridShape, check_value: bool) -> void:
	if shape == null:
		push_error("GridShapeInspectorPlugin: _on_check_all_button_pressed: Shape is null.")
		return

	for y in range(shape.grid_height):
		for x in range(shape.grid_width):
			shape.set_grid_shape_cell(x, y, check_value)

	shape.notify_property_list_changed()

# Updated _update_checkbox_display to take the current shape directly
func _update_checkbox_display(shape: GridShape):
	if shape != null and _custom_grid_control != null and is_instance_valid(_custom_grid_control):
		# Ensure the number of checkboxes matches the current shape dimensions
		var expected_total_checkboxes = shape.grid_width * shape.grid_height
		if _checkboxes.size() != expected_total_checkboxes:
			# If dimensions changed and checkboxes are out of sync, trigger a full re-parse
			# by notifying the property list changed (on the GridShape).
			# This will cause _parse_property to be called again and rebuild the UI.
			shape.notify_property_list_changed() 
			return # Exit as we're expecting a rebuild

		# If dimensions match, just update the existing checkboxes
		for y in range(shape.grid_height):
			for x in range(shape.grid_width):
				var index = y * shape.grid_width + x
				if index < _checkboxes.size():
					var check_box = _checkboxes[index]
					check_box.button_pressed = shape.get_grid_shape_cell(x, y)
	else:
		push_warning("GridShapeInspectorPlugin: Cannot update checkbox display. No valid GridShape or custom control.")

# Godot calls this when the plugin is removed or inspector changes target
func _exit_tree():
	if _custom_grid_control != null and is_instance_valid(_custom_grid_control):
		_custom_grid_control.queue_free()
	_custom_grid_control = null
	_checkboxes.clear()
