extends Node3D
class_name Shop

@export var pickup_scene: PackedScene
@export var shop_items: Array[ShopItemData] = []
@export var slots_path: NodePath = NodePath("Slots")

@onready var slots_root: Node3D = get_node(slots_path) as Node3D
var _spawned: Array[Node] = []
var _queue: Array[ShopItemData] = []
var _slot_to_pickup: Dictionary = {} # slot Node3D -> ShopPickup

func init_shop(player: CharacterBody3D) -> void:
	_queue = _get_available_items(player)
	_queue.shuffle()

	var slot_nodes := slots_root.get_children()
	for slot_node in slot_nodes:
		_fill_slot(slot_node as Node3D, player)


func _fill_slot(slot: Node3D, player: CharacterBody3D) -> void:
	# remove existing
	if _slot_to_pickup.has(slot) and is_instance_valid(_slot_to_pickup[slot]):
		_slot_to_pickup[slot].queue_free()
	_slot_to_pickup.erase(slot)

	if _queue.is_empty():
		return

	var item: ShopItemData = _queue.pop_front()

	var inst = pickup_scene.instantiate()
	var sp := inst as ShopPickup
	if sp == null:
		push_error("[Shop] ShopPickup.tscn root is not ShopPickup")
		inst.queue_free()
		return

	slot.add_child(sp)
	sp.global_transform = slot.global_transform
	sp.item_data = item
	sp.set_slot(slot)
	sp.call_deferred("_apply_display_model")

	sp.set_shop(self)
	sp.set_slot(slot)
	_slot_to_pickup[slot] = sp


func _ready() -> void:
	print("[Shop] ready. slots_root=", slots_root, " children=", slots_root.get_child_count())
	call_deferred("_try_refresh")

func _try_refresh() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	print("[Shop] weapon owned tier =", player.get_owned_tier("weapon"), " raw=", player.owned_shop_items.get("weapon", "none"))

	if player != null:
		init_shop(player)

func on_item_bought(player: CharacterBody3D, slot: Node3D) -> void:
	# Add any new items that just became available (wetsuit_t2 when wetsuit_t1 is bought)
	var newly_available := _get_available_items(player)
	
	# But don't re-add items already in queue or currently displayed
	var existing_ids: Dictionary = {}
	for it in _queue:
		existing_ids[it.item_id] = true
	for s in _slot_to_pickup.keys():
		var p := _slot_to_pickup[s] as ShopPickup
		if p != null and p.item_data != null:
			existing_ids[p.item_data.item_id] = true
	
	for it in newly_available:
		if not existing_ids.has(it.item_id):
			_queue.append(it)

	_fill_slot(slot, player)



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
