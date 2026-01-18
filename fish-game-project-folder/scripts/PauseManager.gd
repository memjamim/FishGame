extends Node

@export var pause_menu_scene: PackedScene

var pause_menu: CanvasItem

func _ready() -> void:
	pause_menu_scene = preload("res://scenes/pause_menu.tscn")
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	var pausing := !get_tree().paused
	get_tree().paused = pausing

	if pausing:
		show_pause_menu()
	else:
		hide_pause_menu()

func show_pause_menu() -> void:
	if pause_menu == null:
		pause_menu = pause_menu_scene.instantiate()
		# Added to root so it's on top of everything
		get_tree().root.add_child(pause_menu)
		pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	pause_menu.get_node("VBoxContainer/ResumeButton").grab_focus()

func hide_pause_menu() -> void:
	if pause_menu != null:
		pause_menu.queue_free()
		pause_menu = null
