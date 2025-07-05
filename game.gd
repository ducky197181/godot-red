extends Node



func _init() -> void:
	var config := ConfigFile.new()
	var err = config.load("res://config.cfg")
	if err != OK:
		return
	invulnerability_time = config.get_value("gameplay", "invulnerability_time", 1.0)

var player_health := 20
var invulnerability_time : float

signal player_health_change(value: int)

func damage_player(value: int):
	var target: = clampi(player_health + value, 0, 20)
	var diff = target - player_health
	if diff == 0:
		return
	player_health = target
	player_health_change.emit(player_health)
