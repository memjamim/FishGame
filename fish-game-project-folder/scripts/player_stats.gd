extends Node

# --- Land Movement ---
@export var land_move_speed: float = 5.0
@export var jump_impulse: float = 4.5

# --- Water Movement ---
@export var swim_speed: float = 3.0
@export var swim_accel: float = 6.0
@export var swim_drag: float = 3.5
@export var bouancy: float = 1.5
@export var dash_impulse: float = 6.0
@export var dash_drag: float = 4.5 				# Optional. Use swim_drag instead?

# --- Breath Stats ---
@export var breath_max: float = 60.0 			# seconds
@export var breath_recover_rate: float = 20.0

# --- Other ---
@export var reach: float = -3.0					# meters
@export var weapon_damage: float = 0			# Kept in weapon instead?


# Example for stat-changing function called when the player purchases an item?
# Optional parameters in case we want flat increase or percent increase
func _change_reach(interact_raycast: RayCast3D, reach_increase: float = 0, reach_increase_percent: float = 0) -> void:
	if reach_increase_percent != 0:
		self.reach *= (1+reach_increase_percent)
	elif reach_increase != 0:
		self.reach -= reach_increase
	
	interact_raycast.target_position.z = self.reach
