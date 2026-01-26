extends Control
signal options_requested
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _on_resume_button_pressed() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()

func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Kills the pause menu overlay
	queue_free()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_options_button_pressed() -> void:
	emit_signal("options_requested")
