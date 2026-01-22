extends Node

const SAVE_PATH := "user://settings.cfg"

# Defaults
var master_volume_db: float = 0.0          # 0 dB = normal
var fov: float = 85.0
var mouse_sensitivity: float = 0.002
var fullscreen: bool = true
var vsync: bool = true

signal changed

func _ready() -> void:
	load_settings()
	apply_all()

func apply_all() -> void:
	apply_audio()
	apply_video()
	emit_signal("changed")

func apply_audio() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), master_volume_db)

func apply_video() -> void:
	# Fullscreen/windowed
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	if fullscreen:
		mode = DisplayServer.WINDOW_MODE_FULLSCREEN

	DisplayServer.window_set_mode(mode)

	# VSync
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume_db", master_volume_db)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("gameplay", "fov", fov)
	cfg.set_value("gameplay", "mouse_sensitivity", mouse_sensitivity)
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return

	master_volume_db = float(cfg.get_value("audio", "master_volume_db", master_volume_db))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	vsync = bool(cfg.get_value("video", "vsync", vsync))
	fov = float(cfg.get_value("gameplay", "fov", fov))
	mouse_sensitivity = float(cfg.get_value("gameplay", "mouse_sensitivity", mouse_sensitivity))
