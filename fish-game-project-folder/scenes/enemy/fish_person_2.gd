extends CharacterBody3D

@export_category("Refs")
@export var player_path: NodePath = NodePath("../Player")

@onready var mesh: MeshInstance3D = $"Armature_001/Skeleton3D/Plane_052" # override per enemy
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var vision_raycast: RayCast3D = $VisionRaycast
@onready var attack_area: Area3D = $AttackArea
@onready var player: CharacterBody3D = get_node_or_null(player_path) as CharacterBody3D

@export_category("Movement")
@export var idle_speed := 1.2
@export var chase_speed := 4.0
@export var turn_speed := 4.0
@export var idle_dir_change_time := 2.5

@export_category("Combat")
@export var max_health := 150
@export var attack_damage := 34
@export var attack_cooldown := 2.0

@export_category("Vision")
@export var lose_sight_time := 1.5
@export var sight_range := 25.0          # distance gate
@export var fov_deg := 120.0             # angle gate
@export var los_check_idle_interval := 0.25
@export var los_check_chase_interval := 0.10

# State
var health := 150
var move_dir := Vector3.ZERO
var idle_dir := Vector3.ZERO
var idle_timer := 0.0
var los_timer := 0.0
var attack_timer := 0.0
var chasing := false
var player_in_attack_range := false

# LOS cache
var _can_see_cached := false
var _los_check_timer := 0.0

@export var anim_name: StringName = &"fast_swim"

func _ready() -> void:
	health = max_health
	if anim_player and anim_name != &"":
		anim_player.play(anim_name)

	_pick_idle_dir()
	move_dir = idle_dir

	attack_area.body_entered.connect(_on_attack_area_entered)
	attack_area.body_exited.connect(_on_attack_area_exited)

func _physics_process(delta: float) -> void:
	attack_timer = max(0.0, attack_timer - delta)

	_update_los_cache(delta)

	if chasing:
		_process_chase(delta)
	else:
		_process_idle(delta)

	_face_movement()
	move_and_slide()

# -------------------------
# LINE OF SIGHT
# -------------------------
func _update_los_cache(delta: float) -> void:
	if player == null or vision_raycast == null:
		_can_see_cached = false
		return

	_los_check_timer -= delta
	if _los_check_timer > 0.0:
		return

	_los_check_timer = (los_check_chase_interval if chasing else los_check_idle_interval)

	# Distance gate
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if dist > sight_range:
		_can_see_cached = false
		return

	# FOV gate (cone)
	var forward := -global_transform.basis.z
	var dir = to_player / max(dist, 0.001)
	var cos_half_fov := cos(deg_to_rad(fov_deg * 0.5))
	if forward.dot(dir) < cos_half_fov:
		_can_see_cached = false
		return

	vision_raycast.target_position = vision_raycast.to_local(player.global_position)
	vision_raycast.force_raycast_update()
	_can_see_cached = vision_raycast.is_colliding() and vision_raycast.get_collider() == player

func _can_see_player() -> bool:
	return _can_see_cached

# -------------------------
# IDLE
# -------------------------
func _process_idle(delta: float) -> void:
	idle_timer -= delta
	if idle_timer <= 0.0:
		_pick_idle_dir()

	move_dir = move_dir.slerp(idle_dir, turn_speed * delta)
	velocity = move_dir * idle_speed

	if _can_see_player():
		chasing = true
		los_timer = lose_sight_time
		_los_check_timer = 0.0 # refresh LOS faster immediately

# -------------------------
# CHASE
# -------------------------
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

# -------------------------
# ATTACK
# -------------------------
func _try_attack() -> void:
	if attack_timer > 0.0:
		return
	attack_timer = attack_cooldown

	if player and player.has_method("hit"):
		var dir := global_position.direction_to(player.global_position)
		player.hit(attack_damage, dir)

# -------------------------
# ATTACK AREA
# -------------------------
func _on_attack_area_entered(body: Node) -> void:
	if body == player:
		player_in_attack_range = true

func _on_attack_area_exited(body: Node) -> void:
	if body == player:
		player_in_attack_range = false

# -------------------------
# IDLE HELPERS
# -------------------------
func _pick_idle_dir() -> void:
	idle_dir = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-0.5, 0.5),
		randf_range(-1.0, 1.0)
	).normalized()

	idle_timer = idle_dir_change_time

func _return_to_idle() -> void:
	chasing = false
	player_in_attack_range = false
	_pick_idle_dir()
	move_dir = idle_dir
	_los_check_timer = 0.0

# -------------------------
# DAMAGE
# -------------------------
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

# -------------------------
# ROTATION
# -------------------------
func _face_movement() -> void:
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)
