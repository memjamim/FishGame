extends CharacterBody3D

# --- Interaction ---
@onready var player_raycast: RayCast3D = $CameraPivot/Camera3D/PlayerRaycast
@onready var pickup_throw: Node = $PickupThrow
@onready var anim_player: AnimationPlayer = $AnimationPlayer

@onready var player_ui: Control = $PlayerUI
var hp_bar
var breath_bar
var coin_counter

@onready var flashlight: SpotLight3D = $CameraPivot/Camera3D/Flashlight
var flashlight_enabled: bool = false

func has_flashlight() -> bool:
	return get_owned_tier("headlamp") >= 1 or owned_shop_items.has("headlamp")

func set_flashlight_unlocked(unlocked: bool) -> void:
	flashlight.visible = unlocked and flashlight_enabled


signal collectables_changed(count: int)

# Stuff for shop

signal shop_inventory_changed

# map family_id -> (tier -> icon)
var _shop_icon_by_family_tier: Dictionary = {}

func register_shop_item_icon(family_id: String, tier: int, icon: Texture2D) -> void:
	if not _shop_icon_by_family_tier.has(family_id):
		_shop_icon_by_family_tier[family_id] = {}
	_shop_icon_by_family_tier[family_id][tier] = icon

func get_best_icon_for_family(family_id: String) -> Texture2D:
	var owned_tier: int = get_owned_tier(family_id)
	if owned_tier <= 0:
		return null

	if not _shop_icon_by_family_tier.has(family_id):
		return null

	var tier_map: Dictionary = _shop_icon_by_family_tier[family_id]
	if not tier_map.has(owned_tier):
		return null

	return tier_map[owned_tier] as Texture2D



# --- Shop ownership (store tier per item family, like "wetsuit" -> 2) ---
var owned_shop_items: Dictionary = {} # { "wetsuit": 2, "flippers": 1, ... }

func get_owned_tier(item_family: String) -> int:
	return int(owned_shop_items.get(item_family, 0))

func set_owned_tier(item_family: String, tier: int) -> void:
	var current := get_owned_tier(item_family)
	if tier > current:
		owned_shop_items[item_family] = tier
		emit_signal("shop_inventory_changed")

func has_tier(item_family: String, tier: int) -> bool:
	return get_owned_tier(item_family) >= tier

func apply_max_health_bonus(new_max: int) -> void:
	var old_max := max_health
	max_health = max(new_max, 1)

	var delta := max_health - old_max
	if delta > 0:
		health = min(health + delta, max_health)
	else:
		health = clamp(health, 0, max_health)


func has_item(item_id: String) -> bool:
	return owned_shop_items.has(item_id)

func add_item(item_id: String) -> void:
	owned_shop_items[item_id] = true

func can_afford(cost: int) -> bool:
	return collectables >= cost

func spend_coins(cost: int) -> bool:
	if collectables < cost:
		return false
	collectables -= cost
	return true

var _collectables: int = 0
var collectables: int:
	get:
		return _collectables
	set(value):
		value = max(0, value)
		if value == _collectables:
			return
		_collectables = value
		emit_signal("collectables_changed", _collectables)

var IS_IN_WATER: bool = false
var IS_HOLDING_ITEM: bool = false
var IS_HOLDING_WEAPON: bool = false
signal water_state_changed(is_in_water: bool)

# Movement
@export var land_speed := 5.0
@export var swim_speed := 3.0

@export var land_accel := 18.0
@export var swim_accel := 6.0

@export var swim_drag := 3.5
@export var buoyancy := 1.5       # upward push in water

@export var jump_velocity := 4.5

# Mouse look
@export var mouse_sensitivity := 0.002
@export var max_pitch_deg := 85.0

# Breath
@export var breath_max := 60.0            # 1:00 breath time / items will likely need to modify this
@export var breath_recover_rate := 20.0  # recovery on land
@export var breath_ui_path: NodePath
signal breath_updated(current: float, max_value: float)
signal drowned

@onready var camera_pivot: Node3D = $CameraPivot

# --- Head-based water detection ---
@export var head_node_path: NodePath = NodePath("CameraPivot/Camera3D")

# Set to the layer of water (currently 1, but may change)
@export var water_collision_mask: int = 1

# Larger = less flicker at the surface.
@export var water_state_smooth_time := 0.20

# --- Underwater bobbing (visual) ---
@export var underwater_bob_amplitude := 0.08   # hight of bob
@export var underwater_bob_frequency := 0.5    # cycles/sec
@export var underwater_bob_smoothing := 8.0    # higher = snappier

# --- Underwater sprint ---
@export var underwater_sprint_multiplier := 1.75  # swim_speed * this while sprinting
@export var breath_drain_normal := 1.0            # per second in water (normal swim)
@export var breath_drain_sprint := 3.0            # per second in water while sprinting

# --- Depth-based breath drain ---
@export var water_surface_y := 0.0              # surface height in world Y (0 = surface)
@export var bottom_depth_m := 100.0             # meters below surface where max multiplier applies
@export var depth_breath_multiplier_max := 3.0  # at bottom_depth_m, breath drains this many times faster

# Per-scene markers (assign in Inspector if we need different scaling), currently unused
@export var surface_marker_path: NodePath
@export var bottom_marker_path: NodePath

var _surface_marker: Node3D
var _bottom_marker: Node3D

# --- Drowning damage / respawn ---
@export var drown_damage_amount: int = 1         # damage per tick
@export var drown_tick_interval: float = 0.1     # seconds between ticks (1 dmg per 0.1s = 10 dmg/sec)

var _drown_tick_timer: float = 0.0
var _spawn_transform: Transform3D

var _pitch := 0.0
var breath := 60.0

var _head_node: Node3D
var _water_blend := 0.0
var _bob_time := 0.0
var _pivot_base_pos: Vector3

var is_attacking: bool = false

# Sprint state
var is_sprinting_underwater: bool = false

@export var base_max_health: int = 100
var max_health: int = 100
var health: int = 100

const PUSHBACK = 8.0

const WEAPON_DAMAGE := {
	1: 20,
	2: 25,
	3: 34
}

var weapon_tier := 1

# --- Audio (children under $Audio) ---
@onready var audio_root: Node = $Audio
@onready var sfx_stab: AudioStreamPlayer = $Audio/Stab
@onready var sfx_oof: AudioStreamPlayer = $Audio/Oof
@onready var sfx_underwater_amb: AudioStreamPlayer = $Audio/UnderwaterAmbiance
@onready var sfx_footsteps: AudioStreamPlayer = $Audio/Footsteps

# Footstep timing
@export var footstep_interval_walk := 0.45
@export var footstep_interval_run := 0.30
@export var footstep_speed_threshold := 0.25
var _footstep_timer := 0.0


func _ready() -> void:
	max_health = base_max_health
	health = max_health
	add_to_group("player")

	# Save spawn position/rotation for respawn
	_spawn_transform = global_transform

	breath = breath_max
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	emit_signal("breath_updated", breath, breath_max)
	emit_signal("collectables_changed", collectables)

	print("total collectables: ", collectables)

	_head_node = get_node(head_node_path) as Node3D
	_pivot_base_pos = camera_pivot.position

	# Cache optional depth markers
	_surface_marker = get_node_or_null(surface_marker_path) as Node3D
	_bottom_marker = get_node_or_null(bottom_marker_path) as Node3D

	mouse_sensitivity = Settings.mouse_sensitivity
	$CameraPivot/Camera3D.fov = Settings.fov

	Settings.changed.connect(_apply_settings)

	self.hp_bar = player_ui.find_child("Hp")
	self.breath_bar = player_ui.find_child("Breath")
	self.coin_counter = player_ui.find_child("CoinsCounter")

	# Ensure underwater ambiance matches initial state
	if IS_IN_WATER:
		if not sfx_underwater_amb.playing:
			sfx_underwater_amb.play()
	else:
		if sfx_underwater_amb.playing:
			sfx_underwater_amb.stop()
	
	flashlight.visible = false


func _apply_settings() -> void:
	mouse_sensitivity = Settings.mouse_sensitivity
	$CameraPivot/Camera3D.fov = Settings.fov


func set_in_water(v: bool) -> void:
	if v == IS_IN_WATER:
		return

	IS_IN_WATER = v
	emit_signal("water_state_changed", IS_IN_WATER)

	# If we just entered water, avoids popping upward from existing velocity
	if IS_IN_WATER:
		velocity.y = min(velocity.y, 0.0)

		# Start underwater ambiance
		if sfx_underwater_amb and not sfx_underwater_amb.playing:
			sfx_underwater_amb.play()
	else:
		# Leaving water: ensure sprint state doesn't stick
		is_sprinting_underwater = false
		# Also reset drowning tick timer when you get air
		_drown_tick_timer = 0.0

		# Stop underwater ambiance
		if sfx_underwater_amb and sfx_underwater_amb.playing:
			sfx_underwater_amb.stop()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("toggle_flashlight"):
		if has_flashlight():
			flashlight_enabled = !flashlight_enabled
			flashlight.visible = flashlight_enabled


	# Toggle mouse capture (for easier testing in editor)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Rotation on player body
		rotate_y(-event.relative.x * mouse_sensitivity)

		# Rotation on pivot
		_pitch = clamp(
			_pitch - event.relative.y * mouse_sensitivity,
			deg_to_rad(-max_pitch_deg),
			deg_to_rad(max_pitch_deg)
		)
		camera_pivot.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	_update_water_state(delta)
	_update_breath(delta)
	_update_drowning_damage(delta)
	_update_footsteps(delta)
	_update_ui()

	var input_dir := Input.get_vector("left", "right", "foward", "back")

	# Vertical swim input: Space up, Shift down
	var vertical_input := 0.0
	if IS_IN_WATER:
		if Input.is_action_pressed("jump"):
			vertical_input += 1.0
		if Input.is_action_pressed("down"):
			vertical_input -= 1.0

	# Move relative to player orientation
	var wish_dir := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y))
	wish_dir.y = vertical_input

	if wish_dir.length() > 0.001:
		wish_dir = wish_dir.normalized()

	# --- Underwater sprint (held) ---
	is_sprinting_underwater = IS_IN_WATER and Input.is_action_pressed("sprint") and wish_dir.length() > 0.001

	if IS_IN_WATER:
		_swim_move(wish_dir, delta)
	else:
		_land_move(wish_dir, delta)

	# --- Interaction ---
	if player_raycast.is_colliding() and Input.is_action_just_pressed("interact"):
		var collider = player_raycast.get_collider()
		if collider.has_method("_on_interact"):
			collider._on_interact(self)

		# collectables are non-physical things to collect (ex. coins that increase a coin value variable)
		if collider.is_in_group("collectable"):
			print("total collectables: ", self.collectables)
		# interactables are things the player can interact with but won't give them anything
		elif collider.is_in_group("interactable"):
			print("interactable encountered")
		# weapons are weapons. duh
		elif collider.is_in_group("weapon"):
			if IS_HOLDING_WEAPON == false:
				self.IS_HOLDING_WEAPON = true
				self.pickup_throw._pick_up(collider)
				if !collider.is_connected("enemy_hit", _on_weapon_hitbox_t_1_body_entered):
					collider.connect("enemy_hit", _on_weapon_hitbox_t_1_body_entered)
		# holdables are things for the player to pick up to bring back to radical david
		elif collider.is_in_group("holdable"):
			if IS_HOLDING_ITEM == false:
				self.IS_HOLDING_ITEM = true
				self.pickup_throw._pick_up(collider)

	if Input.is_action_pressed("throw") and (IS_HOLDING_ITEM or IS_HOLDING_WEAPON):
		self.pickup_throw._charge_throw(delta)

	if Input.is_action_just_released("throw"):
		# Will drop item before dropping weapon.
		# Switch order of elif statements to swap this priority
		if IS_HOLDING_ITEM:
			var held_item = self.get_node("CameraPivot/Camera3D/Offhand").get_child(0)
			self.pickup_throw._throw(held_item)
			self.IS_HOLDING_ITEM = false
		elif IS_HOLDING_WEAPON:
			var held_weapon = self.get_node("CameraPivot/Camera3D/HoldPoint").get_child(0)
			self.pickup_throw._throw(held_weapon)
			self.IS_HOLDING_WEAPON = false

	# --- Combat ---
	if Input.is_action_just_pressed("attack") and IS_HOLDING_WEAPON and !is_attacking:
		is_attacking = true
		var weapon = self.get_node("CameraPivot/Camera3D/HoldPoint").get_child(0)
		anim_player.play("attack")
		weapon.find_child("Hitbox").monitoring = true

		# Play stab sound on swing
		if sfx_stab:
			sfx_stab.play()

	move_and_slide()

	# Visual bob after movement so it feels stable while moving
	_apply_underwater_bob(delta)


func _land_move(wish_dir: Vector3, delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Accelerate horizontally
	var target := wish_dir * land_speed
	velocity.x = move_toward(velocity.x, target.x, land_accel * delta)
	velocity.z = move_toward(velocity.z, target.z, land_accel * delta)


func _swim_move(wish_dir: Vector3, delta: float) -> void:
	# Buoyancy + drag for water movement
	velocity.y += buoyancy * delta
	velocity = velocity.move_toward(Vector3.ZERO, swim_drag * delta)

	# Acceleration toward 3D target direction
	var speed := swim_speed * (underwater_sprint_multiplier if is_sprinting_underwater else 1.0)
	var target := wish_dir * speed
	velocity.x = move_toward(velocity.x, target.x, swim_accel * delta)
	velocity.y = move_toward(velocity.y, target.y, swim_accel * delta)
	velocity.z = move_toward(velocity.z, target.z, swim_accel * delta)


func _get_depth_breath_multiplier() -> float:
	# Determine surface Y
	var surface_y: float = water_surface_y
	if _surface_marker != null:
		surface_y = _surface_marker.global_position.y

	# Determine bottom depth (in meters) either via marker distance or value
	var depth_max: float = bottom_depth_m
	if _bottom_marker != null:
		depth_max = maxf(0.001, surface_y - _bottom_marker.global_position.y)

	# Player depth below surface
	var depth: float = maxf(0.0, surface_y - global_position.y)

	# Normalize depth into 0..1 where 1 = bottom
	var t: float = clampf(depth / depth_max, 0.0, 1.0)

	# 1x at surface -> depth_breath_multiplier_max at bottom
	return lerpf(1.0, depth_breath_multiplier_max, t)


func _update_breath(delta: float) -> void:
	if IS_IN_WATER:
		# Base drain depends on sprinting, then scaled by depth multiplier
		var base_drain: float = breath_drain_sprint if is_sprinting_underwater else breath_drain_normal
		var depth_mult: float = _get_depth_breath_multiplier()
		var drain_rate: float = base_drain * depth_mult

		breath = maxf(0.0, breath - drain_rate * delta)
		if breath <= 0.0:
			emit_signal("drowned")
	else:
		# Fast breath refill when player gets air
		breath = minf(breath_max, breath + breath_recover_rate * delta)

	emit_signal("breath_updated", breath, breath_max)


func _update_drowning_damage(delta: float) -> void:
	# Only take drowning damage when underwater and breath is fully gone
	if IS_IN_WATER and breath <= 0.0 and health > 0:
		_drown_tick_timer += delta
		print('health: ', health)
		while _drown_tick_timer >= drown_tick_interval and health > 0:
			_drown_tick_timer -= drown_tick_interval
			health -= drown_damage_amount
			if health <= 0:
				_respawn()
				return
	else:
		# If you have breath again or aren't underwater, stop the ticking.
		_drown_tick_timer = 0.0


func _respawn() -> void:
	# Reset stats
	health = max_health
	breath = breath_max
	_drown_tick_timer = 0.0

	# Reset movement state
	velocity = Vector3.ZERO
	is_sprinting_underwater = false
	IS_HOLDING_ITEM = false

	# Move player back to spawn
	global_transform = _spawn_transform

	# Update UI signals immediately
	emit_signal("breath_updated", breath, breath_max)


func _update_water_state(delta: float) -> void:
	# Node3D point query at the head position against Water layer(s)
	var head_in_water := _is_head_in_water()

	# Smooth around the surface to reduce flicker
	if water_state_smooth_time <= 0.0:
		set_in_water(head_in_water)
		return

	var rate := delta / water_state_smooth_time
	if head_in_water:
		_water_blend = min(1.0, _water_blend + rate)
	else:
		_water_blend = max(0.0, _water_blend - rate)

	set_in_water(_water_blend >= 0.5)


func _is_head_in_water() -> bool:
	if _head_node == null:
		return false

	var params := PhysicsPointQueryParameters3D.new()
	params.position = _head_node.global_position
	params.collision_mask = water_collision_mask
	params.collide_with_areas = true
	params.collide_with_bodies = false

	var hits := get_world_3d().direct_space_state.intersect_point(params, 8)
	return hits.size() > 0


func _apply_underwater_bob(delta: float) -> void:
	var target_offset_y := 0.0

	if IS_IN_WATER:
		_bob_time += delta
		target_offset_y = sin(_bob_time * TAU * underwater_bob_frequency) * underwater_bob_amplitude
	else:
		_bob_time = 0.0

	var desired := _pivot_base_pos + Vector3(0.0, target_offset_y, 0.0)
	var t: float = clampf(underwater_bob_smoothing * delta, 0.0, 1.0)
	camera_pivot.position = camera_pivot.position.lerp(desired, t)


func _update_footsteps(delta: float) -> void:
	# Only land footsteps
	if IS_IN_WATER or not is_on_floor():
		_footstep_timer = 0.0
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed < footstep_speed_threshold:
		_footstep_timer = 0.0
		return

	# Walking SFX
	#var t := clampf(horizontal_speed / land_speed, 0.0, 1.0)
	#var interval := lerpf(footstep_interval_walk, footstep_interval_run, t)
#
	#_footstep_timer += delta
	#if _footstep_timer >= interval:
		#_footstep_timer = 0.0
		#if sfx_footsteps:
			#sfx_footsteps.stop()
			#sfx_footsteps.play()


func _on_weapon_hitbox_t_1_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy") and body.has_method("apply_damage"):
		var damage: int = WEAPON_DAMAGE.get(weapon_tier, 10)
		body.apply_damage(damage)
		print("Enemy hit!")
		var weapon = self.get_node("CameraPivot/Camera3D/HoldPoint").get_child(0)
		weapon.find_child("Hitbox").set_deferred("monitoring", false)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack" and IS_HOLDING_WEAPON:
		anim_player.play("idle")
		is_attacking = false
		var weapon = self.get_node("CameraPivot/Camera3D/HoldPoint").get_child(0)
		weapon.find_child("Hitbox").monitoring = false


func hit(damage, dir):
	health -= damage
	velocity += dir * PUSHBACK

	# Play "oof" when hit
	if sfx_oof:
		sfx_oof.stop()
		sfx_oof.play()

	if health <= 0:
		_respawn()


func _update_ui() -> void:
	self.breath_bar.value = (self.breath / self.breath_max) * 100.0
	self.hp_bar.value = hp_bar.max_value - (float(health) / float(max_health)) * hp_bar.max_value
	self.coin_counter.find_child("Label").text = str(self._collectables)
