extends RigidBody3D
class_name Weapon

@export var damage: int = 20

# Optional: point this at your mesh if the node isn't named MeshInstance3D
@export var mesh_path: NodePath

@onready var hitbox: Area3D = $Hitbox

var _shader_mat: ShaderMaterial = null

var targeted := false : set = _set_targeted

signal enemy_hit(body_hit: Node3D, damage: int)

func _ready() -> void:

	# Ensure hitbox signal is connected (in case imported scenes lost it)
	if hitbox and not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)

	# Apply initial highlight state
	_apply_target_highlight()

func _extract_shader_material(m: MeshInstance3D) -> ShaderMaterial:
	if m == null:
		return null

	# 1) material_override
	if m.material_override is ShaderMaterial:
		return m.material_override as ShaderMaterial

	# 2) surface material 0
	if m.mesh != null and m.mesh.get_surface_count() > 0:
		var sm := m.mesh.surface_get_material(0)
		if sm is ShaderMaterial:
			return sm as ShaderMaterial
		# 3) next_pass if it's a ShaderMaterial
		if sm != null and sm.next_pass is ShaderMaterial:
			return sm.next_pass as ShaderMaterial

	return null

func _set_targeted(val: bool) -> void:
	targeted = val
	_apply_target_highlight()

func _apply_target_highlight() -> void:
	if _shader_mat:
		_shader_mat.set_shader_parameter("strength", 0.5 if targeted else 0.0)

func _on_hitbox_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy"):
		enemy_hit.emit(body, damage)
		# prevent multi-hit spam in one swing
		if hitbox:
			hitbox.set_deferred("monitoring", false)

func reset_for_swing() -> void:
	if hitbox:
		hitbox.monitoring = true
