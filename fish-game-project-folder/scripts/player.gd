extends CharacterBody3D

# --- Interaction ---
@onready var ray_cast_3d: RayCast3D = $CameraPivot/Camera3D/RayCast3D
@onready var pickup_throw: Node = $PickupThrow
@onready var anim_player: AnimationPlayer = $AnimationPlayer


signal collectables_changed(count: int)

# Stuff for future shop

var owned_shop_items: Dictionary = {}

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

var _pitch := 0.0
var breath := 60.0

var _head_node: Node3D
var _water_blend := 0.0
var _bob_time := 0.0
var _pivot_base_pos: Vector3

const WEAPON_DAMAGE := {
	1: 20,
	2: 25,
	3: 34
}

var weapon_tier := 1

func _ready() -> void:
	add_to_group("player")

	breath = breath_max
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	emit_signal("breath_updated", breath, breath_max)
	emit_signal("collectables_changed", collectables)

	print("total collectables: ", collectables)

	_head_node = get_node(head_node_path) as Node3D
	_pivot_base_pos = camera_pivot.position



func set_in_water(v: bool) -> void:
	if v == IS_IN_WATER:
		return

	IS_IN_WATER = v
	emit_signal("water_state_changed", IS_IN_WATER)

	# If we just entered water, avoids popping upward from existing velocity
	if IS_IN_WATER:
		velocity.y = min(velocity.y, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return

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

	if IS_IN_WATER:
		_swim_move(wish_dir, delta)
	else:
		_land_move(wish_dir, delta)

	# --- Interaction ---
	if ray_cast_3d.is_colliding() and Input.is_action_just_pressed("interact"):
		var collider = ray_cast_3d.get_collider()
		if collider.has_method("_on_interact"):
			collider._on_interact(self)
	
		if collider.is_in_group("collectable"):
			print("total collectables: ", self.collectables)
		elif collider.is_in_group("interactable"):
			print("interactable encountered")
		elif collider.is_in_group('holdable'):
			if IS_HOLDING_ITEM == false:
				self.IS_HOLDING_ITEM = true
				self.pickup_throw._pick_up(collider)
				if collider.is_in_group('weapon'):
					collider.connect('enemy_hit', _on_weapon_hitbox_t_1_body_entered)
		
	if Input.is_action_pressed("throw") and IS_HOLDING_ITEM:
		self.pickup_throw._charge_throw(delta)
	
	if Input.is_action_just_released('throw') and IS_HOLDING_ITEM:
		var held_item = self.get_node('CameraPivot/Camera3D/HoldPoint').get_child(0)
		self.pickup_throw._throw(held_item)
		self.IS_HOLDING_ITEM = false
	
	# --- Combat ---
	if Input.is_action_just_pressed("attack") and IS_HOLDING_ITEM:
		var weapon = self.get_node('CameraPivot/Camera3D/HoldPoint').get_child(0)
		if weapon.is_in_group('weapon'):
			anim_player.play("attack")
			weapon.find_child('Hitbox').monitoring = true

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
	var target := wish_dir * swim_speed
	velocity.x = move_toward(velocity.x, target.x, swim_accel * delta)
	velocity.y = move_toward(velocity.y, target.y, swim_accel * delta)
	velocity.z = move_toward(velocity.z, target.z, swim_accel * delta)


func _update_breath(delta: float) -> void:
	if IS_IN_WATER:
		breath = max(0.0, breath - delta)
		if breath <= 0.0:
			emit_signal("drowned")
	else:
		# Fast breath refill when player gets air
		breath = min(breath_max, breath + breath_recover_rate * delta)

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


func _on_weapon_hitbox_t_1_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy") && body.has_method("apply_damage"):
		var damage: int = WEAPON_DAMAGE.get(weapon_tier, 10)		
		body.apply_damage(damage)
		print("Enemy hit!")
		var weapon = self.get_node('CameraPivot/Camera3D/HoldPoint').get_child(0)
		weapon.find_child('Hitbox').set_deferred('monitoring', false)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == 'attack':
		anim_player.play('idle')
		var weapon = self.get_node('CameraPivot/Camera3D/HoldPoint').get_child(0)
		weapon.find_child('Hitbox').monitoring = false
