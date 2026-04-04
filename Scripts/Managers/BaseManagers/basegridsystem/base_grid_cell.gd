extends Node3D
class_name BaseGridCell

var mesh_instance : MeshInstance3D


func _init(mesh : Mesh) -> void:
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)
	
	mesh_instance.mesh = mesh
