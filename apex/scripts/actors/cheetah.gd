class_name Cheetah
extends CharacterBody3D
## The player predator. Stalk (Ctrl), walk, sprint (Shift), pounce (Space / LMB).
## Animals don't strafe: you steer a heading, and at sprint speed you turn wide.

signal caught_prey(prey: Node3D)

enum State { MOVE, POUNCE, EATING }

var terrain: Terrain
var state := State.MOVE
var heading := 0.0            # yaw, radians
var speed := 0.0
var stamina := Tuning.STAMINA_MAX
var exhausted := false
var stalking := false
var sprinting := false
var in_cover := false
var controls_enabled := true

var _pounce_t := 0.0
var _pounce_cd := 0.0
var _eat_t := 0.0
var _eat_target: Node3D
var _cam_yaw := 0.0
var _cam_pitch := -0.22
var _trauma := 0.0
var _floor_normal := Vector3.UP

var rig: AnimalRig
var cam_pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D


func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.8
	floor_max_angle = deg_to_rad(50)

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.2
	col.shape = shape
	col.position.y = 0.62
	add_child(col)

	rig = AnimalRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.build({
		"body_len": 1.35, "body_r": 0.25, "leg_len": 0.72, "leg_r": 0.065,
		"neck_len": 0.34, "neck_r": 0.13, "neck_pitch": -1.05, "head_r": 0.15, "head_len": 1.05,
		"tail_len": 0.85, "tail_tip": true, "ear": 0.8, "stride": 1.4,
		"coat": {
			"base_color": Color(0.86, 0.63, 0.30), "belly_color": Color(0.96, 0.90, 0.76),
			"spot_color": Color(0.10, 0.07, 0.05), "spot_amount": 0.24, "spot_scale": 11.0,
			"belly_height": -0.05,
		},
	})

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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_cam_yaw -= event.relative.x * Tuning.MOUSE_SENS
		_cam_pitch = clampf(_cam_pitch - event.relative.y * Tuning.MOUSE_SENS, -1.1, 0.35)


func _physics_process(delta: float) -> void:
	_pounce_cd = maxf(0.0, _pounce_cd - delta)
	match state:
		State.MOVE:
			_move(delta)
		State.POUNCE:
			_pounce(delta)
		State.EATING:
			_eat(delta)

	if not is_on_floor():
		velocity.y -= 30.0 * delta
	elif state != State.POUNCE:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()

	if is_on_floor():
		_floor_normal = _floor_normal.lerp(get_floor_normal(), 1.0 - exp(-8.0 * delta)).normalized()
	in_cover = terrain != null and terrain.is_in_tall_grass(global_position)
	_update_rig(delta)


func _process(delta: float) -> void:
	_update_camera(delta)


# --- states ----------------------------------------------------------------

func _move(delta: float) -> void:
	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var has_input := input.length() > 0.1

	stalking = controls_enabled and Input.is_action_pressed("stalk")
	var want_sprint := controls_enabled and Input.is_action_pressed("sprint") and has_input and not stalking
	if exhausted and stamina >= Tuning.STAMINA_MIN_TO_SPRINT:
		exhausted = false
	sprinting = want_sprint and not exhausted and stamina > 0.0

	var max_stamina := Tuning.STAMINA_MAX * GameState.mod("stamina")
	if sprinting:
		stamina -= delta
		if stamina <= 0.0:
			stamina = 0.0
			exhausted = true
			sprinting = false
			GameState.message.emit("Out of breath!")
	elif speed < 0.5:
		# Stamina is a day-long budget: only resting in place wins a little back.
		var regen := Tuning.STAMINA_REST_REGEN * GameState.mod("stamina_regen")
		stamina = minf(max_stamina, stamina + regen * delta)

	var target_speed := 0.0
	if has_input:
		if sprinting:
			target_speed = Tuning.SPRINT_SPEED * GameState.mod("sprint_speed")
		elif stalking:
			target_speed = Tuning.STALK_SPEED
		else:
			target_speed = Tuning.WALK_SPEED

	if has_input:
		# Camera-relative desired heading.
		var world_dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, _cam_yaw)
		var desired := atan2(-world_dir.x, -world_dir.z)
		var t := clampf(speed / Tuning.SPRINT_SPEED, 0.0, 1.0)
		var turn := lerpf(Tuning.TURN_RATE_WALK, Tuning.TURN_RATE_SPRINT * GameState.mod("sprint_turn"), t)
		var diff := wrapf(desired - heading, -PI, PI)
		heading += clampf(diff, -turn * delta, turn * delta)
		# Asking to go the opposite way at speed = brake.
		if absf(diff) > 2.2 and speed > Tuning.WALK_SPEED:
			target_speed = 0.0

	var accel := Tuning.ACCEL_SPRINT if sprinting else Tuning.ACCEL_WALK
	if target_speed < speed:
		accel *= 1.8   # braking is quicker than building speed
	speed = move_toward(speed, target_speed, accel * delta)
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed

	if controls_enabled and Input.is_action_just_pressed("pounce") and _pounce_cd <= 0.0 \
			and stamina >= Tuning.POUNCE_STAMINA_COST:
		_start_pounce()


func _start_pounce() -> void:
	state = State.POUNCE
	_pounce_t = 0.0
	stamina -= Tuning.POUNCE_STAMINA_COST
	sprinting = false
	velocity.y = 6.0
	_trauma = maxf(_trauma, 0.25)


func _pounce(delta: float) -> void:
	_pounce_t += delta
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	var reach := GameState.mod("pounce_range")
	var spd := maxf(speed, Tuning.POUNCE_SPEED)
	velocity.x = fwd.x * spd
	velocity.z = fwd.z * spd

	# A little homing makes pounces feel fair against jinking prey.
	var target := _find_catchable(8.0)
	if target:
		var to := target.global_position - global_position
		heading = lerp_angle(heading, atan2(-to.x, -to.z), 1.0 - exp(-Tuning.POUNCE_HOMING * delta))
	var prey := _find_catchable(Tuning.POUNCE_CATCH_RADIUS * reach)
	if prey:
		_catch(prey)
		return
	if _pounce_t >= Tuning.POUNCE_DURATION * reach:
		state = State.MOVE
		_pounce_cd = Tuning.POUNCE_COOLDOWN
		speed = speed * 0.45   # landing kills momentum: a missed pounce costs you


func _find_catchable(radius: float) -> Gazelle:
	var best: Gazelle = null
	var best_d := radius
	for node in get_tree().get_nodes_in_group("prey"):
		var g := node as Gazelle
		if g == null or g.is_dead:
			continue
		# Measure from the jaws, not the middle of the body.
		var jaws := global_position + Vector3(-sin(heading), 0, -cos(heading)) * 0.9
		var d := g.global_position.distance_to(jaws)
		if d < best_d:
			best_d = d
			best = g
	return best


func _catch(prey: Gazelle) -> void:
	prey.die()
	state = State.EATING
	_eat_t = 2.4
	_eat_target = prey
	speed = 0.0
	velocity = Vector3.ZERO
	_trauma = 0.7
	GameState.register_kill()
	caught_prey.emit(prey)
	# Hit-stop: a tiny freeze sells the impact.
	Engine.time_scale = 0.05
	get_tree().create_timer(Tuning.HITSTOP_TIME, true, false, true).timeout.connect(
		func(): Engine.time_scale = 1.0)


func _eat(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	_eat_t -= delta
	if is_instance_valid(_eat_target):
		var to := _eat_target.global_position - global_position
		if to.length() > 0.1:
			heading = lerp_angle(heading, atan2(-to.x, -to.z), 1.0 - exp(-6.0 * delta))
	if _eat_t <= 0.0:
		state = State.MOVE
		var max_stamina := Tuning.STAMINA_MAX * GameState.mod("stamina")
		stamina = minf(max_stamina, stamina + Tuning.STAMINA_EAT_RESTORE * GameState.mod("stamina_regen"))
		_pounce_cd = 0.3


# --- what prey can sense ------------------------------------------------------

## How "loud/visible" the cheetah is right now, before distance and cover.
func get_posture() -> float:
	if state == State.EATING:
		return Tuning.POSTURE_WALK * 0.6
	if state == State.POUNCE or sprinting:
		return Tuning.POSTURE_SPRINT
	if stalking:
		return Tuning.POSTURE_STALK * GameState.mod("stalk_noise")
	if speed < 0.3:
		return Tuning.POSTURE_STALK * 0.7
	return Tuning.POSTURE_WALK


# --- presentation --------------------------------------------------------------

func _update_rig(delta: float) -> void:
	rig.rotation = Vector3.ZERO
	var b := Basis(Vector3.UP, heading)
	# Tilt to the slope.
	var up := _floor_normal
	var fwd := -b.z
	var right := fwd.cross(up).normalized()
	fwd = up.cross(right).normalized()
	rig.global_basis = Basis(right, up, -fwd)
	# Bank into sprint turns.
	var crouch := 1.0 if (stalking and state == State.MOVE) else 0.0
	if state == State.EATING:
		crouch = 0.6
	var head_down := 1.0 if state == State.EATING else 0.0
	var speed_norm := clampf(speed / Tuning.SPRINT_SPEED, 0.0, 1.0)
	if state == State.POUNCE:
		speed_norm = 1.0
		crouch = 0.0
	rig.animate(delta, speed, speed_norm, crouch, head_down)
	if state == State.POUNCE:
		rig.torso.rotation.x = -0.25


func _update_camera(delta: float) -> void:
	var target := global_position + Vector3(0, Tuning.CAM_HEIGHT * (0.75 if stalking else 1.0), 0)
	cam_pivot.global_position = cam_pivot.global_position.lerp(target, 1.0 - exp(-14.0 * delta))
	cam_pivot.rotation = Vector3(_cam_pitch, _cam_yaw, 0)
	var speed_t := clampf(speed / Tuning.SPRINT_SPEED, 0.0, 1.0)
	var fov_target := lerpf(Tuning.FOV_BASE, Tuning.FOV_SPRINT, speed_t * speed_t)
	camera.fov = lerpf(camera.fov, fov_target, 1.0 - exp(-4.0 * delta))
	spring.spring_length = lerpf(spring.spring_length, Tuning.CAM_DISTANCE * (1.0 + speed_t * 0.25), 1.0 - exp(-3.0 * delta))

	_trauma = maxf(0.0, _trauma - delta * 1.6)
	var shake := _trauma * _trauma
	var tm := Time.get_ticks_msec() * 0.001
	camera.h_offset = sin(tm * 41.0) * shake * 0.25 + sin(tm * 3.1) * speed_t * 0.03
	camera.v_offset = cos(tm * 37.0) * shake * 0.25 + absf(sin(rig.phase)) * speed_t * 0.06
	camera.rotation.z = sin(tm * 29.0) * shake * 0.04
