extends StaticBody3D
class_name ShopPickup

@export var item_data: ShopItemData
var shop: Shop = null

func set_shop(s: Shop) -> void:
	shop = s

func _ready() -> void:
	# visibility sanity
	var mi := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mi and mi.mesh == null:
		mi.mesh = BoxMesh.new()

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
		item_data.apply_to(player)
		print("Bought: ", item_data.display_name)
		if shop != null:
			shop.refresh(player)
