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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

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
