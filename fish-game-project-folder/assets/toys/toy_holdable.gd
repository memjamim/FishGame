extends Node3D

@onready var player := $"../Player"
@onready var level := $".."

var sell_value := 100
var targeted := false : set = _set_targeted

var mesh_options: Array[MeshInstance3D] = []
var mesh_instance: MeshInstance3D
var hover_material: ShaderMaterial

func _ready() -> void:
	randomize()
	_collect_meshes()
	_pick_random_mesh()
	_random_y_rotation()

func _collect_meshes() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false
			mesh_options.append(child)

func _pick_random_mesh() -> void:
	if mesh_options.is_empty():
		push_error("Toy has no mesh options!")
		return

	mesh_instance = mesh_options.pick_random()
	mesh_instance.visible = true
	_setup_shader()

func _setup_shader() -> void:
	var mat := mesh_instance.get_active_material(0)
	if mat == null:
		return

	mat = mat.duplicate()
	mesh_instance.set_surface_override_material(0, mat)

	if mat.next_pass is ShaderMaterial:
		hover_material = mat.next_pass
		hover_material.set_shader_parameter("strength", 0.0)

func _set_targeted(val: bool) -> void:
	targeted = val
	if hover_material:
		hover_material.set_shader_parameter(
			"strength",
			0.5 if targeted else 0.0
		)

func _random_y_rotation() -> void:
	rotate_y(randf_range(-PI, PI))

func sell() -> void:
	sell_value = randi_range(100, 300)
	player.collectables += sell_value
	level._on_toy_sold()
	queue_free()
