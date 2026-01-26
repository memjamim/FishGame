extends Node

@onready var player: CharacterBody3D = $".."
@onready var main_hand: Node3D = $"../CameraPivot/Camera3D/HoldPoint"
@onready var off_hand: Node3D = $"../CameraPivot/Camera3D/Offhand"

@export var min_throw_strength: float = 0.0
@export var max_throw_strength: float = 10.0
@export var throw_charge_time: float = 1.5

# Spawn / safety
@export var drop_dist := 1.0
@export var drop_up := 0.25
@export var ignore_player_time := 0.20

var throw_charge_sec: float = 0.0
var throw_charge_norm: float = 0.0  # 0..1 (eased)

func _pick_up(holdable: RigidBody3D) -> void:
	var p := holdable.get_parent()
	if p != null:
		p.remove_child(holdable)

	if holdable.is_in_group("weapon"):
		main_hand.add_child(holdable)
	else:
		off_hand.add_child(holdable)

	var cs := holdable.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs:
		cs.disabled = true

	holdable.freeze = true
	holdable.linear_velocity = Vector3.ZERO
	holdable.angular_velocity = Vector3.ZERO
	holdable.transform = Transform3D.IDENTITY

func _charge_throw(delta: float) -> void:
	throw_charge_sec = minf(throw_charge_sec + delta, throw_charge_time)
	throw_charge_norm = ease(throw_charge_sec / throw_charge_time, 0.5)

# Soft drop (no impulse) – perfect for death
func drop(holdable: RigidBody3D) -> void:
	_release_to_world(holdable, Vector3.ZERO)

func _throw(holdable: RigidBody3D) -> void:
	var force := lerpf(min_throw_strength, max_throw_strength, throw_charge_norm)

	var camera_pivot: Node3D = player.get_node("CameraPivot")
	var forward: Vector3 = -camera_pivot.global_transform.basis.z

	_release_to_world(holdable, forward * force)

	# reset charge
	throw_charge_sec = 0.0
	throw_charge_norm = 0.0

func _release_to_world(holdable: RigidBody3D, impulse: Vector3) -> void:
	if !is_instance_valid(holdable):
		return

	# Detach from hand
	var p := holdable.get_parent()
	if p != null:
		p.remove_child(holdable)

	var world: Node = get_tree().current_scene
	if world == null:
		world = get_tree().root
	world.add_child(holdable)

	# Forward from camera, spawn safely away from player + a bit up
	var camera_pivot: Node3D = player.get_node("CameraPivot")
	var forward: Vector3 = -camera_pivot.global_transform.basis.z
	holdable.global_position = player.global_position + forward * drop_dist + Vector3.UP * drop_up

	# Ignore player briefly to prevent instant collision slingshot
	if holdable is CollisionObject3D and player is CollisionObject3D:
		(holdable as CollisionObject3D).add_collision_exception_with(player)

	# Re-enable physics
	holdable.freeze = false
	holdable.sleeping = false

	# Re-enable collision after a physics frame (prevents overlap explosion)
	var cs := holdable.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs:
		cs.disabled = true
		await get_tree().physics_frame
		if is_instance_valid(cs):
			cs.disabled = false

	# Apply impulse (if any)
	if impulse.length_squared() > 0.0:
		holdable.apply_impulse(impulse)

	# Restore weapon hitbox if needed
	if holdable.is_in_group("weapon"):
		var hitbox := holdable.find_child("Hitbox", true, false)
		if hitbox and hitbox is Area3D:
			(hitbox as Area3D).monitoring = true

	# Remove collision exception after a short delay
	if holdable is CollisionObject3D and player is CollisionObject3D:
		await get_tree().create_timer(ignore_player_time).timeout
		if is_instance_valid(holdable) and is_instance_valid(player):
			(holdable as CollisionObject3D).remove_collision_exception_with(player)
