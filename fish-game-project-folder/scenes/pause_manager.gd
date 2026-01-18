extends Node

@export var pause_menu_scene: PackedScene = preload("res://scenes/pause_menu.tscn")

var pause_menu: CanvasItem
var _mouse_mode_before_pause: int = Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	# So Esc works even while the tree is paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	var pausing := !get_tree().paused
	get_tree().paused = pausing

	if pausing:
		_enter_pause()
	else:
		_exit_pause()

func _enter_pause() -> void:
	# Remembers the current mouse mode so it can restore it properly
	_mouse_mode_before_pause = Input.get_mouse_mode()

	# Make cursor visible and free
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

	show_pause_menu()

func _exit_pause() -> void:
	hide_pause_menu()

	# Restore whatever the mode was before pausing
	call_deferred("_restore_mouse_mode")

func _restore_mouse_mode() -> void:
	Input.set_mouse_mode(_mouse_mode_before_pause)

func show_pause_menu() -> void:
	if pause_menu == null:
		pause_menu = pause_menu_scene.instantiate()
		get_tree().root.add_child(pause_menu)
		pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	var resume_btn := pause_menu.get_node_or_null("VBoxContainer/ResumeButton")
	if resume_btn:
		resume_btn.grab_focus()

func hide_pause_menu() -> void:
	if pause_menu != null:
		pause_menu.queue_free()
		pause_menu = null
