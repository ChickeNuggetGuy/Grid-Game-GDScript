extends Node
class_name GridObjectAnimation

@export var animation_player_holder : Node
@export var animation_tree : AnimationTree

@export var locomotion_State_playback_path : String
@export var animation_state_names : Array[String]
@export var parent_grid_object : GridObject

func _ready() -> void:
	parent_grid_object = get_parent()
	animation_tree = animation_player_holder.find_child("AnimationTree")
	#animation_tree.advance_expression_base_node = parent_grid_object.get_path()
	UnitActionManager.connect("action_execution_finished",UnitActionManager_action_execution_finished)


func UnitActionManager_action_execution_finished(_completed_action_definition : BaseActionDefinition):
	return #var playback = animation_tree.get(locomotion_State_playback_path) as AnimationNodeStateMachinePlayback

func locomotion_change_stance(target_state : Enums.UnitStance):
	return
	#var playback = animation_tree.get(locomotion_State_playback_path) as AnimationNodeStateMachinePlayback
	#playback.travel("Idle")
	#
	#match (target_state):
		#Enums.UnitStance.NORMAL:
			#animation_tree.set("parameters/Locomotion/Idle/blend_position",1) 
		#Enums.UnitStance.CROUCHED:
			#animation_tree.set("parameters/Locomotion/Idle/blend_position",0) 

func start_locomotion_animation(target_stance : Enums.UnitStance, blend_position : Vector2):
	return#var playback = animation_tree.get(locomotion_State_playback_path) as AnimationNodeStateMachinePlayback
	#
	#if target_stance & Enums.UnitStance.NORMAL:
		#playback.travel("Normal")
		#animation_tree.set("parameters/Locomotion/Normal/blend_position", blend_position)
	#else: if target_stance & Enums.UnitStance.CROUCHED:
		#animation_tree.set("parameters/Locomotion/Crouched/blend_position", blend_position)
		#playback.travel("Crouched")
