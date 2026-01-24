extends Resource
class_name ShopItemData

@export var item_id: String = ""         # unique id like "wetsuit_t1"
@export var family_id: String = ""       # "wetsuit" for wetsuits
@export var tier: int = 1
@export var cost: int = 0
@export var display_name: String = ""
@export var icon: Texture2D

# For the wetsuit test:
@export var max_health_value: int = 100  # absolute max health after buying this tier

func is_available_for(player) -> bool:
	# Only shows the next tier
	# If player owns tier 0 -> tier 1 available
	# If owns tier 1 -> tier 2 available, etc...
	return player.get_owned_tier(family_id) == (tier - 1)

func apply_to(player) -> void:
	# Mark ownership tier
	player.set_owned_tier(family_id, tier)
	# Apply effect (for wetsuit only for now)
	player.apply_max_health_bonus(max_health_value)
