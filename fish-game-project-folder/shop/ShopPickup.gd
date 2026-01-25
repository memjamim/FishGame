extends StaticBody3D
class_name ShopPickup

@export var item_data: ShopItemData
var shop: Shop = null
var slot: Node3D = null
var _is_processing_purchase := false


@onready var model_root: Node3D = $ModelRoot

func set_shop(s: Shop) -> void:
	shop = s

func set_slot(s: Node3D) -> void:
	slot = s

func _ready() -> void:
	_apply_display_model()

func _apply_display_model() -> void:
	if model_root == null:
		return

	# Clear old model immediately
	for c in model_root.get_children():
		model_root.remove_child(c)

		if c is RigidBody3D:
			var rb := c as RigidBody3D
			rb.freeze = true
			rb.gravity_scale = 0.0
			rb.linear_velocity = Vector3.ZERO
			rb.angular_velocity = Vector3.ZERO
			rb.collision_layer = 0
			rb.collision_mask = 0

		c.queue_free()

	if item_data == null:
		return

	print("[DisplayModel] item=", item_data.item_id,
		" display_scene=",
		(item_data.display_scene.resource_path if item_data.display_scene else "null"))

	# Instance item-specific display scene
	if item_data.display_scene != null:
		var m := item_data.display_scene.instantiate()
		model_root.add_child(m)

		# If someone used a physics scene as display, neutralize it
		if m is RigidBody3D:
			var rb2 := m as RigidBody3D
			rb2.freeze = true
			rb2.gravity_scale = 0.0
			rb2.linear_velocity = Vector3.ZERO
			rb2.angular_velocity = Vector3.ZERO
			rb2.collision_layer = 0
			rb2.collision_mask = 0
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		model_root.add_child(mi)


func _on_interact(player) -> void:
	print("[ShopPickup] interact called on ", self.name, " item=", item_data.item_id, " frame=", Engine.get_frames_drawn())
	if _is_processing_purchase:
		return
	_is_processing_purchase = true
	call_deferred("_reset_purchase_lock")

	if item_data == null:
		return
	if not item_data.is_available_for(player):
		print("Not available yet.")
		return
	if not player.can_afford(item_data.cost):
		print("Not enough coins.")
		return

	if player.spend_coins(item_data.cost):
		# Register icon before inventory signal triggers UI rebuild
		if item_data.icon != null and player.has_method("register_shop_item_icon"):
			player.register_shop_item_icon(item_data.family_id, item_data.tier, item_data.icon)

		# Apply stat/unlock effects
		item_data.apply_to(player)

		# Grant actual item (weapon/holdable) if configured
		_grant_item_to_player(player)

		print("Bought: ", item_data.display_name)

		if shop != null:
			shop.on_item_bought(player, slot) if shop.has_method("on_item_bought") else shop.refresh(player)

func _reset_purchase_lock() -> void:
	_is_processing_purchase = false

func _grant_item_to_player(player) -> void:
	if item_data == null or item_data.grant_scene == null:
		return

	var inst: Node = item_data.grant_scene.instantiate()
	var rb := inst as RigidBody3D
	if rb == null:
		push_warning("[ShopPickup] grant_scene root is not RigidBody3D for item_id=" + item_data.item_id)
		inst.queue_free()
		return

	if item_data.is_weapon:
	# Hard replace: delete any currently held weapon (do NOT throw it)
		var hold_point := player.get_node("CameraPivot/Camera3D/HoldPoint") as Node3D
		if hold_point and hold_point.get_child_count() > 0:
			var old := hold_point.get_child(0)
			old.queue_free()
			player.IS_HOLDING_WEAPON = false
		player.IS_HOLDING_WEAPON = true
		player.pickup_throw._pick_up(rb)
	# connect hitbox if needed
		if rb.has_signal("enemy_hit") and not rb.is_connected("enemy_hit", player._on_weapon_hitbox_t_1_body_entered):
			rb.connect("enemy_hit", player._on_weapon_hitbox_t_1_body_entered)


	else:
		if player.IS_HOLDING_ITEM:
			rb.queue_free()
			return
		player.IS_HOLDING_ITEM = true
		player.pickup_throw._pick_up(rb)
