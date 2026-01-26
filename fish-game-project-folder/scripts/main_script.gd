extends WorldEnvironment

@export var toys_to_advance := 3
@export var toy_scene: PackedScene
@export var t1_enemy_scene: PackedScene
@export var t2_enemy_scene: PackedScene
@onready var player = $Player
@onready var poolCover = $PoolCorner

# Enemy spawn variables
@export var enemies_per_wave := 4
@export var tier2_base_chance := 0.2
@export var tier2_chance_per_level := 0.05
@export var tier2_max_chance := 0.8

var enemy_spawn_points := {} 
var active_enemies: Array[Node3D] = []

var current_level = 1
var toys_sold_this_level = 0

var spawn_points := {}  

func _ready() -> void:
	_collect_spawn_points()
	_collect_enemy_spawn_points()
	spawn_toy()

	
func _collect_spawn_points() -> void:
	spawn_points.clear()

	for child in $ItemSpawnPoints.get_children():
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
		
func _collect_enemy_spawn_points() -> void:
	enemy_spawn_points.clear()

	for child in $EnemySpawnPoints.get_children():
		if not child is Marker3D:
			continue

		var name_parts := child.name.split("_")
		if name_parts.size() < 2:
			continue

		var tier_part := name_parts[0] # "T1" or "T2"
		if !tier_part.begins_with("T"):
			continue

		var tier := tier_part.substr(1).to_int()
		if tier <= 0:
			continue

		if !enemy_spawn_points.has(tier):
			enemy_spawn_points[tier] = []

		enemy_spawn_points[tier].append(child)

func spawn_enemies() -> void:
	clear_enemies()

	if current_level < 2:
		return

	var tier2_chance := clamp(
		tier2_base_chance + (current_level - 3) * tier2_chance_per_level,
		0.0,
		tier2_max_chance
	) as float


	for i in enemies_per_wave:
		var spawn_tier := 1

		if current_level >= 3 and randf() < tier2_chance:
			spawn_tier = 2

		_spawn_enemy(spawn_tier)
		
func _spawn_enemy(tier: int) -> void:
	var scene: PackedScene
	var points: Array

	if tier == 2 and enemy_spawn_points.has(2):
		scene = t2_enemy_scene
		points = enemy_spawn_points[2]
	else:
		scene = t1_enemy_scene
		points = enemy_spawn_points.get(1, [])

	if scene == null or points.is_empty():
		return

	var spawn_point: Marker3D = points.pick_random()
	var enemy: Node3D = scene.instantiate()
	enemy.global_transform = spawn_point.global_transform
	enemy.player = player
	add_child(enemy)
	active_enemies.append(enemy)

	
func spawn_toy() -> void:
	if toy_scene == null:
		push_error("Toy scene is null! Assign it in the Inspector.")
		return

	var spawn_point: Marker3D

	if spawn_points.has(current_level):
		var points: Array = spawn_points[current_level]
		spawn_point = points.pick_random()
	else:
		var all_points := []
		for pts in spawn_points.values():
			all_points += pts
		spawn_point = all_points.pick_random()

	var new_toy: Node3D = toy_scene.instantiate()
	new_toy.global_transform = spawn_point.global_transform
	add_child(new_toy)
	
func _on_toy_sold() -> void:
	toys_sold_this_level += 1

	if toys_sold_this_level >= toys_to_advance:
		toys_sold_this_level = 0
		current_level += 1
		
		if current_level == 2 and is_instance_valid(poolCover):
			poolCover.queue_free()

	spawn_toy()
	spawn_enemies()

func clear_enemies() -> void:
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
