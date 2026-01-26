extends Node3D


func _on_holdable_hitbox_body_entered(body: Node3D) -> void:
	if body.is_in_group("holdable") && body.has_method("sell"):
		body.sell()
		
		
