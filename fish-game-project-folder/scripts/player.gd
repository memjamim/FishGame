extends CharacterBody3D

# --- Interaction ---
@onready var ray_cast_3d: RayCast3D = $CameraPivot/Camera3D/RayCast3D

var collectables: int = 0

var IS_IN_WATER: bool = false

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
@export var breath_max := 60.0            # 1:00 breath time
@export var breath_recover_rate := 180.0  # recovery on land
@export var breath_ui_path: NodePath
signal breath_updated(current: float, max_value: float)
signal drowned

@onready var camera_pivot: Node3D = $CameraPivot

var _pitch := 0.0
var breath := 60.0

func _ready() -> void:
	breath = breath_max
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("breath_updated", breath, breath_max)

func set_in_water(v: bool) -> void:
	IS_IN_WATER = v
	if IS_IN_WATER:
		velocity.y = min(velocity.y, 0.0)

func _unhandled_input(event: InputEvent) -> void:
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

func _ready() -> void:
	print('total collectables: ', self.collectables)

func _physics_process(delta: float) -> void:
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

	# If the raycast sees an object, the player presses E, and the object is a collectable
	if (
		ray_cast_3d.is_colliding() 
		and Input.is_action_just_pressed("interact") 
		and (ray_cast_3d.get_collider().get_parent().is_in_group('collectable'))
	):
		# Increase the total number of collectables and delete the interacted object
		self.collectables += 1
		print('total collectables: ', self.collectables)
		ray_cast_3d.get_collider().get_parent().queue_free()
		_land_move(wish_dir, delta)

	move_and_slide()

	# --- Interaction ---
	if ray_cast_3d and ray_cast_3d.is_colliding() and Input.is_action_just_pressed("interact"):
		var collider := ray_cast_3d.get_collider()
		print(collider)
		# Optional: if your interactables implement an "interact" method:
		# if collider and collider.has_method("interact"):
		#     collider.interact(self)

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
