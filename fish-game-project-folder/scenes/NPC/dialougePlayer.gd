extends Control

signal dialogue_finished 

@export_file("*.json") var d_file

var dialogue = []
var current_dialogue_id = 0
var d_active = false
var scholarMet = false

var typing = false
var auto_advance = false

var full_text = ""
var current_text = ""
var text_index = 0
var typewriter_speed = 0.05
var auto_advance_delay = 0.4  # pause after line finishes

func _ready():
	$NinePatchRect.visible = false

func start():
	if d_active:
		return
	d_active = true
	auto_advance = false
	$NinePatchRect.visible = true
	dialogue = load_dialogue()
	current_dialogue_id = -1
	scholarMet = true
	next_script()

func load_dialogue():
	var file = FileAccess.open("res://scenes/NPC/denarouze_dialogue.json", FileAccess.READ)
	var content = JSON.parse_string(file.get_as_text())
	return content["intro"]

func _input(event):
	if !d_active:
		return

	if event.is_action_pressed("interact"):
		# First press enables auto-advance
		auto_advance = true

		# If currently typing, instantly finish current line
		if typing:
			typing = false
			current_text = full_text
			$NinePatchRect/Text.text = full_text

func next_script():
	current_dialogue_id += 1

	if current_dialogue_id >= dialogue.size():
		end_dialogue()
		return

	$NinePatchRect/Name.text = dialogue[current_dialogue_id]["name"]
	full_text = dialogue[current_dialogue_id]["text"]
	current_text = ""
	text_index = 0
	typing = true

	type_text()

func type_text():
	if text_index < full_text.length() and typing:
		current_text += full_text[text_index]
		$NinePatchRect/Text.text = current_text
		text_index += 1
		get_tree().create_timer(typewriter_speed).timeout.connect(type_text)
	else:
		typing = false

		# AUTO ADVANCE once line finishes
		if auto_advance:
			get_tree().create_timer(auto_advance_delay).timeout.connect(next_script)

func end_dialogue():
	d_active = false
	auto_advance = false
	$NinePatchRect.visible = false
	emit_signal("dialogue_finished")
