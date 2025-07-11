extends Area2D

@export var damage:int = 1
var hit_dictionary : Dictionary

func _ready() -> void:
	hit_dictionary = {
		"damage": damage
	}
	hit_dictionary.make_read_only()

func _physics_process(_delta) -> void:
	for body in get_overlapping_bodies():
		if body.has_method("command"):
			body.command(hit_dictionary)
