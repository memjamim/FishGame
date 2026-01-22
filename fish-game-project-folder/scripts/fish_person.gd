extends CharacterBody3D

@onready var mesh: MeshInstance3D = $Armature_001/Skeleton3D/Plane_052
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var hitbox = $enemy_hitbox

@export var move_speed := 2.5
@export var chase_acceleration := 6.0

@export var vision_range := 15.0          
@export var vision_angle := 60.0        

@export var maxHealth := 100  
var currentHealth := 100

var state_machine

const ATTACK_RANGE = 3.0
const DAMAGE = 20

var player: CharacterBody3D = null
var is_chasing := false

func _ready() -> void:
	currentHealth = maxHealth
	state_machine = anim_tree.get("parameters/playback")

func _physics_process(delta: float) -> void:
	
	match state_machine.get_current_node():
		"idle_swim":
				anim_tree.set("parameters/conditions/run", true)
		"fast_swim":
			print("Player out of range ")
			if not is_chasing or player == null:
				velocity = velocity.move_toward(Vector3.ZERO, chase_acceleration * delta)
				move_and_slide()
				return

			var direction := (player.global_position - global_position).normalized()
			var desired_velocity := direction * move_speed

			velocity = velocity.move_toward(desired_velocity, chase_acceleration * delta)

			if velocity.length() > 0.1:
				look_at(global_position + velocity, Vector3.UP)
				
			anim_tree.set("parameters/conditions/attack", target_in_range())
			
			move_and_slide()
		"attack":
			print("Attack initiated")
			anim_tree.set("parameters/conditions/run", !target_in_range())
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		"death":
			pass

#$CharacterBody3D/VisionRaycast.look_at(playerPosition, Vector3.UP)
func target_in_range():
	return global_position.distance_to(player.global_position) < ATTACK_RANGE

func _on_vision_timer_timeout() -> void:
	var overlaps = $VisionArea.get_overlapping_bodies()
	
	if overlaps.size() > 0:
		for overlap in overlaps:
			if overlap.name == "Player":
				
				var playerPosition = overlap.global_position
				$VisionRaycast.look_at(Vector3(overlap.global_position.x, global_position.y, overlap.global_position.z), Vector3.UP)
				$VisionRaycast.force_raycast_update()
				
				if $VisionRaycast.is_colliding():
					var collider = $VisionRaycast.get_collider()
					
					if collider.name == "Player":
						$VisionRaycast.debug_shape_custom_color = Color(255,0,0)
						is_chasing = true;
						player = overlap
						print("Spotted")
					else:
						$VisionRaycast.debug_shape_custom_color = Color(0,255,0)
						is_chasing = false;
						player = null
						print("Blocked")
						
func apply_damage(amount: int) -> void:
	currentHealth -= amount
	_flash_red()
	
	print ("Enemy health: ", currentHealth)
	
	if currentHealth <= 0:
		die()
		
func hit_player():
	if target_in_range():
		var dir = global_position.direction_to(player.global_position)
		player.hit(DAMAGE, dir)
		
func _flash_red() -> void:
	if mesh == null:
		return
		
	var mat := mesh.get_active_material(0)	
	mat = mat.duplicate()
	mesh.set_surface_override_material(0, mat)
	
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color", Color.RED, 0.08)
	tween.tween_property(mat, "albedo_color", Color.WHITE, 0.12)
	
		
func die() -> void:
	queue_free()
