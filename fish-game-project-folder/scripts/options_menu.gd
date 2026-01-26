extends Control
signal back_requested

@onready var vol_slider: HSlider = $Panel/VBoxContainer/VolumeSlider
@onready var vol_value: Label = $Panel/VBoxContainer/VolumeValueLabel

@onready var fov_slider: HSlider = $Panel/VBoxContainer/FovSlider
@onready var fov_value: Label = $Panel/VBoxContainer/FovValueLabel

@onready var fullscreen_check: CheckBox = $Panel/VBoxContainer/FullscreenCheck
@onready var vsync_check: CheckBox = $Panel/VBoxContainer/VsyncCheck

@onready var sens_slider: HSlider = $Panel/VBoxContainer/SensitivitySlider
@onready var sens_value: Label = $Panel/VBoxContainer/SensitivityValueLabel

@onready var controls_list: VBoxContainer = $Panel/VBoxContainer2

# Actions in your project (based on your player code + described controls)
const REMAPPABLE_ACTIONS := [
	{ "action": &"foward",           "label": "Move Foward" }, 
	{ "action": &"back",             "label": "Move Back" },
	{ "action": &"left",             "label": "Move Left" },
	{ "action": &"right",            "label": "Move Right" },

	{ "action": &"jump",             "label": "Up / Jump" },     # space (water up + land jump)
	{ "action": &"down",             "label": "Down" },          # shift (water down)

	{ "action": &"interact",         "label": "Interact" },      # E
	{ "action": &"throw",            "label": "Throw / Drop" },  # Q
	{ "action": &"attack",           "label": "Attack" },        # LMB

	{ "action": &"sprint",           "label": "Underwater Sprint" }, # Ctrl
	{ "action": &"toggle_flashlight","label": "Toggle Flashlight" },   # F
]

var _action_to_button: Dictionary = {} # StringName -> Button
var _waiting_action: StringName = &""
var _waiting_button: Button = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_process_unhandled_input(true)

	# Connect signals
	vol_slider.value_changed.connect(_on_volume_slider_value_changed)
	fov_slider.value_changed.connect(_on_fov_slider_value_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_check_toggled)
	vsync_check.toggled.connect(_on_vsync_check_toggled)
	sens_slider.value_changed.connect(_on_sens_slider_value_changed)

	var back_btn := $Panel/VBoxContainer/BackButton as Button
	back_btn.pressed.connect(_on_back_button_pressed)

	# Load settings into UI
	vol_slider.value = Settings.master_volume_db
	fov_slider.value = Settings.fov
	fullscreen_check.button_pressed = Settings.fullscreen
	vsync_check.button_pressed = Settings.vsync
	sens_slider.value = Settings.mouse_sensitivity

	# Load previously saved bindings (if you add Settings.apply_keybinds below)
	if Settings.has_method("apply_keybinds"):
		Settings.apply_keybinds()

	_build_controls_ui()
	_refresh_controls_ui()

func _build_controls_ui() -> void:
	if controls_list == null:
		push_warning("OptionsMenu: ControlsList not found. Add ControlsScroll/ControlsList.")
		return

	for c in controls_list.get_children():
		c.queue_free()

	_action_to_button.clear()

	for row in REMAPPABLE_ACTIONS:
		var action: StringName = row["action"]
		var label_text: String = row["label"]

		var h := HBoxContainer.new()
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lbl := Label.new()
		lbl.text = label_text
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true

		var btn := Button.new()
		btn.text = _get_action_binding_text(action)
		btn.pressed.connect(func(): _begin_rebind(action, btn))

		h.add_child(lbl)
		h.add_child(btn)
		controls_list.add_child(h)

		_action_to_button[action] = btn

func _refresh_controls_ui() -> void:
	for row in REMAPPABLE_ACTIONS:
		var action: StringName = row["action"]
		var btn: Button = _action_to_button.get(action, null)
		if btn:
			btn.text = _get_action_binding_text(action)

func _begin_rebind(action: StringName, btn: Button) -> void:
	_waiting_action = action
	_waiting_button = btn
	btn.text = "Press a key..."

func _unhandled_input(event: InputEvent) -> void:
	if _waiting_action == &"":
		return

	# Ignore mouse motion, etc.
	if event is InputEventMouseMotion:
		return

	# KEY
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return

		# Don't allow Escape to be bound (keeps pause/back sane)
		var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
		if code == KEY_ESCAPE:
			_cancel_rebind()
			return

		_set_action_single_event(_waiting_action, k)
		_finish_rebind()
		return

	# MOUSE BUTTON
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		_set_action_single_event(_waiting_action, mb)
		_finish_rebind()
		return

	# JOYPAD BUTTONS
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if not jb.pressed:
			return
		_set_action_single_event(_waiting_action, jb)
		_finish_rebind()
		return

func _cancel_rebind() -> void:
	if _waiting_button:
		_waiting_button.text = _get_action_binding_text(_waiting_action)
	_waiting_action = &""
	_waiting_button = null

func _finish_rebind() -> void:
	_waiting_action = &""
	_waiting_button = null
	_refresh_controls_ui()

	# Save the bindings
	if Settings.has_method("save_keybinds"):
		Settings.save_keybinds()

func _set_action_single_event(action: StringName, ev: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)

func _get_action_binding_text(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "Unbound"

	var ev := events[0]

	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
		return OS.get_keycode_string(code)

	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		return "Mouse%d" % mb.button_index

	if ev is InputEventJoypadButton:
		var jb := ev as InputEventJoypadButton
		return "Pad%d" % jb.button_index

	return "Bound"

# ---- settings callbacks ----

func _on_volume_slider_value_changed(value: float) -> void:
	Settings.master_volume_db = value
	Settings.apply_audio()
	Settings.save_settings()

func _on_fov_slider_value_changed(value: float) -> void:
	Settings.fov = value
	Settings.emit_signal("changed")
	Settings.save_settings()

func _on_fullscreen_check_toggled(toggled_on: bool) -> void:
	Settings.fullscreen = toggled_on
	Settings.apply_video()
	Settings.save_settings()

func _on_vsync_check_toggled(toggled_on: bool) -> void:
	Settings.vsync = toggled_on
	Settings.apply_video()
	Settings.save_settings()

func _on_sens_slider_value_changed(value: float) -> void:
	Settings.mouse_sensitivity = value
	Settings.emit_signal("changed")
	Settings.save_settings()

func _on_back_button_pressed() -> void:
	emit_signal("back_requested")
