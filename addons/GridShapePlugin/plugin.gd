# plugin.gd
@tool
extends EditorPlugin

var grid_shape_inspector_plugin: EditorInspectorPlugin

func _enter_tree():
	# Initialization of the plugin goes here.
	grid_shape_inspector_plugin = preload("res://addons/GridShapePlugin/GridShapeInspectorPlugin.gd").new()
	add_inspector_plugin(grid_shape_inspector_plugin)
	print("GridShape Inspector Plugin Enabled.")

func _exit_tree():
	# Clean-up of the plugin goes here.
	remove_inspector_plugin(grid_shape_inspector_plugin)
	grid_shape_inspector_plugin = null
	print("GridShape Inspector Plugin Disabled.")
