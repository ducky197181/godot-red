extends Node

enum GameState { PLAY_STATE, LOAD_MAP }

func _init() -> void:
	var config := ConfigFile.new()
	var err = config.load("res://core/config.cfg")
	assert(err == OK)
	invulnerability_time = config.get_value("gameplay", "invulnerability_time", 1.0)

var player_health := 20
var invulnerability_time : float
var game_state := GameState.PLAY_STATE

signal player_health_change(value: int)

func damage_player(value: int):
	var target: = clampi(player_health + value, 0, 20)
	var diff = target - player_health
	if diff == 0:
		return
	player_health = target
	player_health_change.emit(player_health)

func load_map(path: String):
	if game_state == GameState.LOAD_MAP:
		push_warning("Loading map while one is loading? Abort.")
		return false
		
	var rt = get_tree()
	
	pass
