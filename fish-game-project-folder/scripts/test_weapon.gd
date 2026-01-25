extends RigidBody3D
class_name Weapon

@export var damage: int = 20

@onready var hitbox: Area3D = $Hitbox
@onready var shader = $MeshInstance3D.mesh.material.next_pass

var targeted := false : set = _set_targeted

signal enemy_hit(body_hit: Node3D, damage: int)

func _set_targeted(val: bool) -> void:
	targeted = val
	if shader:
		shader.set_shader_parameter("strength", 0.5 if targeted else 0.0)

func _on_hitbox_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy"):
		enemy_hit.emit(body, damage)
		# prevent multi-hit spam in one swing
		hitbox.set_deferred("monitoring", false)

func reset_for_swing() -> void:
	# call this right when the attack starts
	hitbox.monitoring = true
