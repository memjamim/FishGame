extends Node3D

@onready var anim_tree: AnimationTree = $AnimationTree

func _ready():
	anim_tree.active = true

	anim_tree["parameters/Blend1/blend_amount"] = 0.2
