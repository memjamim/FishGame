extends Node3D

@onready var cooldown_timer: Timer = $CooldownTimer

var CAN_INTERACT: bool = true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_interact(player: CharacterBody3D = null) -> void:
	if player.IS_IN_WATER:
		if CAN_INTERACT:
			player.velocity.y += 5
			CAN_INTERACT = false
			cooldown_timer.start()


func _on_cooldown_timer_timeout() -> void:
	CAN_INTERACT = true
