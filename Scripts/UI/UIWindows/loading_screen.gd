class_name LoadingScreen
extends UIWindow

@export var loading_text : Label
@export var progress_bar : ProgressBar


func _ready() -> void:
	if progress_bar:
		progress_bar.value = 0.0

func update_progress(value: float, text : String) -> void:
	if progress_bar:
		progress_bar.value = value * 100
	
	loading_text.text = text
