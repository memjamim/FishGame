extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	pass 

#10-30 Small
#30-70 Medium
#70-100
func _on_interact(player: CharacterBody3D) -> void:
	var value = randi_range(30, 70)
	player.collectables += value
	self.queue_free()
