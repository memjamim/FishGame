extends RigidBody3D

@onready var hitbox: Area3D = $Hitbox
@onready var shader = $MeshInstance3D.mesh.material.next_pass

var targeted = false : set = _set_targeted

signal enemy_hit(body_hit)

## Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#pass # Replace with function body.
#
#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass

func _set_targeted(val):
	targeted = val
	if targeted:
		shader.set_shader_parameter('strength', 0.5)
	else:
		shader.set_shader_parameter('strength', 0.0)


func _on_hitbox_body_entered(body: Node3D) -> void:
	if body.is_in_group('enemy'):
		enemy_hit.emit(body)
		#hitbox.monitoring = false
