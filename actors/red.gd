extends CharacterBody2D

@export var jump_curve : Curve
var jump_curve_time : float = 10.0
@export var walk_curve : Curve




var grounded_timer:float = 0.0
var jump_timer: float = 0.0

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

# States: Current, Previous, Current age, Previous age
var control_state := [UNKNOWN, UNKNOWN, 0.0, 0.0]
var horizontal_state := [UNKNOWN, UNKNOWN, 0.0, 0.0]
var vertical_state := [UNKNOWN, UNKNOWN, 0.0, 0.0]
var attack_state := [UNKNOWN, UNKNOWN, 0.0, 0.0]

var states = [control_state, horizontal_state, vertical_state, attack_state]


func fuzzy(a, b = 0.1):
	return a > 0 and a < b

func hit(source : Node, type = DAMAGE) -> void:
	Game.damage_player(-2)

func change_state(state_group:Array, state) -> void:
	state_group[0] = state
	state_group[3] = state_group[2]
	state_group[2] = 0.0

func _physics_process(delta: float) -> void:
	var walk_effect : float = 0.0
	var gravity_effect : float = 0.0
	
	var input_left := Input.is_action_pressed("move_left")
	var input_right := Input.is_action_pressed("move_right")
	var input_vector := Input.get_vector("move_left", "move_right", "Down", "Up")
	var input_sign := Vector2i(sign(input_vector.x), sign(input_vector.y))
	var attack := Input.is_action_just_pressed("Fire")
	
	grounded_timer = max(delta, grounded_timer + delta) if is_on_floor() else min(-delta, grounded_timer - delta)
	jump_timer = max(delta, jump_timer + delta) if Input.is_action_pressed("jump") else min(-delta, jump_timer - delta)

	for state in states:
		state[1] = state[0]
		state[2] += delta
	
	# Adjust only state
	match attack_state:
		[UNKNOWN, ..]:
			change_state(attack_state, READY)
		[ATTACK, ..]: # Previously attacked, return to Ready
			change_state(attack_state, READY)
		[READY, _, var age, ..] when attack and age > 0.1:
			change_state(attack_state, ATTACK)
	
	
	
	match vertical_state:
		[UNKNOWN, ..]: # Unknown
			change_state(vertical_state, GROUNDED if grounded_timer > 0 else FALLING)
		[JUMPING, ..] when jump_timer < 0 or jump_timer > jump_curve.get_point_position(1).x: # stop jump
			change_state(vertical_state, FALLING)
		[FALLING, ..] when grounded_timer > 0: # Landed
			change_state(vertical_state, GROUNDED)
			if fuzzy(jump_timer): # Jump on land
				vertical_state[1] = GROUNDED
				vertical_state[0] = JUMPING
		[FALLING, ..] when fuzzy(-grounded_timer) and fuzzy(jump_timer): # coyote
			change_state(vertical_state, JUMPING)
		[GROUNDED, ..] when fuzzy(jump_timer): # jump on ground
			change_state(vertical_state, JUMPING)
		[GROUNDED, ..] when grounded_timer < 0:
			change_state(vertical_state, FALLING)

	match horizontal_state:
		[UNKNOWN, ..]: #Unknown
			change_state(horizontal_state, IDLE)
		[IDLE, ..] when input_left != input_right: # start walking
			change_state(horizontal_state, WALKING)
		[WALKING, ..] when not input_left and not input_right: # stop walking
			change_state(horizontal_state, IDLE)
	
	# React to state
	
	match vertical_state:
		[GROUNDED, ..]:
			jump_curve_time = jump_curve.get_point_position(1).x
		[JUMPING, GROUNDED, ..]:
			jump_curve_time = 0.0
		[FALLING, JUMPING, ..]:
			jump_curve_time = jump_curve.get_point_position(1).x
		[FALLING, FALLING, ..]:
			if jump_curve_time >= jump_curve.get_point_position(2).x:
				jump_curve_time = jump_curve.get_point_position(2).x - delta
	
	match horizontal_state:
		[WALKING, _, var age, ..]:
			var walk_speed = walk_curve.sample_baked(age)
			walk_effect = walk_speed if input_right else -walk_speed
			
			if $VisualRoot.scale.x != -input_sign.x:
				var s = Vector2(float(-input_sign.x), 1.0)
				if s.x != 0:
					$VisualRoot.scale = s
					input_sign.x
		[IDLE, ..]:
			walk_effect = 0.0
	
	match attack_state:
		[ATTACK, _, _, var prev_age]:
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
			shoot.emit(bullet, placement.global_transform, prev_age)
	
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
