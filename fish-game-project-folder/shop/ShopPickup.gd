extends StaticBody3D
class_name ShopPickup

@export var item_data: ShopItemData
var shop: Shop = null
var slot: Node3D = null

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

	# Clear old model
	for c in model_root.get_children():
		c.queue_free()

	if item_data == null:
		return

	# Instance item-specific display scene
	if item_data.display_scene != null:
		var m := item_data.display_scene.instantiate()
		model_root.add_child(m)
	else:
		# Fallback debug cube
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		model_root.add_child(mi)

func _on_interact(player) -> void:
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

func _grant_item_to_player(player) -> void:
	if item_data.grant_scene == null:
		return

	var inst := item_data.grant_scene.instantiate()

	# Weapons / holdables should be RigidBody3D for pickup_throw
	var rb := inst as RigidBody3D
	if rb == null:
		push_warning("Granted scene root is not a RigidBody3D: " + str(inst))
		return

	# Put it in hand
	if item_data.is_weapon:
		if player.IS_HOLDING_WEAPON:
			# optional: you could drop current weapon first, or block purchase
			print("Already holding a weapon.")
			return

		player.IS_HOLDING_WEAPON = true
		player.pickup_throw._pick_up(rb)
		# connect hitbox signal if needed
		if rb.has_signal("enemy_hit") and not rb.is_connected("enemy_hit", player._on_weapon_hitbox_t_1_body_entered):
			rb.connect("enemy_hit", player._on_weapon_hitbox_t_1_body_entered)
	else:
		if player.IS_HOLDING_ITEM:
			print("Already holding an item.")
			return
		player.IS_HOLDING_ITEM = true
		player.pickup_throw._pick_up(rb)
