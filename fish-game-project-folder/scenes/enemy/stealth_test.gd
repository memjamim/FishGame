extends Node3D


@export var toys_to_advance := 3
@export var toy_scene: PackedScene

var current_level = 1
var toys_sold_this_level = 0

var spawn_points := {}  # { level_number : [Marker3D, Marker3D] }

func _ready() -> void:
	_collect_spawn_points()
	spawn_toy()
	
func _collect_spawn_points() -> void:
	spawn_points.clear()

	for child in $SpawnPoints.get_children():
		if not child is Marker3D:
			continue

		var name_parts := child.name.split("_")
		if name_parts.is_empty():
			continue

		var level_part := name_parts[0]
		if not level_part.begins_with("L"):
			continue

		var level_number := level_part.substr(1).to_int()
		if level_number <= 0:
			continue

		if not spawn_points.has(level_number):
			spawn_points[level_number] = []

		spawn_points[level_number].append(child)
	
func spawn_toy() -> void:
	if toy_scene == null:
		push_error("Toy scene is null! Assign it in the Inspector.")
		return

	var points: Array = spawn_points.get(current_level, [])
	if points.is_empty():
		push_error("No spawn points for level %d" % current_level)
		return

	var spawn_point: Marker3D = points.pick_random()

	var new_toy: Node3D = toy_scene.instantiate()
	new_toy.global_transform = spawn_point.global_transform
	add_child(new_toy)


	
func _on_toy_sold() -> void:
	toys_sold_this_level += 1

	if toys_sold_this_level >= toys_to_advance:
		toys_sold_this_level = 0
		current_level += 1

	spawn_toy()
