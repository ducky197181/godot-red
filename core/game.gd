extends Node

enum GameState { PLAY_STATE, LOAD_MAP }

func _init() -> void:
	var config := ConfigFile.new()
	var err = config.load("res://core/config.cfg")
	assert(err == OK)
	invulnerability_time = config.get_value("gameplay", "invulnerability_time", 1.0)

var base_levels : Array[BaseLevel] = []
var base_levels : Array[BaseScene] = []

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
	ResourceLoader.load_threaded_request(path)
	
	for level in base_levels:
		level.prepare_exit()
		
	var grace_period = 5.0
	while grace_period > 0.0 and len(base_levels) > 0:
		await get_tree().process_frame
		grace_period -= get_process_delta_time()
	
	if len(base_levels) > 0:
		push_warning("Levels did not exit in time.")
		for level in base_levels:
			level.queue_free()
		base_levels.clear()

	var level_scene := ResourceLoader.load_threaded_get(path)
	get_tree().root.add_child(level_scene.instantiate())
