extends CharacterBody2D

@export var jump_curve : Curve
var jump_curve_time : float = 10.0
@export var walk_curve : Curve

var grounded_timer:float = 0.0
var jump_timer: float = 0.0
var pushback:int = 0

@export var projectiles: Array[PackedScene]

signal on_player_move(deltatime:float)
signal shoot(bullet:PackedScene, spawn_point:Transform2D)

# Using strings instead of enums to help debugging during development.
# Can be changed to enums later.
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
const KO = "KO"
const NONE = "NONE"
const SMALL = "small"
const DASH = "dash"
const LARGE:StringName = "large"
const GROWING:StringName = "growing"
const SMALL:StringName = "small"
const SHRINKING:StringName = "shrinking"

# States: Current, Previous, Current age, Previous age
var control_state := [UNKNOWN, UNKNOWN, 0.0, 0.0]
var horizontal_state := [UNKNOWN, UNKNOWN, 0.0, 0.0]
var vertical_state := [UNKNOWN, UNKNOWN, 0.0, 0.0]
var attack_state := [UNKNOWN, UNKNOWN, 0.0, 0.0]

var states = [control_state, horizontal_state, vertical_state, attack_state]


func fuzzy(a, b = 0.1):
	return a > 0 and a < b

func switch_timer(source:float, delta:float, switch:bool):
	if switch:
		return max(delta, source + delta)
	return min(-delta, source - delta)

func ghost() -> void:
	Game.ghost_trail($Sprite, "")

func command(attributes: Dictionary) -> void:
	if control_state[0] == READY:
		match attributes:
			{"damage": var dmg, ..}:
				var size_multiply = 4 if size_state[0] == SMALL else 1
				Game.affect_player_health(-absi(dmg) * size_multiply)
				$Sprite.material = Game.blink_sprite
				var next_state = DAMAGE if Game.player_health > 0 else KO
				change_state(control_state, next_state)
		
		if control_state[0] == DAMAGE:
			match(attributes):
				{"damage", "source": var src, ..}:
					pushback = signi(int(global_position.x - src.global_position.x))
				_:
					pushback = 0
		
func change_state(state_group:Array, state) -> void:
	state_group[0] = state
	if state_group[2] > 0.0:
		state_group[3] = state_group[2]
	state_group[2] = 0.0

# Keep movement inputs from previous process.
# This allows moving when player input is disabled for animation or transitions.
# Care needs to be taken if character needs to stay put that these values are reset.
var input_left:float
var input_right:float
var input_vector:Vector2
var input_sign:Vector2i
var input_dir:Vector2i
var input_jump:bool
var input_jump_released:int

func _physics_process(delta: float) -> void:
	var walk_effect : float = 0.0
	var gravity_effect : float = 0.0

	var process_input:bool = Game.can_process_input(self)
	if control_state[0] == DAMAGE or control_state[0] == KO:
		# This will require more granularity if different damage types are implemented
		process_input = false
	var attack:bool
	var size_shift:bool
	
	if process_input:
		input_jump = Input.is_action_pressed("jump")
		input_left = Input.is_action_pressed("move_left")
		input_right = Input.is_action_pressed("move_right")
		input_vector = Input.get_vector("move_left", "move_right", "down", "up")
		input_sign = Vector2i(sign(input_vector.x), sign(input_vector.y))
		attack = Input.is_action_just_pressed("fire")
		size_shift = Input.is_action_just_pressed("size_toggle")
		input_dir = Vector2i(0,0)
		
		if Input.is_action_just_released("jump"):
			input_jump_released = Time.get_ticks_msec()
		
		# Determining throw direction from analogue stick
		if input_vector.length_squared() > 0.0:
			const sector = PI / 6 # 30 degrees
			var ang_rad = atan2(input_vector.y, input_vector.x)

			if ang_rad < sector * 2 and ang_rad > sector * -2: # Forwardish
				input_dir.x = 1
			elif ang_rad > sector * 4 or ang_rad < sector * -4: # Back-ish
				input_dir.x = -1
				
			if ang_rad > sector and ang_rad < sector * 5: # Up-ish
				input_dir.y = 1
			elif ang_rad < -sector and ang_rad > -sector * 5: # Down-ish
				input_dir.y = -1
		
		
	
	grounded_timer = switch_timer(grounded_timer, delta, is_on_floor())
	jump_timer = switch_timer(jump_timer, delta, input_jump)

	for state in states:
		state[1] = state[0]
		state[2] += delta
	
	# Adjust only state
	match control_state:
		[UNKNOWN, UNKNOWN, ..]:
			change_state(control_state, READY)
		[READY, DAMAGE]: # 
			change_state(vertical_state, UNKNOWN)
			change_state(horizontal_state, UNKNOWN)
		[DAMAGE, var x, ..] when x != DAMAGE:
			change_state(vertical_state, DAMAGE)
			change_state(horizontal_state, DAMAGE)
		[DAMAGE, _, var age, ..] when age > 0.2:
			change_state(control_state, COOLDOWN)
		[COOLDOWN, _, var age, ..] when age > Game.invulnerability_time:
			change_state(control_state, READY)
		[KO, _, var age, ..] when age > 0.3:
			Game.player_health = 20
			Game.load_scene("res://tilesets/test.tscn")
			change_state(control_state, NONE)
	
	match size_state:
		[UNKNOWN, ..]:
			change_state(size_state, LARGE)
		[LARGE, ..] when size_shift:
			change_state(size_state, SHRINKING)
		[SMALL, ..] when size_shift:
			change_state(vertical_state, UNKNOWN)
			change_state(size_state, GROWING)
		[GROWING, _, var age, ..] when age > 0.2:
			change_state(size_state, LARGE)
		[SHRINKING, _, var age, ..] when age > 0.2:
			change_state(size_state, SMALL)
			
	
	match attack_state:
		[UNKNOWN, ..]:
			change_state(attack_state, READY)
		[ATTACK, ..]: # Previously attacked, return to Ready
			change_state(attack_state, READY)
		[READY, _, var age, ..] when attack and age > 0.1 and control_state[0] != SMALL:
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
			print("coyote")
			change_state(vertical_state, JUMPING)
		[GROUNDED, ..] when fuzzy(jump_timer): # jump on ground
			if input_dir.y == -1 and control_state[0] == SMALL: # Dash
				if horizontal_state[0] != DASH:
					change_state(horizontal_state, DASH)
				else:
					var start = Time.get_ticks_msec() - (horizontal_state[2] * 1000)
					if input_jump_released > start:
						change_state(vertical_state, JUMPING)
			else:
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
		[DASH, _, var age, ..] when age > 0.25 and grounded_timer > 0:
			var st = WALKING if input_left != input_right else IDLE
			change_state(horizontal_state, st)
	
	# React to state
	
	match vertical_state:
		[GROUNDED, ..]:
			jump_curve_time = jump_curve.get_point_position(1).x
		[JUMPING, _, ..]:
			jump_curve_time = 0.0
			if control_state[0] == SMALL:
				jump_curve_time = jump_curve.get_point_position(1).x * 0.7
		[FALLING, JUMPING, ..]:
			jump_curve_time = jump_curve.get_point_position(1).x
		[FALLING, FALLING, ..]:
			if jump_curve_time >= jump_curve.get_point_position(2).x:
				jump_curve_time = jump_curve.get_point_position(2).x - delta
	
	match horizontal_state:
		[WALKING, _, var age, ..]:
			var walk_speed = walk_curve.sample_baked(age)
			walk_effect = walk_speed if input_right else -walk_speed
			
			if control_state[0] == SMALL:
				walk_effect *= 0.75
				
			$Sprite.flip_h = input_sign.x > 0
			if $VisualRoot.scale.x != -input_sign.x:
				var s = Vector2(float(-input_sign.x), 1.0)
				if s.x != 0:
					$VisualRoot.scale = s
		[IDLE, ..]:
			walk_effect = 0.0
		[DASH, ..]:
			walk_effect = 200.0 if $Sprite.flip_h else -200.0
			Game.ghost_trail($Sprite)
	
	match attack_state:
		[ATTACK, _, _, var prev_age]:
			var bullet = projectiles[0]
			var placement: Node2D = $VisualRoot/AimLoc/AimForward
			if horizontal_state[0] != DASH:
				match [abs(input_dir.x), input_dir.y]:
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

	velocity.y = gravity_effect
	velocity.x = walk_effect
	
	match control_state:
		[DAMAGE, ..]:
			if pushback != 0:
				velocity.y = 0
				velocity.x = 150 * pushback
				Game.ghost_trail($Sprite)
		[COOLDOWN, DAMAGE, ..]:
			$Sprite.material = null
		[COOLDOWN, _, var age, ..]:
			var opacity = 1.0 if sin(age*50) < 0.0 else 0.5
			$Sprite.self_modulate = Color(1,1,1, opacity)
		[READY, COOLDOWN, ..]:
			$Sprite.self_modulate = Color(1,1,1,1)
		[KO, ..]:
			velocity.x = 0
			velocity.y = 0
	
	match size_state:
		[SHRINKING, LARGE, ..]:
			$AnimationPlayer.play("shrink")
			set_collision_mask_value(4, false) # do not collide with `world_big`
			set_collision_mask_value(5, true) # collide with `world` and `world_small`
			set_collision_layer_value(6, false) # exit `player_big` layer
			set_collision_layer_value(7, true) # enter `player_small` layer
		[GROWING, SMALL, ..]:
			$AnimationPlayer.play("grow")
			set_collision_mask_value(4, true) # collide with `world` and `world_big`
			set_collision_mask_value(5, false) # do not collide with `world_small`
			set_collision_layer_value(6, true) # enter `player_big` layer
			set_collision_layer_value(7, false) # exit `player_small` layer
	
	var _collision_info = move_and_slide()
	on_player_move.emit(delta)
