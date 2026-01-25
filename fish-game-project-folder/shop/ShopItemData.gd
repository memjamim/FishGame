extends Resource
class_name ShopItemData

@export var item_id: String = ""
@export var family_id: String = ""
@export var tier: int = 1
@export var cost: int = 0
@export var display_name: String = ""
@export var icon: Texture2D
@export var max_health_value: int = 0
@export var unlocks_flashlight: bool = false


func is_available_for(player) -> bool:
	return player.get_owned_tier(family_id) == (tier - 1)

func apply_to(player) -> void:
	player.set_owned_tier(family_id, tier)

	if max_health_value > 0 and family_id == "wetsuit":
		player.apply_max_health_bonus(max_health_value)

	if unlocks_flashlight and player.has_method("set_flashlight_unlocked"):
		player.set_flashlight_unlocked(true)
