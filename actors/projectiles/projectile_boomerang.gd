extends Node2D


@onready var projectile : Area2D = $ProjectileA
@onready var target : Node2D = $Marker2D

var moving_target : Node2D
var dir : float = 0.0
var dir_set : bool = false
var age := 0.0
var turnspeed = 6
var speed = 80.0

var command_obj: Dictionary

func _ready() -> void:
	command_obj = {
		"damage": 5
	}

func set_moving_target(tg : Node2D, launch := 0, timer := 1.0):
	timer = lerpf(0.2, 1.0, min(timer, 1.0))
	target.position.x *= timer
	moving_target = tg
	speed += clampf(launch, 20.0, 70.0)

func _physics_process(delta: float) -> void:
	if projectile.position.distance_squared_to(target.position) < 8:
		var global_diff = ((moving_target.global_position + Vector2(randi_range(-1,1), randi_range(-7,-8))) - target.global_position) * 1.5
		if global_diff.length_squared() < 8:
			queue_free()
		target.global_position = target.global_position + global_diff
		turnspeed *= 1.2
		speed *= 1.2
	
	age += delta
	var target_dir = (target.position - projectile.position).normalized().angle()
	dir = rotate_toward(dir, target_dir, delta*turnspeed)

	var v = Vector2.RIGHT.rotated(dir)
	projectile.position = projectile.position + (v * delta * speed)
	$ProjectileA/Plh.rotate(PI * delta)


func _on_projectile_a_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_projectile_target") and body.has_method("command"):
		body.command(command_obj)
		queue_free()
	if age > 1.0 and body.is_in_group("player"):
		queue_free()


func _on_projectile_a_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_projectile_target") and area.has_method("command"):
		area.command(command_obj)
		queue_free()
