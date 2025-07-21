extends CharacterBody2D

@export var jump_curve : Curve
var grow_jump_curve : Curve
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
const UNKNOWN:StringName = "unknown"
const READY:StringName = "ready"
const GROUNDED:StringName = "grounded"
const JUMPING:StringName = "jumping"
const FALLING:StringName = "falling"
const GLIDING:StringName = "gliding"
const WALLSLIDE:StringName = "wallslide"
const WALKING:StringName = "walking"
const IDLE:StringName = "idle"
const ATTACK:StringName = "attack"
const COOLDOWN:StringName = "cooldown"
const DAMAGE:StringName = "damage"
const KO:StringName = "KO"
const NONE:StringName = "NONE"
const LARGE:StringName = "large"
const GROWING:StringName = "growing"
const SMALL:StringName = "small"
const SHRINKING:StringName = "shrinking"
const DASH:StringName = "dash"
const SPRING:StringName = "spring"

# States: Current, Previous, Current age, Previous age
var control_state := [UNKNOWN, UNKNOWN, 0.0, 0.0]
var horizontal_state := [UNKNOWN, UNKNOWN, 0.0, 0.0]
var vertical_state := [UNKNOWN, UNKNOWN, 0.0, 0.0]
var attack_state := [UNKNOWN, UNKNOWN, 0.0, 0.0]
var size_state := [UNKNOWN, UNKNOWN, 0.0, 0.0]

var states = [control_state, horizontal_state, vertical_state, attack_state, size_state]

func _ready() -> void:
	grow_jump_curve = Curve.new()
	grow_jump_curve.max_domain = 2
	grow_jump_curve.max_value = jump_curve.max_value * 2
	#jump_curve.duplicate()
	for i in range(0, jump_curve.point_count):
		var c: = jump_curve.get_point_position(i)
		var lm: = jump_curve.get_point_left_mode(i)
		var lt: = jump_curve.get_point_left_tangent(i)
		var rm = jump_curve.get_point_right_mode(i)
		var rt = jump_curve.get_point_right_tangent(i)
		c.x *= 1.1
		c.y *= 1.1
		grow_jump_curve.add_point(c, lt, rt, lm, rm)

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
var shrink_dash:bool
var grow_jump: bool
var input_dash_time:float
var wall_stick:float

func _physics_process(delta: float) -> void:
	var walk_effect : float = 0.0
	var gravity_effect : float = 0.0

	var process_input:bool = Game.can_process_input(self)
	if control_state[0] == DAMAGE or control_state[0] == KO:
		# This will require more granularity if different damage types are implemented
		process_input = false
	var attack:bool
	var size_shift:bool
	var dash_input:bool
	var dash_input_hold:bool
	var jump_input_pressed
	
	if process_input:
		input_jump = Input.is_action_pressed("jump")
		jump_input_pressed = Input.is_action_just_pressed("jump")
		input_left = Input.is_action_pressed("move_left")
		input_right = Input.is_action_pressed("move_right")
		input_vector = Input.get_vector("move_left", "move_right", "down", "up")
		input_sign = Vector2i(sign(input_vector.x), sign(input_vector.y))
		attack = Input.is_action_just_pressed("fire")
		size_shift = Input.is_action_just_pressed("size_toggle")
		input_dir = Vector2i(0,0)
		dash_input = Input.is_action_just_pressed("dash")
		input_dash_time = input_dash_time + delta if Input.is_action_pressed("dash") else 0.0
		
		
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
	var _jump_curve := jump_curve if not grow_jump else grow_jump_curve

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
		[READY, _, var age, ..] when attack and age > 0.1 and size_state[0] == LARGE:
			change_state(attack_state, ATTACK)
	
	
	match [horizontal_state[0], vertical_state[0]]:
		# Exit wallslide if touching floor
		[WALLSLIDE, WALLSLIDE] when not is_on_wall_only():
			change_state(horizontal_state, UNKNOWN)
			change_state(vertical_state, UNKNOWN)
		
		# Count down stick timer if not pressing against the wall
		[WALLSLIDE, WALLSLIDE] when is_on_wall_only() \
			and -sign(get_wall_normal().x) != sign(input_vector.x):
				wall_stick -= delta
				if wall_stick <= 0.0:
					change_state(horizontal_state, UNKNOWN)
					change_state(vertical_state, UNKNOWN)
	
	
	match vertical_state:
		# Unknown, reset to a state
		[UNKNOWN, ..]: 
			change_state(vertical_state, GROUNDED if grounded_timer > 0 else FALLING)
			
		# Stop jump at curve apex or on button release
		[JUMPING, JUMPING, ..] \
			when jump_timer < 0 or jump_curve_time > _jump_curve.get_point_position(1).x:
				change_state(vertical_state, FALLING)
		
		# Land on ground, and if jumped within fuzzy period, switch to JUMP
		[FALLING, ..], [GLIDING, ..], [WALLSLIDE, ..] when grounded_timer > 0: # Landed
			change_state(vertical_state, GROUNDED)
			if fuzzy(jump_timer): # Jump on land
				vertical_state[1] = GROUNDED
				vertical_state[0] = JUMPING
			
		# Coyote jump
		[FALLING, ..] when fuzzy(-grounded_timer) and fuzzy(jump_timer): # coyote
			change_state(vertical_state, JUMPING)
		
		# Normal grounded jump
		[GROUNDED, ..] when fuzzy(jump_timer): # jump on ground
			change_state(vertical_state, JUMPING)
			
		# Walk over edge and start falling
		[GROUNDED, ..] when grounded_timer < 0:
			change_state(vertical_state, FALLING)
		
		# Wall dash while small
		[WALLSLIDE, ..] when jump_input_pressed:
			change_state(vertical_state, DASH)
			change_state(horizontal_state, DASH)
		
		# Glide when falling
		[FALLING, FALLING, var age, ..] when input_dash_time > 0.0 and input_dash_time < age and size_state[0] == SMALL:
			change_state(vertical_state, GLIDING)
		
		# Release gliding button, begin fall
		[GLIDING, ..] when input_dash_time == 0.0:
			change_state(vertical_state, FALLING)
		
		# Time out wall dash
		[DASH, _, var age, ..] when age > 0.25:
			change_state(vertical_state, JUMPING)
			change_state(horizontal_state, IDLE)
			

	match horizontal_state:
		[UNKNOWN, ..]: #Unknown
			var st = WALKING if input_left != input_right else IDLE
			change_state(horizontal_state, st)
		
		# Begin walk on horizontal input
		[IDLE, ..] when input_left != input_right:
			change_state(horizontal_state, WALKING)
			
		# Stop walking if neither left or right input
		[WALKING, ..] when not input_left and not input_right: # stop walking
			change_state(horizontal_state, IDLE)
		
		# Begin grounded dash
		[IDLE, ..], [WALKING, ..] when dash_input \
			and size_state[0] == SMALL \
			and (vertical_state[0] == GROUNDED) \
			and horizontal_state[0] != DASH:
				change_state(horizontal_state, DASH)
				
		# Time out dash
		[DASH, _, var age, ..] when age > 0.25:
			var st = WALKING if input_left != input_right else IDLE
			change_state(horizontal_state, st)
		
	
	match [horizontal_state[0], vertical_state[0], size_state[0]]:
		# Start wall stick when airborne and moving against a wall
		# Currently limited to when small
		[WALKING, FALLING, SMALL], [WALKING, JUMPING, SMALL] \
			when is_on_wall_only() \
			and sign(get_wall_normal().x) != sign(input_vector.x):
				wall_stick = 0.2
				change_state(vertical_state, WALLSLIDE)
				change_state(horizontal_state, WALLSLIDE)
	
	
	# React to state
	
	match vertical_state:
		[GROUNDED, var x, ..]:
			jump_curve_time = _jump_curve.get_point_position(1).x
			if x == FALLING:
				grow_jump = false
				shrink_dash = false
		[JUMPING, GROUNDED,..], [JUMPING, FALLING,..]:
			jump_curve_time = 0.0
			match size_state:
				[GROWING, ..]:
					grow_jump = true
				[SMALL, ..], [SHRINKING, ..]:
					jump_curve_time = _jump_curve.get_point_position(1).x * 0.3
		[JUMPING, JUMPING, ..] when grow_jump:
			Game.ghost_trail($Sprite)
		[FALLING, JUMPING, ..]:
			jump_curve_time = _jump_curve.get_point_position(1).x
		[FALLING, FALLING, ..]:
			if jump_curve_time >= _jump_curve.get_point_position(2).x:
				jump_curve_time = _jump_curve.get_point_position(2).x - delta
		[DASH, ..]:
			jump_curve_time = _jump_curve.get_point_position(1).x * 0.7
			Game.ghost_trail($Sprite)
		[GLIDING, ..]:
			if jump_curve_time >= _jump_curve.get_point_position(2).x:
				jump_curve_time = _jump_curve.get_point_position(2).x - delta
			Game.ghost_trail($Sprite)
		[WALLSLIDE, ..]:
			jump_curve_time = min(jump_curve_time, _jump_curve.get_point_position(1).x + 0.1)
			Game.ghost_trail($Sprite)
	
	match horizontal_state:
		[WALKING, _, var age, ..]:
			var walk_speed = walk_curve.sample_baked(age)
			walk_effect = walk_speed if input_right else -walk_speed
			
			if size_state[0] == SMALL:
				walk_effect *= 0.75
				
			$Sprite.flip_h = input_sign.x > 0
			if $VisualRoot.scale.x != -input_sign.x:
				var s = Vector2(float(-input_sign.x), 1.0)
				if s.x != 0:
					$VisualRoot.scale = s
		[IDLE, ..]:
			walk_effect = 0.0
		[DASH, var prev, ..]:
			shrink_dash = false
			walk_effect = 200.0 if $Sprite.flip_h else -200.0
			if vertical_state[0] == DASH:
				if vertical_state[1] != DASH:
					$Sprite.flip_h = not $Sprite.flip_h
				walk_effect = 100.0 if $Sprite.flip_h else -100.0
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
	
	var a := _jump_curve.sample(jump_curve_time)
	jump_curve_time += delta if not grow_jump else delta * 0.7
	var b := _jump_curve.sample(jump_curve_time)
	gravity_effect = (a-b) / delta

	if grow_jump:
		gravity_effect *= 1.5
		
	if vertical_state[0] == GLIDING:
		gravity_effect *= remap(-grounded_timer, 0.5, 6.0, 0.0, 1.0)

	velocity.y = gravity_effect
	velocity.x = walk_effect
	
	if shrink_dash and horizontal_state[0] == DASH:
		velocity.y = 0
	
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
			shrink_dash = true
			$AnimationPlayer.play("shrink")
			set_collision_mask_value(4, false) # do not collide with `world_big`
			set_collision_mask_value(5, true) # collide with `world` and `world_small`
			set_collision_layer_value(6, false) # exit `player_big` layer
			set_collision_layer_value(7, true) # enter `player_small` layer
		[GROWING, SMALL, ..]:
			grow_jump = true
			$AnimationPlayer.play("grow")
			set_collision_mask_value(4, true) # collide with `world` and `world_big`
			set_collision_mask_value(5, false) # do not collide with `world_small`
			set_collision_layer_value(6, true) # enter `player_big` layer
			set_collision_layer_value(7, false) # exit `player_small` layer
		[LARGE, GROWING, ..] when vertical_state[0] == GROUNDED:
			grow_jump = false
	
	var _collision_info = move_and_slide()
	on_player_move.emit(delta)
