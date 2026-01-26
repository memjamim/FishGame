extends Node

@onready var player: CharacterBody3D = $".."
@onready var main_hand: Node3D = $"../CameraPivot/Camera3D/HoldPoint"
@onready var off_hand: Node3D = $"../CameraPivot/Camera3D/Offhand"


# --- Throw ---
@export var min_throw_strength: float = 0
@export var max_throw_strength: float = 10
@export var throw_charge_time: float = 1.5

var IS_CHARGING_THROW: bool = false
var throw_charge: float = 0



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


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

	print("picked up:", holdable.name, " scene=", holdable.scene_file_path)



func _charge_throw(delta: float) -> void:
	self.throw_charge += delta
	self.throw_charge = min(throw_charge, throw_charge_time)


func _throw(holdable: RigidBody3D) -> void:
	if !is_instance_valid(holdable):
		return

	var p := holdable.get_parent()
	if p != null:
		p.remove_child(holdable)

	var world: Node = get_tree().current_scene
	if world == null:
		world = get_tree().root # fallback

	world.add_child(holdable)

	var camera_pivot: Node3D = player.get_node("CameraPivot")
	var forward: Vector3 = -camera_pivot.global_transform.basis.z
	var drop_dist := 2.0
	holdable.global_position = player.global_position + forward * drop_dist

	var cs := holdable.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs:
		cs.disabled = false

	holdable.freeze = false

	var charge_strength = self.throw_charge / self.throw_charge_time
	var throw_force = lerp(self.min_throw_strength, self.max_throw_strength, charge_strength)

	holdable.apply_impulse(forward * throw_force)

	self.throw_charge = 0

	if holdable.is_in_group("weapon"):
		var hitbox := holdable.find_child("Hitbox", true, false)
		if hitbox and hitbox is Area3D:
			hitbox.monitoring = true
