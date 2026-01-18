extends CanvasLayer

@onready var label: Label = $Panel/Label
@onready var player := get_node("/root/Ben/Player")

func _ready() -> void:
	player.breath_updated.connect(set_breath)
	set_breath(player.breath, player.breath_max)

func set_breath(current: float, max_value: float) -> void:
	var secs := int(ceil(clamp(current, 0.0, max_value)))
	label.text = "Breath: %d:%02d" % [secs / 60, secs % 60]
	visible = true# = player.IS_IN_WATER or secs < int(max_value)
