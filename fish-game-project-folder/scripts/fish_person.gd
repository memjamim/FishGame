extends CharacterBody3D

@onready var mesh: MeshInstance3D = $Armature_001/Skeleton3D/Plane_052
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var vision_raycast: RayCast3D = $VisionRaycast
@onready var attack_area: Area3D = $AttackArea
# @onready var player_path = $'../Player'
var player: CharacterBody3D 

# ---------------- MOVEMENT ----------------
@export var idle_speed := 1.2
@export var chase_speed := 2.5
@export var turn_speed := 4.0
@export var idle_dir_change_time := 2.5

# ---------------- COMBAT ----------------
@export var max_health := 100
@export var attack_damage := 20
@export var attack_cooldown := 2.0

# ---------------- VISION ----------------
@export var lose_sight_time := 1.5

# ---------------- STATE ----------------
var health := 100
var move_dir := Vector3.ZERO
var idle_dir := Vector3.ZERO
var idle_timer := 0.0
var los_timer := 0.0
var attack_timer := 0.0
var chasing := false
var player_in_attack_range := false

const ANIM_NAME := "fast_swim"

# ----------------------------------------------------

func _ready() -> void:
	if player == null:
		player = get_tree().get_root().find_node("Player")
		if player == null:
			push_warning("Enemy has no player reference and could not find Player node in scene!")
		else:
			print("Player reference found automatically:", player)

	health = max_health
	anim_player.play(ANIM_NAME)
	_pick_idle_dir()
	move_dir = idle_dir

	attack_area.body_entered.connect(_on_attack_area_entered)
	attack_area.body_exited.connect(_on_attack_area_exited)


# ----------------------------------------------------

func _physics_process(delta: float) -> void:
	attack_timer -= delta

	if chasing:
		_process_chase(delta)
	else:
		_process_idle(delta)

	_face_movement()
	move_and_slide()

# ----------------------------------------------------
# IDLE
# ----------------------------------------------------

func _process_idle(delta: float) -> void:
	idle_timer -= delta
	if idle_timer <= 0.0:
		_pick_idle_dir()

	move_dir = move_dir.slerp(idle_dir, turn_speed * delta)
	velocity = move_dir * idle_speed

	if _can_see_player():
		chasing = true
		los_timer = lose_sight_time

# ----------------------------------------------------
# CHASE
# ----------------------------------------------------

func _process_chase(delta: float) -> void:
	if player == null:
		_return_to_idle()
		return

	if _can_see_player():
		los_timer = lose_sight_time
	else:
		los_timer -= delta
		if los_timer <= 0.0:
			_return_to_idle()
			return

	var to_player := (player.global_position - global_position).normalized()
	move_dir = move_dir.slerp(to_player, turn_speed * delta)
	velocity = move_dir * chase_speed

	if player_in_attack_range:
		_try_attack()

# ----------------------------------------------------
# ATTACK
# ----------------------------------------------------

func _try_attack() -> void:
	if attack_timer > 0.0:
		return

	attack_timer = attack_cooldown

	if player and player.has_method("hit"):
		var dir := global_position.direction_to(player.global_position)
		player.hit(attack_damage, dir)

# ----------------------------------------------------
# ATTACK AREA SIGNALS
# ----------------------------------------------------

func _on_attack_area_entered(body: Node) -> void:
	if body == player:
		player_in_attack_range = true

func _on_attack_area_exited(body: Node) -> void:
	if body == player:
		player_in_attack_range = false

# ----------------------------------------------------
# VISION
# ----------------------------------------------------

func _can_see_player() -> bool:
	if player == null:
		return false

	vision_raycast.look_at(player.global_position, Vector3.UP)
	vision_raycast.force_raycast_update()

	return vision_raycast.is_colliding() and vision_raycast.get_collider() == player

# ----------------------------------------------------
# IDLE HELPERS
# ----------------------------------------------------

func _pick_idle_dir() -> void:
	idle_dir = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()

	idle_timer = idle_dir_change_time

func _return_to_idle() -> void:
	chasing = false
	player_in_attack_range = false
	_pick_idle_dir()
	move_dir = idle_dir

# ----------------------------------------------------
# DAMAGE
# ----------------------------------------------------

func apply_damage(amount: int) -> void:
	health -= amount
	_flash_red()

	if health <= 0:
		queue_free()

func _flash_red() -> void:
	if mesh == null:
		return

	var mat := mesh.get_active_material(0)
	if mat == null:
		return

	mat = mat.duplicate()
	mesh.set_surface_override_material(0, mat)

	var t := create_tween()
	t.tween_property(mat, "albedo_color", Color.RED, 0.07)
	t.tween_property(mat, "albedo_color", Color.WHITE, 0.12)

# ----------------------------------------------------
# ROTATION
# ----------------------------------------------------

func _face_movement() -> void:
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)
