extends CanvasLayer

@export var panel_path: NodePath
@export var breath_label_path: NodePath
@export var coin_label_path: NodePath

@onready var player := get_node("/root/Ben/Player")

@export var underwater_tint_color: Color = Color(0.1, 0.35, 0.85, 0.25)
@export var tint_fade_speed := 6.0

var panel: Control
var breath_label: Label
var coin_label: Label

var _tint: ColorRect
var _tint_alpha := 0.0
var _tint_target_alpha := 0.0

func _ready() -> void:
	panel = get_node_or_null(panel_path) as Control
	breath_label = get_node_or_null(breath_label_path) as Label
	coin_label = get_node_or_null(coin_label_path) as Label

	if panel == null or breath_label == null or coin_label == null:
		push_error("PlayerUI: One or more UI node paths are not set or invalid. Assign panel_path, breath_label_path, coin_label_path in the Inspector.")
		return

	# Tint overlay
	_tint = ColorRect.new()
	_tint.name = "UnderwaterTint"
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.offset_left = 0
	_tint.offset_top = 0
	_tint.offset_right = 0
	_tint.offset_bottom = 0
	_tint.z_index = -100
	add_child(_tint)

	# signals
	player.breath_updated.connect(set_breath)
	player.water_state_changed.connect(_on_water_state_changed)
	player.collectables_changed.connect(_on_collectables_changed)

	# initialize
	set_breath(player.breath, player.breath_max)
	_on_collectables_changed(player.collectables)
	_on_water_state_changed(player.IS_IN_WATER)

func _process(delta: float) -> void:
	_tint_alpha = move_toward(_tint_alpha, _tint_target_alpha, tint_fade_speed * delta)
	var c := underwater_tint_color
	c.a = _tint_alpha
	_tint.color = c

func _on_water_state_changed(in_water: bool) -> void:
	_tint_target_alpha = underwater_tint_color.a if in_water else 0.0

func set_breath(current: float, max_value: float) -> void:
	var secs := int(ceil(clamp(current, 0.0, max_value)))
	var mins := int(secs / 60)
	breath_label.text = "Breath: %d:%02d" % [mins, secs % 60]
	panel.visible = true

func _on_collectables_changed(count: int) -> void:
	coin_label.text = "Coins: %d" % count
