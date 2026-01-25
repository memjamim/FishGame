extends StaticBody3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_breath_refill_area_body_entered(body: Node3D) -> void:
	if body.name == 'Player':
		body.IS_IN_CORAL = true


func _on_breath_refill_area_body_exited(body: Node3D) -> void:
	if body.name == 'Player':
		body.IS_IN_CORAL = false
