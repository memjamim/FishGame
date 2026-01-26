extends Node3D

@export var armature_path: NodePath = NodePath("doorAnimated/Armature_009")
@export var open_angle_deg: float = 120.0
@export var open_time: float = 1.5

@onready var armature: Node3D = get_node(armature_path) as Node3D

var _is_open := false
var _closed_y := 0.0

func _ready() -> void:
	_closed_y = armature.rotation.y

func open_door() -> void:
	if _is_open:
		return
	_is_open = true

	var target_y := _closed_y + deg_to_rad(open_angle_deg)

	var tw := create_tween()
	tw.tween_property(armature, "rotation:y", target_y, open_time) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
