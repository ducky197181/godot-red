extends Node2D

class_name BaseScene

func _ready():
	self.modulate = Color(1.0, 1.0, 1.0, 0.0)
	Game.base_levels.push_back(self)
	var _root:CanvasLayer = await Game.add_as_base_scene(self)
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)

func switch_level(path:String) -> void:
	Game.load_map(path)

func prepare_exit():
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.5)
	tw.tween_callback(queue_free)

func _exit_tree() -> void:
	Game.base_levels.erase(self)
