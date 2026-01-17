extends CharacterBody3D

@onready var ray_cast_3d: RayCast3D = $Node3D/Camera3D/RayCast3D

var collectables: int = 0

var IS_IN_WATER: bool = false

const SPEED = 5.0
const JUMP_VELOCITY = 4.5


func _ready() -> void:
	print('total collectables: ', self.collectables)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not IS_IN_WATER:
		if not is_on_floor():
			velocity += get_gravity() * delta
		# Handle jump.
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "foward", "back")
	
	# If we're in water, use Space and Shift to move up and down.
	# Else, cant move up and down with controlls. Velocity is controlled by jump
	var up_down_dir
	if IS_IN_WATER:
		up_down_dir = Input.get_axis("down", "up")
	else:
		up_down_dir = 0
	
	# Sets the direction of movement based on input_dir and up_down_dir
	var direction := (transform.basis * Vector3(input_dir.x, up_down_dir, input_dir.y)).normalized()
	
	# Set speed in the direction
	# If in water, y direction is considered as well
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		if IS_IN_WATER:
			velocity.y = direction.y * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		if IS_IN_WATER:
			velocity.y = move_toward(velocity.y, 0, SPEED)
	
	move_and_slide()
	
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
