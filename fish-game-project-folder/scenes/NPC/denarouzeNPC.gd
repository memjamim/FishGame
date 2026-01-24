extends CharacterBody3D

const speed = 0
var current_state = SIDE_LEFT

var is_chatting = false

var start_pos
var player_in_range = false

@export var player_path: NodePath
var player: CharacterBody3D

enum {
	IDLE
}

func _ready():
	player = get_node(player_path)
	randomize()
	start_pos = position


func _process(_delta):
	if player == null:
		print("No player")
		return

	if Input.is_action_just_pressed("interact") && player_in_range == true:
		$DialogueUI.start()
		is_chatting = true



func _on_dialogue_ui_dialogue_finished() -> void:
	is_chatting = false

func _on_interaction_radius_body_entered(body: Node3D) -> void:
	if body == player:
		player_in_range = true


func _on_interaction_radius_body_exited(body: Node3D) -> void:
	if body == player:
		is_chatting = false
		player_in_range = false
