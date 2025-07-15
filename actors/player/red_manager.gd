extends Node2D

func _on_red_shoot(bullet: PackedScene, spawn_point: Transform2D, timer: float) -> void:
	var instance: Node2D = bullet.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	add_child(instance, false, Node.INTERNAL_MODE_DISABLED)
	instance.global_transform = spawn_point
	instance.reset_physics_interpolation()

	if instance.has_method("set_moving_target"):
		var red : CharacterBody2D = $Red
		var vel = red.velocity.length()
		instance.set_moving_target(red, vel, timer)
