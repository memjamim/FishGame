extends StaticBody3D

@onready var slide_camera: Camera3D = $Path3D/PathFollow3D/SlideCamera
@onready var path_follow_3d: PathFollow3D = $Path3D/PathFollow3D
@onready var path_3d: Path3D = $Path3D

var CAN_SLIDE: bool = false
var IS_SLIDING: bool = false

var t: float = 0.0
@export var slide_speed: float = 0.3
var saved_player: CharacterBody3D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.slide_camera.current = false
	path_follow_3d.progress_ratio = 0.0
	path_follow_3d.rotation_mode = PathFollow3D.ROTATION_ORIENTED


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if IS_SLIDING:
		t += delta * slide_speed
		t = clamp(t, 0.0, 1.0)
		path_follow_3d.progress_ratio = ease(t, -2.0)
		
		if t >= 1.0:
			IS_SLIDING = false
			_finish_sliding(self.saved_player)


func _on_interact(player: CharacterBody3D = null) -> void:
	if not CAN_SLIDE or player == null:
		return
	
	self.saved_player = player
	CAN_SLIDE = false
	t = 0.0
	path_follow_3d.progress_ratio = 0.0
	
	var camera = player.find_child('Camera3D')
	if camera:
		camera.current = false
		self.slide_camera.current = true
	
	player.PAUSE_MOVEMENT = true
	IS_SLIDING = true


func _finish_sliding(player: CharacterBody3D) -> void:
	var player_camera: Camera3D = player.find_child("Camera3D")
	var head: Node3D = player_camera.get_parent() # CameraPivot / Head
	
	player.global_position = path_3d.curve.get_point_position(6) \
		+ path_3d.position - Vector3(0, 1.5, 0)
	
	var forward := slide_camera.global_transform.basis.z
	var yaw := atan2(forward.x, forward.z)
	player.rotation.y = yaw

	head.rotation.x = 0.0
	player_camera.rotation = Vector3.ZERO
	
	slide_camera.current = false
	player_camera.current = true
	
	player.PAUSE_MOVEMENT = false
	CAN_SLIDE = true


func _on_interact_area_body_entered(body: Node3D) -> void:
	if body.name == 'Player':
		CAN_SLIDE = true


func _on_interact_area_body_exited(body: Node3D) -> void:
	if body.name == 'Player':
		CAN_SLIDE = false
