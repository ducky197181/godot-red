extends CharacterBody2D

@export var jump_curve : Curve
var jump_curve_time : float = 10.0
@export var walk_curve : Curve

var gravity_effect : float = 0.0
var walk_effect : float = 0.0

var grounded_timer:float = 0.0
var walk_timer: float = 0.0
var jump_timer: float = 0.0
var attack_timer: float = 10.0

var invisible_time : float = 0.0

@export var projectiles: Array[PackedScene]

signal on_player_move(deltatime:float)
signal shoot(bullet:PackedScene, spawn_point:Transform2D)

const UNKNOWN = "unknown"
const READY = "ready"
const GROUNDED = "grounded"
const JUMPING = "jumping"
const FALLING = "falling"
const WALKING = "walking"
const IDLE = "idle"
const ATTACK = "attack"
const COOLDOWN = "cooldown"
const DAMAGE = "damage"

var control_state := [UNKNOWN, UNKNOWN]
var horizontal_state := [UNKNOWN, UNKNOWN]
var vertical_state := [UNKNOWN, UNKNOWN]
var attack_state := [UNKNOWN, UNKNOWN, UNKNOWN] # third is equipment


func fuzzy(a, b = 0.1):
	return a > 0 and a < b

func hit(source : Node, type = DAMAGE) -> void:
	if invisible_time > Game.invulnerability_time:
		control_state[0] = type

func _physics_process(delta: float) -> void:
	var input_left = Input.is_action_pressed("move_left")
	var input_right = Input.is_action_pressed("move_right")
	var input_vector = Input.get_vector("move_left", "move_right", "Down", "Up")
	var input_sign = Vector2i(sign(input_vector.x), sign(input_vector.y))
	var attack = Input.is_action_just_pressed("Fire")
	
	grounded_timer = max(delta, grounded_timer + delta) if is_on_floor() else min(-delta, grounded_timer - delta)
	jump_timer = max(delta, jump_timer + delta) if Input.is_action_pressed("jump") else min(-delta, jump_timer - delta)
	attack_timer += delta
	invisible_time += delta

	control_state[1] = control_state[0]
	vertical_state[1] = vertical_state[0]
	horizontal_state[1] = horizontal_state[0]
	attack_state[1] = attack_state[0]
	
	# Adjust only state
	match control_state:
		[UNKNOWN, ..]:
			control_state[0] = READY
	
	match attack_state:
		[UNKNOWN,_,_]:
			attack_state[0] = READY
		[ATTACK,_,_]: # Previously attacked, return to Ready
			attack_state[0] = READY
		[READY,_,_] when attack and attack_timer > 0.1:
			attack_state[0] = ATTACK
	
	match vertical_state:
		[UNKNOWN, _]: # Unknown
			vertical_state[0] = GROUNDED if grounded_timer > 0 else FALLING
		[JUMPING, _] when jump_timer < 0 or jump_timer > jump_curve.get_point_position(1).x: # stop jump
			vertical_state[0] = FALLING
		[FALLING, _] when grounded_timer > 0: # Landed
			vertical_state[0] = GROUNDED
			if fuzzy(jump_timer): # Jump on land
				vertical_state[1] = GROUNDED
				vertical_state[0] = JUMPING
		[FALLING, _] when fuzzy(-grounded_timer) and fuzzy(jump_timer): # coyote
			vertical_state[0] = JUMPING
		[GROUNDED, _] when fuzzy(jump_timer): # jump on ground
			vertical_state[0] = JUMPING
		[GROUNDED, _] when grounded_timer < 0:
			vertical_state[0] = FALLING

	match horizontal_state:
		[UNKNOWN, _]: #Unknown
			horizontal_state[0] = IDLE
		[IDLE, _] when input_left != input_right: # start walking
			horizontal_state[0] = WALKING
		[WALKING, _] when not input_left and not input_right: # stop walking
			horizontal_state[0] = IDLE
	
	# React to state
	
	
	match vertical_state:
		[GROUNDED, _]:
			jump_curve_time = jump_curve.get_point_position(1).x
		[JUMPING, GROUNDED]:
			jump_curve_time = 0.0
		[FALLING, JUMPING]:
			jump_curve_time = jump_curve.get_point_position(1).x
		[FALLING, FALLING]:
			if jump_curve_time >= jump_curve.get_point_position(2).x:
				jump_curve_time = jump_curve.get_point_position(2).x - delta
	
	match horizontal_state:
		[WALKING, _]:
			walk_timer = max(delta, walk_timer + delta)
			var walk_speed = walk_curve.sample_baked(walk_timer)
			walk_effect = walk_speed if input_right else -walk_speed
			
			if $VisualRoot.scale.x != -input_sign.x:
				var s = Vector2(float(-input_sign.x), 1.0)
				if s.x != 0:
					$VisualRoot.scale = s
					input_sign.x
		[IDLE, _]:
			walk_timer = min(-delta, walk_timer - delta)
			walk_effect = 0.0
	
	match attack_state:
		[ATTACK,..]:
			var bullet = projectiles[0]
			var placement: Node2D = $VisualRoot/AimLoc/AimForward
			match [abs(input_sign.x), input_sign.y]:
				[0,1,..]: # Up
					placement = $VisualRoot/AimLoc/AimUp
				[1,1,..]: # Up angle
					placement = $VisualRoot/AimLoc/AimUpForward
				[1,-1,..]: # Down angle
					placement = $VisualRoot/AimLoc/AimDownForward
				[0,-1,..]:
					if vertical_state[0] == GROUNDED:
						placement = $VisualRoot/AimLoc/AimCrouched
					else:
						placement = $VisualRoot/AimLoc/AimDown
			shoot.emit(bullet, placement.global_transform, attack_timer)
			attack_timer = 0.0
	
	var a := jump_curve.sample(jump_curve_time)
	jump_curve_time += delta
	var b := jump_curve.sample(jump_curve_time)
	gravity_effect = (a-b) / delta

	$Debug.text = "%s / %s" % [jump_curve_time , gravity_effect]
	
	velocity.y = gravity_effect
	velocity.x = walk_effect
	
	
	#velocity.y = vertical_curve.sample(jump_marker) * 200
	#get_input()
	var collision_info = move_and_slide()
	on_player_move.emit(delta)
