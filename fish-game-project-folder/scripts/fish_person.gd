extends CharacterBody3D


@onready var mesh: MeshInstance3D = $Armature_001/Skeleton3D/Plane_052
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var hitbox = $enemy_hitbox
@onready var vision_raycast: RayCast3D = $VisionRaycast

@export var player_path: NodePath
var player: CharacterBody3D


@export var move_speed := 2.5
@export var chase_acceleration := 6.0

# Idle / patrol
@export var idle_speed := 1.5
@export var idle_direction_change_time := 3.0

# Steering
@export var direction_smooth_speed := 6.0

var current_move_dir: Vector3 = Vector3.ZERO


@export var maxHealth := 100
var currentHealth := 100

const ATTACK_RANGE := 2.0
const DAMAGE := 20

@export var lose_sight_time := 1.2

var is_chasing := false
var los_timer := 0.0
var state_machine

# Idle movement
var idle_dir: Vector3
var idle_timer := 0.0

func _ready() -> void:
	player = get_node(player_path)
	currentHealth = maxHealth

	anim_tree.active = true
	state_machine = anim_tree.get("parameters/playback")

	_pick_new_idle_direction()
	current_move_dir = idle_dir


func _physics_process(delta: float) -> void:
	match state_machine.get_current_node():

		"idle_swim":
			_idle_move(delta)
			_check_vision()

		"fast_swim":
			_chase_move(delta)

		"attack":
			_attack_behavior(delta)

		"death":
			hitbox.disabled = true

func _idle_move(delta: float) -> void:
	idle_timer -= delta
	if idle_timer <= 0.0:
		_pick_new_idle_direction()

	current_move_dir = _smooth_direction(
		current_move_dir,
		idle_dir,
		delta
	)

	var target_velocity := current_move_dir * idle_speed
	velocity = velocity.move_toward(target_velocity, chase_acceleration * delta)

	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)

	move_and_slide()

func _pick_new_idle_direction() -> void:
	idle_dir = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-0.3, 0.3),
		randf_range(-1.0, 1.0)
	).normalized()

	idle_timer = idle_direction_change_time

func _check_vision() -> void:
	if _has_line_of_sight():
		is_chasing = true
		los_timer = lose_sight_time
		current_move_dir = (player.global_position - global_position).normalized()
		anim_tree.set("parameters/conditions/run", true)

func _has_line_of_sight() -> bool:
	if player == null:
		return false

	vision_raycast.look_at(
		Vector3(player.global_position.x, global_position.y, player.global_position.z),
		Vector3.UP
	)
	vision_raycast.force_raycast_update()

	if not vision_raycast.is_colliding():
		return false

	return vision_raycast.get_collider() == player


func _chase_move(delta: float) -> void:
	if player == null:
		_return_to_idle()
		return

	# LOS handling
	if _has_line_of_sight():
		los_timer = lose_sight_time
	else:
		los_timer -= delta
		if los_timer <= 0.0:
			_return_to_idle()
			return

	var to_player := player.global_position - global_position
	var distance := to_player.length()

	var desired_dir := to_player.normalized()
	current_move_dir = _smooth_direction(
		current_move_dir,
		desired_dir,
		delta
	)

	var desired_velocity := current_move_dir * move_speed
	velocity = velocity.move_toward(desired_velocity, chase_acceleration * delta)

	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)

	anim_tree.set("parameters/conditions/attack", distance <= ATTACK_RANGE)

	move_and_slide()

func _attack_behavior(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, chase_acceleration * delta)

	if player:
		look_at(
			Vector3(player.global_position.x, global_position.y, player.global_position.z),
			Vector3.UP
		)

	anim_tree.set("parameters/conditions/run", not target_in_range())
	move_and_slide()


func _return_to_idle() -> void:
	is_chasing = false
	los_timer = 0.0

	anim_tree.set("parameters/conditions/run", false)
	anim_tree.set("parameters/conditions/attack", false)

	_pick_new_idle_direction()
	current_move_dir = idle_dir
	
func target_in_range() -> bool:
	return player and global_position.distance_to(player.global_position) <= ATTACK_RANGE

func hit_player() -> void:
	if target_in_range():
		var dir := global_position.direction_to(player.global_position)
		player.hit(DAMAGE, dir)

func apply_damage(amount: int) -> void:
	currentHealth -= amount
	_flash_red()

	if currentHealth <= 0:
		die()

func _flash_red() -> void:
	if mesh == null:
		return

	var mat := mesh.get_active_material(0)
	if mat == null:
		return

	mat = mat.duplicate()
	mesh.set_surface_override_material(0, mat)

	var tween := create_tween()
	tween.tween_property(mat, "albedo_color", Color.RED, 0.08)
	tween.tween_property(mat, "albedo_color", Color.WHITE, 0.12)

func die() -> void:
	anim_tree.set("parameters/conditions/death", true)
	queue_free()

func _smooth_direction(current: Vector3, target: Vector3, delta: float) -> Vector3:
	if target.length() == 0.0:
		return current

	return current.lerp(
		target,
		clampf(direction_smooth_speed * delta, 0.0, 1.0)
	).normalized()
