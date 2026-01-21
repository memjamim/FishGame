extends RayCast3D

var looking_at = null

func _process(delta: float) -> void:
	var collider = get_collider()
	
	if collider != looking_at:
		if collider != null and 'targeted' in collider:
			collider.targeted = true
		if looking_at != null and 'targeted' in looking_at:
			looking_at.targeted = false
		
		looking_at = collider
