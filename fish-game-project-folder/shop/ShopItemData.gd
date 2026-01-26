extends Resource
class_name ShopItemData

enum EffectType {
	NONE,
	MAX_HEALTH_ABSOLUTE,
	BREATH_BONUS,
	UNLOCK_FLASHLIGHT,
	UNLOCK_MINI_RADIO,
	FLIPPER_MULTIPLIER,
}

@export var flipper_speed_multiplier: float = 1.0

@export var display_scene: PackedScene        # what appears in the shop slot
@export var grant_scene: PackedScene          # what you actually give the player (if weapon or holdable)
@export var is_weapon: bool = false           # controls how we grant it
@export var item_id: String = ""
@export var family_id: String = ""
@export var tier: int = 1
@export var cost: int = 0
@export var display_name: String = ""
@export var icon: Texture2D

@export var effect_type: EffectType = EffectType.NONE

# Use only what you need per item:
@export var max_health_value: int = 0
@export var breath_bonus_seconds: float = 0.0
@export var unlocks_flashlight: bool = false

func is_available_for(player) -> bool:
	return player.get_owned_tier(family_id) == (tier - 1)

func apply_to(player) -> void:
	player.set_owned_tier(family_id, tier)

	match effect_type:
		EffectType.MAX_HEALTH_ABSOLUTE:
			if max_health_value > 0:
				player.apply_max_health_bonus(max_health_value)

		EffectType.BREATH_BONUS:
			player.apply_breath_max_bonus(breath_bonus_seconds)

		EffectType.UNLOCK_FLASHLIGHT:
			if unlocks_flashlight and player.has_method("set_flashlight_unlocked"):
				player.set_flashlight_unlocked(true)
				
		EffectType.UNLOCK_MINI_RADIO:
			if player.has_method("unlock_mini_radio"):
				player.unlock_mini_radio()

		EffectType.FLIPPER_MULTIPLIER:
			if player.has_method("apply_flipper_multiplier"):
				player.apply_flipper_multiplier(flipper_speed_multiplier)

		_:
			pass
