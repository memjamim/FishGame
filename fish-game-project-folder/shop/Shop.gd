extends Node3D
class_name Shop

@export var pickup_scene: PackedScene
@export var shop_items: Array[ShopItemData] = []
@export var slots_path: NodePath = NodePath("Slots")

@onready var slots_root: Node3D = get_node(slots_path) as Node3D
var _spawned: Array[Node] = []

func _ready() -> void:
	print("[Shop] ready. slots_root=", slots_root, " children=", slots_root.get_child_count())
	call_deferred("_try_refresh")

func _try_refresh() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	print("[Shop] found player? ", player)
	if player != null:
		refresh(player)

func refresh(player: CharacterBody3D) -> void:
	print("[Shop] refresh called")
	_clear_spawned()

	if pickup_scene == null:
		push_error("[Shop] pickup_scene is null.")
		return

	var available := _get_available_items(player)
	available.shuffle()

	var slot_nodes := slots_root.get_children()
	var count: int = mini(mini(available.size(), slot_nodes.size()), 3)
	print("[Shop] spawning count=", count)

	for i in range(count):
		var slot := slot_nodes[i] as Node3D
		var item: ShopItemData = available[i]

		var inst = pickup_scene.instantiate()
		if inst == null:
			push_error("[Shop] pickup_scene.instantiate() returned null. Check errors from ShopPickup.tscn/scripts.")
			return

		slot.add_child(inst)

		var sp := inst as ShopPickup
		if sp == null:
			push_error("[Shop] Instanced root is not ShopPickup. Ensure ShopPickup.tscn root is StaticBody3D with ShopPickup.gd.")
			inst.queue_free()
			continue

		sp.item_data = item
		sp.set_shop(self)
		sp.global_transform = slot.global_transform
		_spawned.append(sp)

	print("[Shop] done. _spawned size=", _spawned.size())

func _get_available_items(player: CharacterBody3D) -> Array[ShopItemData]:
	var out: Array[ShopItemData] = []
	for item in shop_items:
		if item != null and item.is_available_for(player):
			out.append(item)
	return out

func _clear_spawned() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()
