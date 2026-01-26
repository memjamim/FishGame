extends Control

signal dialogue_finished 

@export_file("*.json") var d_file

var dialogue = []
var current_dialogue_id = 0
var d_active = false

# Dialogue conditionals
var diver_met = false
var played_shop_intro := false
var played_eelbert_intro := false
var intro_completed := false
var played_post_game := false

var played_last_level_1 := false
var played_last_level_2 := false
var played_last_level_3 := false

enum DialogueState {
	IDLE,
	TYPING,
	WAITING
}

var state := DialogueState.IDLE
var skip_requested := false
var auto_play := false

var typing = false
var auto_advance = false

var full_text = ""
var current_text = ""
var text_index = 0
var typewriter_speed = 0.05
var auto_advance_delay = 1.0  # pause after line finishes

@onready var level = $"../.."

func _ready():
	$NinePatchRect.visible = false

func start():
	if d_active:
		return
	d_active = true
	auto_play = true
	$NinePatchRect.visible = true
	dialogue = load_dialogue()
	current_dialogue_id = -1
	next_script()

func load_dialogue():
	var file = FileAccess.open("res://scenes/NPC/denarouze_dialogue.json", FileAccess.READ)
	var content = JSON.parse_string(file.get_as_text())

	# ─────────────────────────────
	# FIRST INTERACTION
	# ─────────────────────────────
	if !diver_met:
		diver_met = true
		intro_completed = true
		return content["intro"]

	# ─────────────────────────────
	# SHOP INTRO
	# ─────────────────────────────
	if !played_shop_intro:
		played_shop_intro = true
		return content["shop-intro"]

	# ─────────────────────────────
	# EELBERT INTRO
	# ─────────────────────────────
	if !played_eelbert_intro:
		played_eelbert_intro = true
		return content["eelbert-intro"]

	# ─────────────────────────────
	# TOY-BASED MILESTONES
	# ─────────────────────────────
	match level.current_level:
		1:
			if level.toys_sold_this_level == 1:
				return content["first-level-1-toy-sold"]

		2:
			if !played_last_level_1:
				played_last_level_1 = true 
				return content["last-level-1-toy-sold"]
			if level.toys_sold_this_level == 1:
				return content["first-level-2-toy-sold"]
			if level.toys_sold_this_level == level.toys_to_advance:
				return content["last-level-2-toy-sold"]

		3:
			if !played_last_level_2:
				played_last_level_2 = true 
				return content["last-level-2-toy-sold"]
			if level.toys_sold_this_level == 1:
				return content["first-level-3-toy-sold"]
			if level.toys_sold_this_level == level.toys_to_advance:
				return content["last-level-3-toy-sold"]

	# ─────────────────────────────
	# POST GAME
	# ─────────────────────────────
	if level.current_level == 4 and !played_last_level_3:
		played_last_level_3 = true
		return content["last-level-3-toy-sold"]
	
	if level.current_level > 3:
		if !played_post_game:
			played_post_game = true
			return content["past-last-level-3-toy-sold"]
		else:
			var post_game_options := [
				content["post-game-1"],
				content["post-game-2"],
				content["post-game-3"]
			]
			return post_game_options.pick_random()

	# ─────────────────────────────
	# FALLBACK
	# ─────────────────────────────
	return content["generic"]

func _unhandled_input(event: InputEvent):
	
	if get_tree().paused:
		return

	if !d_active:
		return

	if event.is_action_pressed("interact"):
		print("e_pressed")
		match state:
			DialogueState.TYPING:
				print("skip requested")
				skip_requested = true
			DialogueState.WAITING:
				next_script()

func next_script() -> void:
	if state == DialogueState.TYPING:
		return

	current_dialogue_id += 1

	if current_dialogue_id >= dialogue.size():
		end_dialogue()
		return

	var line = dialogue[current_dialogue_id]
	$NinePatchRect/Name.text = line["name"]
	full_text = line["text"]

	await type_text()


func type_text() -> void:
	state = DialogueState.TYPING
	skip_requested = false
	current_text = ""
	text_index = 0

	while text_index < full_text.length():
		if skip_requested:
			break

		current_text += full_text[text_index]
		$NinePatchRect/Text.text = current_text
		text_index += 1
		await get_tree().create_timer(typewriter_speed, false).timeout

	# Finish line instantly if skipped
	$NinePatchRect/Text.text = full_text
	state = DialogueState.WAITING

	if auto_play:
		await get_tree().create_timer(auto_advance_delay, false).timeout
		next_script()


func end_dialogue():
	state = DialogueState.IDLE
	d_active = false
	skip_requested = false
	$NinePatchRect.visible = false
	emit_signal("dialogue_finished")
