extends Node

const SAVE_PATH := "user://settings.cfg"

# Defaults
var master_volume_db: float = 0.0 # default volume
var fov: float = 85.0
var mouse_sensitivity: float = 0.002
var fullscreen: bool = true
var vsync: bool = true

signal changed

func _ready() -> void:
	load_settings()
	get_tree().scene_changed.connect(_on_scene_changed)
	apply_all()

func _on_scene_changed() -> void:
	call_deferred("_apply_scene_dependent_video")

func _apply_scene_dependent_video() -> void:
	apply_graphics_preset(graphics_preset)


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
	apply_graphics_preset(graphics_preset)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume_db", master_volume_db)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("gameplay", "fov", fov)
	cfg.set_value("gameplay", "mouse_sensitivity", mouse_sensitivity)
	cfg.save(SAVE_PATH)
	cfg.set_value("video", "graphics_preset", graphics_preset)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return

	master_volume_db = float(cfg.get_value("audio", "master_volume_db", master_volume_db))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	vsync = bool(cfg.get_value("video", "vsync", vsync))
	fov = float(cfg.get_value("gameplay", "fov", fov))
	mouse_sensitivity = float(cfg.get_value("gameplay", "mouse_sensitivity", mouse_sensitivity))
	graphics_preset = int(cfg.get_value("video", "graphics_preset", graphics_preset))

# Graphics Settings

enum GraphicsPreset { LOW, MEDIUM, HIGH }

var graphics_preset: int = GraphicsPreset.HIGH

func _get_world_environment() -> WorldEnvironment:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("WorldEnvironment", true, false) as WorldEnvironment

func _get_environment() -> Environment:
	var we := _get_world_environment()
	if we and we.environment:
		return we.environment
	return null

func apply_graphics_preset(preset: int) -> void:
	var vp := get_tree().root  # root Viewport

	# Resolution scaling
	# Runtime adjustable
	match preset:
		GraphicsPreset.LOW:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
			vp.scaling_3d_scale = 0.67
		GraphicsPreset.MEDIUM:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
			vp.scaling_3d_scale = 0.85
		GraphicsPreset.HIGH:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
			vp.scaling_3d_scale = 1.0

	# Environment toggles: GI + screen-space effects
	var env := _get_environment()
	if env:
		if preset == GraphicsPreset.LOW:
			env.sdfgi_enabled = false
			env.ssao_enabled = false
			env.ssil_enabled = false
			env.ssr_enabled = false
			env.volumetric_fog_enabled = false
			env.glow_enabled = false
		elif preset == GraphicsPreset.MEDIUM:
			env.sdfgi_enabled = false
			env.ssao_enabled = true
			env.ssil_enabled = false
			env.ssr_enabled = false
			env.volumetric_fog_enabled = false
			env.glow_enabled = true
		else: # HIGH
			env.sdfgi_enabled = true
			# env.sdfgi_cascades = 4
			env.ssao_enabled = true
			env.ssil_enabled = true
			env.ssr_enabled = true
			env.volumetric_fog_enabled = true
			env.glow_enabled = true

	# Shadows: per-light distance + selectively disabling omni shadows
	_apply_shadow_preset(preset)

	emit_signal("changed")

func _apply_shadow_preset(preset: int) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	# put important shadow-casting omni/spot lights in a group in the editor,
	# Gcritical_shadow_lights,
	# Then low/medium can disable shadows on everything else.
	var critical := {}
	for n in get_tree().get_nodes_in_group("critical_shadow_lights"):
		critical[n] = true

	for n in scene.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l == null:
			continue

		if preset == GraphicsPreset.LOW:
			# Cut shadow distance hard (this property is meant for performance).
			l.distance_fade_shadow = 20.0

			# Disable shadows on non-critical omni/spot lights.
			# (distance_fade_shadow only matters when shadow_enabled is true).
			if not critical.has(l) and (l is OmniLight3D or l is SpotLight3D):
				l.shadow_enabled = false
		elif preset == GraphicsPreset.MEDIUM:
			l.distance_fade_shadow = 40.0
			if not critical.has(l) and (l is OmniLight3D or l is SpotLight3D):
				l.shadow_enabled = true  # or keep false if still too heavy
		else:
			l.distance_fade_shadow = 80.0
			if l is OmniLight3D or l is SpotLight3D:
				l.shadow_enabled = true

	# Directional sun shadow distance control.
	for n in scene.find_children("*", "DirectionalLight3D", true, false):
		var d := n as DirectionalLight3D
		if d == null:
			continue
		match preset:
			GraphicsPreset.LOW:    d.directional_shadow_max_distance = 60.0
			GraphicsPreset.MEDIUM: d.directional_shadow_max_distance = 100.0
			GraphicsPreset.HIGH:   d.directional_shadow_max_distance = 160.0
	# Hides VoxelGI nodes, if any are found
	for n in scene.find_children("*", "VoxelGI", true, false):
		var v := n as VoxelGI
		if v == null:
			continue
		v.visible = (preset == GraphicsPreset.HIGH)
