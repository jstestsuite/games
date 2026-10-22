class_name Lion
extends BigCat
## The player. Stalk (Ctrl), walk, sprint (Shift: a short burst that fades into a run),
## pounce (Space; hold it to keep your grip in a takedown), swipe (LMB / F),
## dodge (RMB / Alt), roar (Q), eat (E).
## Animals don't strafe: you steer a heading, and at speed you turn wide.

signal roared(at: Vector3, radius: float)

enum State { MOVE, POUNCE, TAKEDOWN, EATING, SWIPE, DODGE, STAGGER, DOWN }

var state := State.MOVE
var charge := 0.0             # seconds of burst left in the tank
var sprinting := false        # charging or running
var bursting := false         # the full-speed part of a sprint
var winded_t := 0.0
var stalking := false
var in_cover := false
var notice_mult := 1.0
var controls_enabled := true
var last_hurt_by := ""
var grab_target: Prey
var eat_target: Prey

var _sprint_t := 0.0
var _burst_left := 0.0
var _fade := 1.0
var _state_t := 0.0
var _pounce_cd := 0.0
var _pounce_hit := false
var _swipe_cd := 0.0
var _swipe_done := false
var _dodge_cd := 0.0
var _dodge_dir := Vector3.ZERO
var roar_cd := 0.0
var _cam_yaw := 0.0
var _cam_pitch := -0.22
var _trauma := 0.0

var cam_pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D


func _ready() -> void:
	add_to_group("player")
	add_to_group("hunter")
	_init_body(true)
	strength = GameState.strength
	health = health_max()
	charge = max_charge()

	cam_pivot = Node3D.new()
	cam_pivot.name = "CameraPivot"
	cam_pivot.top_level = true
	add_child(cam_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = Tuning.CAM_DISTANCE
	spring.margin = 0.3
	spring.collision_mask = 1
	spring.add_excluded_object(get_rid())
	cam_pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = Tuning.FOV_BASE
	camera.far = 2500.0
	camera.current = true
	spring.add_child(camera)
	_cam_yaw = heading


func max_charge() -> float:
	return Tuning.CHARGE_TIME * GameState.mod("charge_time")


## Fresh start for a new day: full charge, not winded, standing.
func wake() -> void:
	state = State.MOVE
	charge = max_charge()
	winded_t = 0.0
	sprinting = false
	speed = 0.0
	health = minf(health_max(), health + Tuning.HEALTH_NIGHT_HEAL * GameState.mod("health_regen"))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_cam_yaw -= event.relative.x * Tuning.MOUSE_SENS
		_cam_pitch = clampf(_cam_pitch - event.relative.y * Tuning.MOUSE_SENS, -1.1, 0.35)


func _physics_process(delta: float) -> void:
	strength = GameState.strength
	_pounce_cd = maxf(0.0, _pounce_cd - delta)
	_swipe_cd = maxf(0.0, _swipe_cd - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	roar_cd = maxf(0.0, roar_cd - delta)
	winded_t = maxf(0.0, winded_t - delta)
	_state_t += delta
	if state != State.MOVE:
		sprinting = false
		bursting = false

	match state:
		State.MOVE:
			_move(delta)
		State.POUNCE:
			_pounce(delta)
		State.TAKEDOWN:
			_takedown(delta)
		State.EATING:
			_eat(delta)
		State.SWIPE:
			_swipe(delta)
		State.DODGE:
			_dodge(delta)
		State.STAGGER:
			speed = move_toward(speed, 0.0, 30.0 * delta)
			if _state_t > Tuning.STAGGER_TIME:
				_set_state(State.MOVE)
		State.DOWN:
			speed = move_toward(speed, 0.0, 30.0 * delta)

	if not sprinting and state != State.DOWN:
		var rate := Tuning.CHARGE_RECOVER
		if speed <= Tuning.STALK_SPEED + 0.2:
			rate *= Tuning.CHARGE_RECOVER_IDLE_MULT
		charge = minf(max_charge(), charge + rate * delta)

	if _since_hurt > Tuning.HEALTH_REGEN_DELAY and GameState.hunger > 0.0 and not is_dead:
		health = minf(health_max(), health + Tuning.HEALTH_REGEN * GameState.mod("health_regen") * delta)

	_move_body(delta)
	in_cover = terrain != null and terrain.is_in_tall_grass(global_position)
	refresh_look(GameState.mane_darkness())
	_update_rig(delta)


func _process(delta: float) -> void:
	_pad_look(delta)
	_update_camera(delta)


## Right stick turns the camera (the mouse does it in _unhandled_input).
func _pad_look(delta: float) -> void:
	if not controls_enabled:
		return
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down", Tuning.PAD_DEADZONE)
	if look == Vector2.ZERO:
		return
	_cam_yaw -= look.x * Tuning.PAD_LOOK_SPEED * delta
	var dy := look.y * (-1.0 if Tuning.PAD_INVERT_Y else 1.0)
	_cam_pitch = clampf(_cam_pitch - dy * Tuning.PAD_LOOK_SPEED * 0.6 * delta, -1.1, 0.35)


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0


# --- moving ------------------------------------------------------------------

func _input_vector() -> Vector2:
	if not controls_enabled:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back", Tuning.PAD_DEADZONE)


func _move(delta: float) -> void:
	var input := _input_vector()
	var has_input := input.length() > 0.1

	stalking = controls_enabled and Input.is_action_pressed("stalk")
	var want_sprint := controls_enabled and Input.is_action_pressed("sprint") and has_input \
			and not stalking and winded_t <= 0.0
	if want_sprint and not sprinting:
		# Start a sprint: burst with whatever charge is in the tank, else just run.
		sprinting = true
		_sprint_t = 0.0
		_burst_left = charge if charge >= Tuning.CHARGE_MIN_TO_START else 0.0
		_fade = 0.0 if _burst_left > 0.0 else 1.0
	elif not want_sprint:
		sprinting = false

	var target_speed := 0.0
	bursting = false
	if sprinting:
		_sprint_t += delta
		if _burst_left > 0.0:
			bursting = true
			_burst_left -= delta
			charge = maxf(0.0, charge - delta)
		else:
			_fade = minf(1.0, _fade + delta / Tuning.CHARGE_FADE)
		target_speed = lerpf(Tuning.CHARGE_SPEED, Tuning.RUN_SPEED, smoothstep(0.0, 1.0, _fade))
		if _sprint_t > Tuning.RUN_WINDED_TIME * GameState.mod("run_time"):
			sprinting = false
			winded_t = Tuning.WINDED_TIME
			GameState.message.emit("Winded!")
	if not has_input:
		target_speed = 0.0
	elif not sprinting:
		target_speed = Tuning.STALK_SPEED if stalking else Tuning.WALK_SPEED

	if has_input:
		# Camera-relative desired heading.
		var world_dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, _cam_yaw)
		var desired := atan2(-world_dir.x, -world_dir.z)
		var t := clampf(speed / Tuning.CHARGE_SPEED, 0.0, 1.0)
		var turn := lerpf(Tuning.TURN_RATE_WALK, Tuning.TURN_RATE_SPRINT, t)
		var diff := wrapf(desired - heading, -PI, PI)
		heading += clampf(diff, -turn * delta, turn * delta)
		# Asking to go the opposite way at speed = brake.
		if absf(diff) > 2.2 and speed > Tuning.WALK_SPEED:
			target_speed = 0.0

	var accel := Tuning.ACCEL_SPRINT if sprinting else Tuning.ACCEL_WALK
	if target_speed < speed:
		accel *= 1.8   # braking is quicker than building speed
	speed = move_toward(speed, target_speed, accel * delta)

	if not controls_enabled:
		return
	if Input.is_action_just_pressed("pounce") and _pounce_cd <= 0.0:
		_start_pounce()
	elif Input.is_action_just_pressed("swipe") and _swipe_cd <= 0.0:
		_start_swipe()
	elif Input.is_action_just_pressed("dodge") and _dodge_cd <= 0.0:
		_start_dodge(input)
	elif Input.is_action_just_pressed("roar") and roar_cd <= 0.0:
		_roar()
	elif Input.is_action_just_pressed("eat"):
		var c := _nearest_carcass(3.5)
		if c:
			_start_eating(c)
		else:
			GameState.message.emit("Nothing to eat here.")


# --- pounce and takedown -----------------------------------------------------

func _start_pounce() -> void:
	_set_state(State.POUNCE)
	_pounce_hit = false
	velocity.y = 5.0
	_trauma = maxf(_trauma, 0.25)


func _pounce(delta: float) -> void:
	speed = maxf(speed, Tuning.POUNCE_SPEED)
	# A little homing makes pounces feel fair against jinking prey.
	var target := _find_prey(8.0)
	if target:
		face_towards(target.global_position, Tuning.POUNCE_HOMING, delta)
	var prey := _find_prey(Tuning.POUNCE_CATCH_RADIUS)
	if prey and prey.grab(self):
		grab_target = prey
		_set_state(State.TAKEDOWN)
		_trauma = 0.5
		return
	if not _pounce_hit:
		for e in targets_in_arc("enemy", Tuning.POUNCE_CATCH_RADIUS, 100.0):
			_pounce_hit = true
			e.take_hit(_attack_damage(Tuning.LUNGE_DAMAGE) * GameState.mod("lunge_damage"), global_position, true)
			_trauma = 0.6
			_hitstop()
		if _pounce_hit:
			speed *= 0.3
	if _state_t >= Tuning.POUNCE_DURATION:
		_set_state(State.MOVE)
		_pounce_cd = Tuning.POUNCE_COOLDOWN
		speed *= 0.45   # landing kills momentum: a missed pounce costs you


func _find_prey(radius: float) -> Prey:
	var best: Prey = null
	var best_d := radius
	# Measure from the jaws, not the middle of the body.
	var jaws := global_position + forward() * 1.1
	for node in get_tree().get_nodes_in_group("prey"):
		var g := node as Prey
		if g == null or g.is_dead:
			continue
		var d := g.global_position.distance_to(jaws)
		if d < best_d:
			best_d = d
			best = g
	return best


func _takedown(delta: float) -> void:
	if not is_instance_valid(grab_target):
		_set_state(State.MOVE)
		return
	if grab_target.is_dead:
		_on_kill(grab_target)
		return
	if grab_target.state != Prey.State.GRABBED or not grab_target.grabbers.has(self):
		grab_target = null
		_set_state(State.MOVE)
		return
	if controls_enabled and not Input.is_action_pressed("pounce"):
		# Let go: it bolts.
		grab_target.release(self)
		grab_target = null
		_pounce_cd = Tuning.POUNCE_COOLDOWN
		_set_state(State.MOVE)
		GameState.message.emit("It broke free!")
		return
	# Hang on to its flank.
	var pf := Vector3(-sin(grab_target.heading), 0, -cos(grab_target.heading))
	var pr := pf.cross(Vector3.UP)
	var spot := grab_target.global_position + pr * 0.9 + pf * 0.2
	global_position.x = lerpf(global_position.x, spot.x, 1.0 - exp(-12.0 * delta))
	global_position.z = lerpf(global_position.z, spot.z, 1.0 - exp(-12.0 * delta))
	face_towards(grab_target.global_position, 10.0, delta)
	speed = 0.0


func _on_kill(prey: Prey) -> void:
	grab_target = null
	GameState.register_kill(prey.display_name())
	_trauma = 0.7
	_hitstop()
	_start_eating(prey)


func _hitstop() -> void:
	# A tiny freeze sells the impact.
	Engine.time_scale = 0.05
	get_tree().create_timer(Tuning.HITSTOP_TIME, true, false, true).timeout.connect(
		func(): Engine.time_scale = 1.0)


# --- eating -----------------------------------------------------------------

func _nearest_carcass(radius: float) -> Prey:
	var best: Prey = null
	var best_d := radius
	for node in get_tree().get_nodes_in_group("carcass"):
		var c := node as Prey
		if c == null or c.food_left <= 0.0:
			continue
		var d := flat_dist(c)
		if d < best_d:
			best_d = d
			best = c
	return best


func _start_eating(c: Prey) -> void:
	eat_target = c
	speed = 0.0
	_set_state(State.EATING)


func _eat(delta: float) -> void:
	speed = 0.0
	if not is_instance_valid(eat_target) or eat_target.food_left <= 0.0:
		eat_target = null
		_set_state(State.MOVE)
		GameState.message.emit("Picked clean.")
		return
	face_towards(eat_target.global_position, 6.0, delta)
	if GameState.hunger >= Tuning.HUNGER_MAX - 0.01:
		_set_state(State.MOVE)
		GameState.message.emit("You're full.")
		return
	var got := eat_target.take_food(Tuning.EAT_RATE * GameState.mod("eat_rate") * delta)
	GameState.eat(got)
	# Any other action stops the meal.
	if controls_enabled and (_input_vector().length() > 0.1 or Input.is_action_just_pressed("swipe") \
			or Input.is_action_just_pressed("dodge") or Input.is_action_just_pressed("roar") \
			or Input.is_action_just_pressed("pounce")):
		_set_state(State.MOVE)
		_move(delta)


# --- fighting ---------------------------------------------------------------

func _attack_damage(base: float) -> float:
	var dmg := scaled_damage(base)
	if GameState.hunger < Tuning.HUNGER_MAX * 0.3:
		dmg *= Tuning.HUNGRY_FIGHT_MULT
	return dmg


func _start_swipe() -> void:
	_set_state(State.SWIPE)
	_swipe_done = false
	# Soft aim: snap toward an enemy that's roughly in front.
	var best: Node3D = null
	var best_a := Tuning.SOFT_AIM_ANGLE
	for n in get_tree().get_nodes_in_group("enemy"):
		var e := n as Node3D
		if e == null or e.get("is_dead"):
			continue
		var to := e.global_position - global_position
		to.y = 0
		if to.length() > Tuning.SWIPE_RANGE + 2.5:
			continue
		var a := absf(wrapf(atan2(-to.x, -to.z) - heading, -PI, PI))
		if a < best_a:
			best_a = a
			best = e
	if best:
		var to := best.global_position - global_position
		heading = atan2(-to.x, -to.z)


func _swipe(delta: float) -> void:
	speed = move_toward(speed, 0.0, 25.0 * delta)
	if not _swipe_done and _state_t >= Tuning.SWIPE_HIT_AT:
		_swipe_done = true
		var dmg := _attack_damage(Tuning.SWIPE_DAMAGE) * GameState.mod("swipe_damage")
		for e in targets_in_arc("enemy", Tuning.SWIPE_RANGE, Tuning.SWIPE_ARC):
			e.take_hit(dmg, global_position, false)
			_trauma = maxf(_trauma, 0.35)
	if _state_t >= Tuning.SWIPE_TIME:
		_swipe_cd = Tuning.SWIPE_COOLDOWN
		_set_state(State.MOVE)


func _start_dodge(input: Vector2) -> void:
	_set_state(State.DODGE)
	if input.length() > 0.1:
		_dodge_dir = Vector3(input.x, 0, input.y).rotated(Vector3.UP, _cam_yaw).normalized()
	else:
		_dodge_dir = -forward()
	speed = 0.0


func _dodge(_delta: float) -> void:
	knock = _dodge_dir * Tuning.DODGE_SPEED
	if _state_t >= Tuning.DODGE_TIME:
		_dodge_cd = Tuning.DODGE_COOLDOWN * GameState.mod("dodge_cd")
		_set_state(State.MOVE)


func is_invulnerable() -> bool:
	return is_dead or state == State.DODGE


func _roar() -> void:
	roar_cd = Tuning.ROAR_COOLDOWN * GameState.mod("roar_cd")
	_trauma = maxf(_trauma, 0.3)
	roared.emit(global_position, Tuning.ROAR_RADIUS * GameState.mod("roar_radius"))


## Hits from lions.
func take_hit(damage: float, from: Vector3, heavy: bool) -> void:
	last_hurt_by = "a rival lion"
	super.take_hit(damage * GameState.mod("damage_taken"), from, heavy)


## Hits from prey and hyenas: kicks, horns, bites.
func take_beast_hit(damage: float, from: Vector3, heavy: bool, who := "") -> void:
	last_hurt_by = who if who != "" else "a kick"
	super.take_hit(damage * GameState.mod("beast_damage"), from, heavy)


## Starving eats away at you without the flinch of a hit.
func starve(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	last_hurt_by = "hunger"
	if health <= 0.0:
		health = 0.0
		_on_health_gone()


func _on_hit(damage: float, heavy: bool) -> void:
	_trauma = maxf(_trauma, clampf(damage / 25.0, 0.3, 0.9))
	if state == State.EATING:
		_set_state(State.MOVE)
	if heavy and state != State.DOWN:
		if state == State.TAKEDOWN and is_instance_valid(grab_target):
			grab_target.release(self)
			grab_target = null
		_set_state(State.STAGGER)


func _on_health_gone() -> void:
	super._on_health_gone()
	_set_state(State.DOWN)
	if is_instance_valid(grab_target):
		grab_target.release(self)


## How "loud/visible" the lion is right now, before distance and cover.
func get_posture() -> float:
	match state:
		State.EATING:
			return Tuning.POSTURE_WALK * 0.6
		State.POUNCE, State.TAKEDOWN:
			return Tuning.POSTURE_SPRINT
		State.SWIPE, State.DODGE, State.STAGGER:
			return Tuning.POSTURE_WALK * 2.0
	if sprinting:
		return Tuning.POSTURE_SPRINT
	if stalking:
		return Tuning.POSTURE_STALK * GameState.mod("stalk_noise")
	if speed < 0.3:
		return Tuning.POSTURE_STALK * 0.7
	return Tuning.POSTURE_WALK


# --- presentation --------------------------------------------------------------

func _update_rig(delta: float) -> void:
	var crouch := 1.0 if (stalking and state == State.MOVE) else 0.0
	var head_down := 0.0
	var speed_norm := clampf(speed / Tuning.CHARGE_SPEED, 0.0, 1.0)
	rig.paw = 0.0
	rig.lunge = 0.0
	match state:
		State.EATING:
			crouch = 0.6
			head_down = 1.0
		State.TAKEDOWN:
			crouch = 0.4
			head_down = 0.5
			rig.lunge = 0.6
			speed_norm = 0.6
		State.POUNCE:
			speed_norm = 1.0
			rig.lunge = 1.0
		State.SWIPE:
			rig.paw = sin(clampf(_state_t / Tuning.SWIPE_TIME, 0.0, 1.0) * PI)
		State.DOWN:
			crouch = 1.0
			head_down = 1.0
	_pose_rig(delta, speed_norm, crouch, head_down)
	if state == State.DOWN:
		rig.rotate_object_local(Vector3.FORWARD, minf(_state_t * 3.0, 1.4))


func _update_camera(delta: float) -> void:
	var target := global_position + Vector3(0, Tuning.CAM_HEIGHT * (0.75 if stalking else 1.0), 0)
	cam_pivot.global_position = cam_pivot.global_position.lerp(target, 1.0 - exp(-14.0 * delta))
	cam_pivot.rotation = Vector3(_cam_pitch, _cam_yaw, 0)
	var speed_t := clampf(speed / Tuning.CHARGE_SPEED, 0.0, 1.0)
	var fov_target := lerpf(Tuning.FOV_BASE, Tuning.FOV_SPRINT, speed_t * speed_t)
	camera.fov = lerpf(camera.fov, fov_target, 1.0 - exp(-4.0 * delta))
	spring.spring_length = lerpf(spring.spring_length, Tuning.CAM_DISTANCE * (1.0 + speed_t * 0.25), 1.0 - exp(-3.0 * delta))

	_trauma = maxf(0.0, _trauma - delta * 1.6)
	var shake := _trauma * _trauma
	var tm := Time.get_ticks_msec() * 0.001
	camera.h_offset = sin(tm * 41.0) * shake * 0.25 + sin(tm * 3.1) * speed_t * 0.03
	camera.v_offset = cos(tm * 37.0) * shake * 0.25 + absf(sin(rig.phase)) * speed_t * 0.06
	camera.rotation.z = sin(tm * 29.0) * shake * 0.04
