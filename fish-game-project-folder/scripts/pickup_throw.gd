extends Node

@onready var player: CharacterBody3D = $".."
@onready var hold_point: Node3D = $"../CameraPivot/Camera3D/HoldPoint"

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
	holdable.get_parent().remove_child(holdable)
	hold_point.add_child(holdable)
	
	holdable.get_node("CollisionShape3D").disabled = true
	holdable.freeze = true
	holdable.linear_velocity = Vector3.ZERO
	holdable.angular_velocity = Vector3.ZERO
	holdable.transform = Transform3D.IDENTITY

	print("picked up:", holdable.name)


func _charge_throw(delta: float) -> void:
	self.throw_charge += delta
	self.throw_charge = min(throw_charge, throw_charge_time)


func _throw(holdable: RigidBody3D) -> void:
	holdable.get_parent().remove_child(holdable)
	var world := player.get_parent_node_3d()
	world.add_child(holdable)

	var camera_pivot: Node3D = player.get_node("CameraPivot")
	var forward: Vector3 = -camera_pivot.global_transform.basis.z
	var drop_dist := 2.0
	holdable.global_position = player.global_position + forward * drop_dist
	holdable.get_node("CollisionShape3D").disabled = false
	holdable.freeze = false
	
	var charge_strength = self.throw_charge/self.throw_charge_time
	var throw_force = lerp(self.min_throw_strength, self.max_throw_strength, charge_strength)
	
	holdable.apply_impulse(
		forward * throw_force
	)
	self.throw_charge = 0
	
	print("throwing:", holdable.name)
