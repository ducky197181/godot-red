extends Area2D

@export var damage:int = 1

func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.has_method("hit"):
			body.hit(null, "damage")
