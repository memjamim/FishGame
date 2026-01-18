extends CanvasLayer

@onready var panel: Control = $Panel
@onready var label: Label = $Panel/Label
@onready var player := get_node("/root/Ben/Player")

@export var underwater_tint_color: Color = Color(0.1, 0.35, 0.85, 0.25)
@export var tint_fade_speed := 6.0 

var _tint: ColorRect
var _tint_alpha := 0.0
var _tint_target_alpha := 0.0

func _ready() -> void:
	# Screen tint overlay (behind UI text/panel)
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

	player.breath_updated.connect(set_breath)
	player.water_state_changed.connect(_on_water_state_changed)

	set_breath(player.breath, player.breath_max)
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
	label.text = "Breath: %d:%02d" % [secs / 60, secs % 60]

	# currently breath time is always visible, change later if we want 
	# it to be off while player is above water
	panel.visible = true # player.IS_IN_WATER or secs < int(max_value)
