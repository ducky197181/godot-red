extends Node2D

# Load variables from configuration.
func _init() -> void:
	var config := ConfigFile.new()
	var err = config.load("res://core/config.cfg")
	assert(err == OK)
	invulnerability_time = config.get_value("gameplay", "invulnerability_time", 1.0)

# Add scene to its own `CanvasLayer` to separate its physics from other scenes.
# This allows creating a "zoomed in" scene with separate colliders.
# CanvasLayers has meta attribute that can be used to control if inputs should
# be listened to, in case adjusting `process_mode` is not possible.
func add_as_base_scene(level:BaseScene) -> CanvasLayer:
	level.process_mode = Node.PROCESS_MODE_DISABLED
	var cl := CanvasLayer.new()
	cl.follow_viewport_enabled = true
	add_child(cl)
	await get_tree().process_frame
	level.reparent(cl, false)
	level.connect("tree_exited", cl.queue_free)
	level.process_mode = Node.PROCESS_MODE_INHERIT
	base_levels.push_back(level)
	return cl

# `BaseScene` nodes may request input priority through the "input" metadata.
# A minigame on top of the main game with larger "input" should have priority
# over smaller or non-existent "input" values.
func can_process_input(cl:Node) -> bool:
	while cl != null and cl.has_meta("input") == false:
		cl = cl.get_parent()
	var priority:int = 0 if cl == null else cl.get_meta("input")
	if priority < 0:
		return false
	for bl in base_levels:
		if priority < bl.get_meta("input", 0):
			return false
	return true

var base_levels : Array[BaseScene] = []

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

func load_scene(path: String):
	ResourceLoader.load_threaded_request(path)
	
	for level in base_levels:
		level.set_meta("input", -1) # Stop input but allow processing
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
