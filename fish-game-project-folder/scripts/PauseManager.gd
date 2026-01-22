extends Node

@export var pause_menu_scene: PackedScene = preload("res://scenes/pause_menu.tscn")
@export var options_menu_scene: PackedScene = preload("res://scenes/options_menu.tscn")

var pause_menu: Control
var options_menu: Control
var _mouse_mode_before_pause: int = Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		# If options are open, Esc should behave like Back
		if options_menu != null:
			_close_options()
		else:
			toggle_pause()

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
	# Ensure no UI is left on screen when resuming
	_close_options()
	hide_pause_menu()
	call_deferred("_restore_mouse_mode")

func _restore_mouse_mode() -> void:
	Input.set_mouse_mode(_mouse_mode_before_pause)

func show_pause_menu() -> void:
	if pause_menu == null:
		pause_menu = pause_menu_scene.instantiate() as Control
		get_tree().root.add_child(pause_menu)
		pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

		# Connect pause menu signals
		if pause_menu.has_signal("options_requested"):
			pause_menu.options_requested.connect(_open_options)

	var resume_btn := pause_menu.get_node_or_null("VBoxContainer/ResumeButton")
	if resume_btn:
		resume_btn.grab_focus()

func hide_pause_menu() -> void:
	if pause_menu != null:
		pause_menu.queue_free()
		pause_menu = null

func _open_options() -> void:
	if options_menu != null:
		return

	options_menu = options_menu_scene.instantiate() as Control
	get_tree().root.add_child(options_menu)
	options_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# Optional: hide pause menu so only options are visible/interactive
	if pause_menu != null:
		pause_menu.visible = false

	if options_menu.has_signal("back_requested"):
		options_menu.back_requested.connect(_close_options)

func _close_options() -> void:
	if options_menu != null:
		options_menu.queue_free()
		options_menu = null

	if pause_menu != null:
		pause_menu.visible = true
		var resume_btn := pause_menu.get_node_or_null("VBoxContainer/ResumeButton")
		if resume_btn:
			resume_btn.grab_focus()
