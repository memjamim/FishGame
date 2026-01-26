extends CharacterBody3D

# --- Interaction ---
@onready var player_raycast: RayCast3D = $CameraPivot/Camera3D/PlayerRaycast
@onready var pickup_throw: Node = $PickupThrow
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# --- UI ---
@onready var player_ui: Control = $PlayerUI
var hp_bar: Range
var breath_bar: Range
var coin_counter: Control
var item_bar: HBoxContainer

# --- Flashlight (Headlamp unlock) ---
@onready var flashlight: SpotLight3D = $CameraPivot/Camera3D/Flashlight
var flashlight_enabled: bool = false
var flashlight_unlocked: bool = false

func has_flashlight() -> bool:
	return get_owned_tier("headlamp") >= 1

func set_flashlight_unlocked(unlocked: bool) -> void:
	flashlight_unlocked = unlocked
	flashlight.visible = flashlight_unlocked and flashlight_enabled


# --- Currency / Collectables ---
signal collectables_changed(count: int)

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

func can_afford(cost: int) -> bool:
	return collectables >= cost

func spend_coins(cost: int) -> bool:
	if collectables < cost:
		return false
	collectables -= cost
	return true


# --- Shop / Inventory ownership ---
signal shop_inventory_changed

# owned_shop_items stores tiers per family (e.g. "wetsuit" -> 2, "headlamp" -> 1)
var owned_shop_items: Dictionary = {}

func get_owned_tier(item_family: String) -> int:
	return int(owned_shop_items.get(item_family, 0))

func set_owned_tier(item_family: String, tier: int) -> void:
	var current := get_owned_tier(item_family)
	if tier > current:
		owned_shop_items[item_family] = tier
		emit_signal("shop_inventory_changed")

func has_tier(item_family: String, tier: int) -> bool:
	return get_owned_tier(item_family) >= tier

# Icon registry: family -> { tier -> Texture2D }
var _shop_icon_by_family_tier: Dictionary = {}

func register_shop_item_icon(family_id: String, tier: int, icon: Texture2D) -> void:
	if icon == null:
		return
	if not _shop_icon_by_family_tier.has(family_id):
		_shop_icon_by_family_tier[family_id] = {}
	var tier_map: Dictionary = _shop_icon_by_family_tier[family_id]
	tier_map[tier] = icon
	_shop_icon_by_family_tier[family_id] = tier_map

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


# --- Water / Holding ---
var IS_IN_WATER: bool = false
var IS_HOLDING_ITEM: bool = false
var IS_HOLDING_WEAPON: bool = false

signal water_state_changed(is_in_water: bool)

# --- Movement ---
var PAUSE_MOVEMENT: bool = false

@export var land_speed := 5.0
@export var swim_speed := 3.0

@export var land_accel := 18.0
@export var swim_accel := 6.0

@export var swim_drag := 3.5
@export var buoyancy := 1.5
@export var jump_velocity := 4.5

# Mouse look
@export var mouse_sensitivity := 0.002
@export var max_pitch_deg := 85.0

# --- Breath ---
@export var breath_max := 60.0
@export var breath_recover_rate := 20.0
signal breath_updated(current: float, max_value: float)
signal drowned

@onready var camera_pivot: Node3D = $CameraPivot

# --- Head-based water detection ---
@export var head_node_path: NodePath = NodePath("CameraPivot/Camera3D")
@export var water_collision_mask: int = 1
@export var water_state_smooth_time := 0.20

# --- Underwater bobbing (visual) ---
@export var underwater_bob_amplitude := 0.08
@export var underwater_bob_frequency := 0.5
@export var underwater_bob_smoothing := 8.0

# --- Underwater sprint ---
@export var underwater_sprint_multiplier := 1.75
@export var breath_drain_normal := 1.0
@export var breath_drain_sprint := 3.0

# --- Depth-based breath drain ---
@export var water_surface_y := 0.0
@export var bottom_depth_m := 100.0
@export var depth_breath_multiplier_max := 3.0

@export var surface_marker_path: NodePath
@export var bottom_marker_path: NodePath

var _surface_marker: Node3D
var _bottom_marker: Node3D

# --- Drowning damage / respawn ---
@export var drown_damage_amount: int = 1
@export var drown_tick_interval: float = 0.1

var _drown_tick_timer: float = 0.0
var _spawn_transform: Transform3D

var _pitch := 0.0
var breath := 60.0

var IS_IN_CORAL: bool = false
var coral_recover_rate: float = 0.25

var _head_node: Node3D
var _water_blend := 0.0
var _bob_time := 0.0
var _pivot_base_pos: Vector3

var is_attacking: bool = false
var is_sprinting_underwater: bool = false

# --- Health ---
@export var base_max_health: int = 100
var max_health: int = 100
var health: int = 100

func apply_max_health_bonus(new_max: int) -> void:
	var old_max := max_health
	max_health = max(new_max, 1)

	# Heal by the increase in max health
	var delta := max_health - old_max
	if delta > 0:
		health = min(health + delta, max_health)
	else:
		health = clamp(health, 0, max_health)

const PUSHBACK = 8.0

const WEAPON_DAMAGE := {
	1: 20,
	2: 25,
	3: 34
}

var weapon_tier := 1

# --- Audio ---
@onready var audio_root: Node = $Audio
@onready var sfx_stab: AudioStreamPlayer = $Audio/Stab
@onready var sfx_oof: AudioStreamPlayer = $Audio/Oof
@onready var sfx_underwater_amb: AudioStreamPlayer = $Audio/UnderwaterAmbiance
@onready var sfx_footsteps: AudioStreamPlayer = $Audio/Footsteps

@export var footstep_interval_walk := 0.45
@export var footstep_interval_run := 0.30
@export var footstep_speed_threshold := 0.25
var _footstep_timer := 0.0

# --- Visual ---
@onready var underwater_effect: MeshInstance3D = $CameraPivot/Camera3D/UnderwaterEffect



func _ready() -> void:
	max_health = base_max_health
	health = max_health

	add_to_group("player")
	_spawn_transform = global_transform

	breath = breath_max
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	emit_signal("breath_updated", breath, breath_max)
	emit_signal("collectables_changed", collectables)

	_head_node = get_node(head_node_path) as Node3D
	_pivot_base_pos = camera_pivot.position

	_surface_marker = get_node_or_null(surface_marker_path) as Node3D
	_bottom_marker = get_node_or_null(bottom_marker_path) as Node3D

	mouse_sensitivity = Settings.mouse_sensitivity
	$CameraPivot/Camera3D.fov = Settings.fov
	Settings.changed.connect(_apply_settings)

	# Cache UI nodes
	hp_bar = player_ui.find_child("Hp", true, true) as Range
	breath_bar = player_ui.find_child("Breath", true, true) as Range
	coin_counter = player_ui.find_child("CoinsCounter", true, true) as Control
	item_bar = player_ui.find_child("ItemBar", true, true) as HBoxContainer



	if item_bar == null:
		push_warning("PlayerUI: ItemBar not found (HBoxContainer). Icons will not display.")

	# Update icon bar whenever inventory changes
	shop_inventory_changed.connect(_rebuild_item_bar)
	_rebuild_item_bar()

	# Underwater ambiance initial state
	if IS_IN_WATER:
		if not sfx_underwater_amb.playing:
			sfx_underwater_amb.play()
	else:
		if sfx_underwater_amb.playing:
			sfx_underwater_amb.stop()
	
	

	# Flashlight starts hidden until unlocked and toggled
	flashlight.visible = false


func _apply_settings() -> void:
	mouse_sensitivity = Settings.mouse_sensitivity
	$CameraPivot/Camera3D.fov = Settings.fov


func _rebuild_item_bar() -> void:
	if item_bar == null:
		return

	for c in item_bar.get_children():
		c.queue_free()

	# One icon per family (highest tier only)
	for family_id in owned_shop_items.keys():
		var icon: Texture2D = get_best_icon_for_family(family_id)
		if icon == null:
			continue

		var tex := TextureRect.new()
		tex.texture = icon
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(80, 80)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_bar.add_child(tex)


func set_in_water(v: bool) -> void:
	if v == IS_IN_WATER:
		return

	IS_IN_WATER = v
	emit_signal("water_state_changed", IS_IN_WATER)

	if IS_IN_WATER:
		velocity.y = min(velocity.y, 0.0)

		# Start underwater ambiance
		if sfx_underwater_amb and not sfx_underwater_amb.playing:
			sfx_underwater_amb.play()
	else:
		is_sprinting_underwater = false
		_drown_tick_timer = 0.0
		if sfx_underwater_amb and sfx_underwater_amb.playing:
			sfx_underwater_amb.stop()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return

	# Toggle flashlight if unlocked
	if event.is_action_pressed("toggle_flashlight"):
		if flashlight_unlocked or has_flashlight():
			flashlight_unlocked = true
			flashlight_enabled = !flashlight_enabled
			flashlight.visible = flashlight_enabled

	# Toggle mouse capture (for easier testing in editor)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
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
	#_update_footsteps(delta)
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
		print(collider)
		if collider and collider.has_method("_on_interact"):
			collider._on_interact(self)
<<<<<<< Updated upstream

=======
			return
	
>>>>>>> Stashed changes
		if collider and collider.is_in_group("collectable"):
			print("total collectables: ", self.collectables)
		elif collider and collider.is_in_group("interactable"):
			print("interactable encountered")
		# weapons are weapons. duh
		elif collider.is_in_group("weapon"):
			if !IS_HOLDING_WEAPON:
				IS_HOLDING_WEAPON = true
				pickup_throw._pick_up(collider)

				var hitbox = collider.find_child("Hitbox")
				if hitbox:
					hitbox.monitoring = false  # start clean

				if !collider.is_connected("enemy_hit", _on_weapon_hitbox_t_1_body_entered):
					collider.connect("enemy_hit", _on_weapon_hitbox_t_1_body_entered)
		elif collider and collider.is_in_group("holdable"):
			if IS_HOLDING_ITEM == false:
				IS_HOLDING_ITEM = true
				pickup_throw._pick_up(collider)

	if Input.is_action_pressed("throw") and (IS_HOLDING_ITEM or IS_HOLDING_WEAPON):
		pickup_throw._charge_throw(delta)

	if Input.is_action_just_released("throw"):
		if IS_HOLDING_ITEM:
			var held_item = get_node("CameraPivot/Camera3D/Offhand").get_child(0)
			pickup_throw._throw(held_item)
			IS_HOLDING_ITEM = false
		elif IS_HOLDING_WEAPON:
			var held_weapon = self.get_node("CameraPivot/Camera3D/HoldPoint").get_child(0)
			self.pickup_throw._throw(held_weapon)
			self.IS_HOLDING_WEAPON = false
			
			is_attacking = false
			anim_player.stop()

	# --- Combat ---
	if Input.is_action_just_pressed("attack") and IS_HOLDING_WEAPON and not is_attacking:
		is_attacking = true
		var weapon = get_node("CameraPivot/Camera3D/HoldPoint").get_child(0)
		anim_player.play("attack")
		weapon.find_child("Hitbox").monitoring = true
		if sfx_stab:
			sfx_stab.play()

	move_and_slide()
	_apply_underwater_bob(delta)


func _land_move(wish_dir: Vector3, delta: float) -> void:
	if PAUSE_MOVEMENT:
		return
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var target := wish_dir * land_speed
	velocity.x = move_toward(velocity.x, target.x, land_accel * delta)
	velocity.z = move_toward(velocity.z, target.z, land_accel * delta)


func _swim_move(wish_dir: Vector3, delta: float) -> void:
	velocity.y += buoyancy * delta
	velocity = velocity.move_toward(Vector3.ZERO, swim_drag * delta)

	var speed := swim_speed * (underwater_sprint_multiplier if is_sprinting_underwater else 1.0)
	var target := wish_dir * speed
	velocity.x = move_toward(velocity.x, target.x, swim_accel * delta)
	velocity.y = move_toward(velocity.y, target.y, swim_accel * delta)
	velocity.z = move_toward(velocity.z, target.z, swim_accel * delta)


func _get_depth_breath_multiplier() -> float:
	var surface_y: float = water_surface_y
	if _surface_marker != null:
		surface_y = _surface_marker.global_position.y

	var depth_max: float = bottom_depth_m
	if _bottom_marker != null:
		depth_max = maxf(0.001, surface_y - _bottom_marker.global_position.y)

	var depth: float = maxf(0.0, surface_y - global_position.y)
	var t: float = clampf(depth / depth_max, 0.0, 1.0)
	return lerpf(1.0, depth_breath_multiplier_max, t)


func _update_breath(delta: float) -> void:
	if IS_IN_CORAL:
		breath = minf(breath_max, breath + breath_recover_rate * delta * coral_recover_rate)
	elif IS_IN_WATER:
		# Base drain depends on sprinting, then scaled by depth multiplier
		var base_drain: float = breath_drain_sprint if is_sprinting_underwater else breath_drain_normal
		var depth_mult: float = _get_depth_breath_multiplier()
		var drain_rate: float = base_drain * depth_mult

		breath = maxf(0.0, breath - drain_rate * delta)
		if breath <= 0.0:
			emit_signal("drowned")
	else:
		breath = minf(breath_max, breath + breath_recover_rate * delta)

	emit_signal("breath_updated", breath, breath_max)


func _update_drowning_damage(delta: float) -> void:
	if IS_IN_WATER and breath <= 0.0 and health > 0:
		_drown_tick_timer += delta
		while _drown_tick_timer >= drown_tick_interval and health > 0:
			_drown_tick_timer -= drown_tick_interval
			health -= drown_damage_amount
			if health <= 0:
				_respawn()
				return
		_set_taking_damage()
	else:
		_drown_tick_timer = 0.0


func _respawn() -> void:
	health = max_health
	breath = breath_max
	_drown_tick_timer = 0.0
	velocity = Vector3.ZERO
	is_sprinting_underwater = false
	IS_HOLDING_ITEM = false
	global_transform = _spawn_transform
	emit_signal("breath_updated", breath, breath_max)


func _update_water_state(delta: float) -> void:
	var head_in_water := _is_head_in_water()

	if water_state_smooth_time <= 0.0:
		set_in_water(head_in_water)
		return

	var rate := delta / water_state_smooth_time
	if head_in_water:
		self.underwater_effect.visible = true
		_water_blend = min(1.0, _water_blend + rate)
	else:
		self.underwater_effect.visible = false
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


#func _update_footsteps(delta: float) -> void:
	#if IS_IN_WATER or not is_on_floor():
		#_footstep_timer = 0.0
		#return
#
	#var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	#if horizontal_speed < footstep_speed_threshold:
		#_footstep_timer = 0.0
		#return



func _on_weapon_hitbox_t_1_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy") and body.has_method("apply_damage"):
		var damage: int = WEAPON_DAMAGE.get(weapon_tier, 10)
		body.apply_damage(damage)
		var weapon = get_node("CameraPivot/Camera3D/HoldPoint").get_child(0)
		weapon.find_child("Hitbox").set_deferred("monitoring", false)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack":
		is_attacking = false

	if IS_HOLDING_WEAPON:
		anim_player.play("idle")
		var weapon = $CameraPivot/Camera3D/HoldPoint.get_child(0)
		weapon.find_child("Hitbox").monitoring = false


func hit(damage, dir): 
	health -= damage
	velocity += dir * PUSHBACK

	if sfx_oof:
		sfx_oof.stop()
		sfx_oof.play()

	if health <= 0:
		_respawn()
	
	_set_taking_damage()


func _update_ui() -> void:
	if breath_bar:
		breath_bar.value = (breath / breath_max) * 100.0
	if hp_bar:
		hp_bar.value = hp_bar.max_value - (float(health) / float(max_health)) * hp_bar.max_value
	if coin_counter:
		var lbl := coin_counter.find_child("Label", true, false) as Label
		if lbl:
			lbl.text = str(_collectables)


func _set_taking_damage() -> void:
	pass
