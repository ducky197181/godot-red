extends RigidBody2D

@export var damage: int = 1

var command_obj : Dictionary

func _ready() -> void:
	command_obj = {
		"damage": damage,
		"source": self
	}
	command_obj.make_read_only()


func _on_body_entered(body: Node) -> void:
	if body.has_method("command"):
		body.command(command_obj)
	queue_free()
