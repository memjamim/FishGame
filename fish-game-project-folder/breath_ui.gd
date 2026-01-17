extends CanvasLayer
@export var player_path: NodePath
@onready var label: Label = $MarginContainer/Label
# TODO: display in top corner
func _ready() -> void:
	var player := get_node_or_null(player_path)
	if player:
		player.breath_updated.connect(set_breath)

func set_breath(current: float, max_value: float) -> void:
	current = clamp(current, 0.0, max_value)

	visible = current < max_value

	var secs := int(ceil(current))
	var m := secs / 60
	var s := secs % 60
	label.text = "Breath: %d:%02d" % [m, s]
