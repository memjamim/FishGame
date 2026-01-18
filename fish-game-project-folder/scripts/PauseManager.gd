extends Node

@export var pause_menu_scene: PackedScene = preload("res://scenes/pause_menu.tscn")

var pause_menu: Control
var _mouse_mode_before_pause: int = Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS



func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		toggle_pause()
		print("Toggled Pause")
		get_viewport().set_input_as_handled()



func toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		_exit_pause()
	else:
		_enter_pause()
		get_tree().paused = true

func _enter_pause() -> void:
	_mouse_mode_before_pause = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	show_pause_menu()

func _exit_pause() -> void:
	hide_pause_menu()
	call_deferred("_restore_mouse_mode")

func _restore_mouse_mode() -> void:
	Input.set_mouse_mode(_mouse_mode_before_pause)

func show_pause_menu() -> void:
	if pause_menu == null:
		pause_menu = pause_menu_scene.instantiate() as Control
		get_tree().root.add_child(pause_menu)
		pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	var resume_btn := pause_menu.get_node_or_null("VBoxContainer/ResumeButton")
	if resume_btn:
		resume_btn.grab_focus()

func hide_pause_menu() -> void:
	if pause_menu != null:
		pause_menu.queue_free()
		pause_menu = null
