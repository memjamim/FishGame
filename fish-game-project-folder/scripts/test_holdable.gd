extends Node3D

# --- Hover Shader --- #
# Use this code on an object you want to change color slightly when you look at it and can interact with it
# shader = $MeshInstance3D.blah.blah.blah the $MeshInstance is the mesh of the opject
# In that mesh, go into the material and in 'Next Pass', add the shader that is in the shaders folder in the art folder
# Then add the rest of this code to the object and done
# The color of the shader can be changed by opening the shader and changing the albedo vec3 values (RGB)
@onready var shader = $MeshInstance3D.mesh.material.next_pass
@onready var player := $"../Player"
@onready var level := $".."
@export var sell_value = 10

var targeted = false : set = _set_targeted

func _set_targeted(val):
	targeted = val
	if targeted:
		shader.set_shader_parameter('strength', 0.5)
	else:
		shader.set_shader_parameter('strength', 0.0)
		
func sell():
	player.collectables += sell_value
	level._on_toy_sold()
	self.queue_free()
