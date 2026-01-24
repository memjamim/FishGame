extends Node3D
class_name ShopPickup

@export var item_data: ShopItemData
@export var shop_path: NodePath          # assign the Shop node in inspector

@onready var shop = get_node(shop_path)

func _on_interact(player) -> void:
	if item_data == null:
		return

	# Availability gate (tiered)
	if not item_data.is_available_for(player):
		print("Not available yet.")
		return

	# Cost gate
	if not player.can_afford(item_data.cost):
		print("Not enough coins.")
		return

	# Spend + apply
	if player.spend_coins(item_data.cost):
		item_data.apply_to(player)
		print("Bought: ", item_data.display_name)

		# Refresh shop items immediately
		if shop and shop.has_method("refresh"):
			shop.refresh(player)
