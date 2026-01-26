extends Control

@export var options_menu_scene: PackedScene = preload("res://scenes/options_menu.tscn")
var options_menu: Control

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_options_button_pressed() -> void:
	if options_menu != null:
		return

	options_menu = options_menu_scene.instantiate() as Control
	add_child(options_menu)
	options_menu.process_mode = Node.PROCESS_MODE_INHERIT


	if options_menu.has_signal("back_requested"):
		options_menu.back_requested.connect(_on_options_back)

func _on_options_back() -> void:
	if options_menu != null:
		options_menu.queue_free()
		options_menu = null

func _on_quit_button_pressed() -> void:
	get_tree().quit()
