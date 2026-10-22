class_name Gazelle
extends CharacterBody3D
## Prey AI. Senses the player by sight (distance, posture, cover, head up/down)
## and by scent (wind). Builds an awareness meter: GRAZE -> ALERT -> FLEE.
## Fleeing gazelles jink (sharp direction changes) and spook their herd.

enum State { GRAZE, ALERT, FLEE, DEAD }

var state := State.GRAZE
var awareness := 0.0
var is_dead := false
var herd: Herd
var terrain: Terrain
var player: Cheetah
var wind := Vector2(1, 0)          # set by main; direction the wind blows TOWARD

var heading := 0.0
var speed := 0.0
var head_down := 0.0
var _grazing := true
var _graze_timer := 0.0
var _wander_target := Vector3.ZERO
var _wander_pause := 0.0
var _flee_t := 0.0
var _jink_t := 0.0
var _jink := 0.0
var _panic_t := -1.0
var _floor_normal := Vector3.UP
var _rng := RandomNumberGenerator.new()

var _size := 1.0
var rig: AnimalRig
var marker: Label3D


func _ready() -> void:
	add_to_group("prey")
	_rng.randomize()
	floor_snap_length = 0.8
	collision_layer = 2           # prey don't block the camera spring arm
	collision_mask = 1 | 2

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.1
	col.shape = shape
	col.position.y = 0.75
	add_child(col)

	rig = AnimalRig.new()
	add_child(rig)
	_size = _rng.randf_range(0.92, 1.08)
	rig.build({
		"body_len": 1.0, "body_r": 0.22, "leg_len": 0.78, "leg_r": 0.045,
		"neck_len": 0.42, "neck_r": 0.09, "neck_pitch": -0.5, "head_r": 0.11, "head_len": 1.35,
		"tail_len": 0.18, "ear": 1.4, "horns": true, "hooves": true, "stride": 1.3,
		"coat": {
			"base_color": Color(0.72, 0.45, 0.22), "belly_color": Color(0.97, 0.94, 0.88),
			"belly_height": 0.0, "roughness_val": 0.8,
		},
	})

	marker = Label3D.new()
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.fixed_size = true
	marker.pixel_size = 0.0016
	marker.font_size = 48
	marker.outline_size = 12
	marker.position.y = 2.1
	marker.visible = false
	add_child(marker)

	heading = _rng.randf() * TAU
	_graze_timer = _rng.randf_range(1.0, 5.0)
	_pick_wander()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_sense(delta)
	_think(delta)

	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	if not is_on_floor():
		velocity.y -= 30.0 * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()
	if is_on_floor():
		_floor_normal = _floor_normal.lerp(get_floor_normal(), 1.0 - exp(-8.0 * delta)).normalized()
	_update_visuals(delta)


# --- senses ---------------------------------------------------------------------

func _sense(delta: float) -> void:
	if player == null:
		return
	var to_me := global_position - player.global_position
	to_me.y = 0
	var d := to_me.length()
	var gain := 0.0

	if d < Tuning.SIGHT_RANGE:
		var closeness := 1.0 - d / Tuning.SIGHT_RANGE
		var sight := player.get_posture() * closeness
		if player.in_cover:
			sight *= Tuning.COVER_MULT
		if _grazing and state == State.GRAZE:
			sight *= 0.45   # head in the grass: this is your window
		elif state == State.ALERT:
			sight *= 1.5
		gain += sight
		if d < Tuning.PERSONAL_SPACE:
			gain += Tuning.PERSONAL_SPACE_RATE * (1.0 - d / Tuning.PERSONAL_SPACE) \
					* (0.5 if player.in_cover else 1.0) * (0.6 if _grazing else 1.0)

	if d < Tuning.SCENT_RANGE and d > 0.01:
		var w3 := Vector3(wind.x, 0, wind.y)
		var downwind := w3.dot(to_me / d)   # 1 = I'm directly downwind of the cat
		if downwind > 0.5:
			gain += Tuning.SCENT_STRENGTH * (1.0 - d / Tuning.SCENT_RANGE) \
					* (downwind - 0.5) * 2.0 * GameState.mod("scent")

	if gain > 0.04:
		awareness += gain * Tuning.AWARENESS_RATE * delta
	else:
		awareness -= Tuning.AWARENESS_DECAY * delta
	awareness = clampf(awareness, 0.0, 1.3)

	if _panic_t >= 0.0:
		_panic_t -= delta
		if _panic_t < 0.0 and state != State.FLEE:
			awareness = Tuning.FLEE_THRESHOLD
			_start_flee()


func spook(delay: float) -> void:
	if state == State.FLEE or state == State.DEAD or _panic_t >= 0.0:
		return
	_panic_t = delay


# --- decisions ----------------------------------------------------------------

func _think(delta: float) -> void:
	match state:
		State.GRAZE:
			_graze(delta)
			if awareness >= Tuning.ALERT_THRESHOLD:
				state = State.ALERT
				_alert_herd()
		State.ALERT:
			speed = move_toward(speed, 0.0, 8.0 * delta)
			_grazing = false
			if player:
				var to := player.global_position - global_position
				heading = lerp_angle(heading, atan2(-to.x, -to.z), 1.0 - exp(-3.0 * delta))
			if awareness >= Tuning.FLEE_THRESHOLD:
				_start_flee()
			elif awareness < Tuning.ALERT_THRESHOLD * 0.5:
				state = State.GRAZE
		State.FLEE:
			_flee(delta)


func _graze(delta: float) -> void:
	_graze_timer -= delta
	if _graze_timer <= 0.0:
		_grazing = not _grazing
		_graze_timer = _rng.randf_range(3.0, 7.0) if _grazing else _rng.randf_range(1.2, 2.8)

	var to := _wander_target - global_position
	to.y = 0
	if _wander_pause > 0.0:
		_wander_pause -= delta
		speed = move_toward(speed, 0.0, 4.0 * delta)
	elif to.length() < 1.0:
		_wander_pause = _rng.randf_range(2.0, 6.0)
		_pick_wander()
	else:
		heading = lerp_angle(heading, atan2(-to.x, -to.z), 1.0 - exp(-2.0 * delta))
		speed = move_toward(speed, Tuning.GAZELLE_GRAZE_SPEED, 3.0 * delta)


func _pick_wander() -> void:
	var c := herd.center if herd else global_position
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(2.0, 11.0)
	_wander_target = c + Vector3(cos(a) * r, 0, sin(a) * r)


func _alert_herd() -> void:
	if herd == null:
		return
	for m in herd.alive_members():
		if m != self and m.state == State.GRAZE:
			m.awareness = maxf(m.awareness, Tuning.ALERT_THRESHOLD * 0.8)


func _start_flee() -> void:
	state = State.FLEE
	_flee_t = 0.0
	_jink_t = _rng.randf_range(0.3, 0.6)
	_grazing = false
	if player:
		var away := global_position - player.global_position
		heading = atan2(-away.x, -away.z)
	# Panic spreads to anything nearby, herd or not.
	for node in get_tree().get_nodes_in_group("prey"):
		var g := node as Gazelle
		if g and g != self and not g.is_dead \
				and g.global_position.distance_to(global_position) < Tuning.PANIC_RADIUS:
			g.spook(_rng.randf_range(Tuning.PANIC_DELAY.x, Tuning.PANIC_DELAY.y))


func _flee(delta: float) -> void:
	_flee_t += delta
	var away := Vector3.FORWARD
	var d := 999.0
	if player:
		away = global_position - player.global_position
		away.y = 0
		d = away.length()
		away = away.normalized()

	# Steer away from the map edge.
	var half := Tuning.WORLD_SIZE * 0.5 - 30.0
	var p := global_position
	var edge_push := Vector3(
		-clampf((absf(p.x) - half) / 12.0, 0.0, 1.0) * signf(p.x), 0,
		-clampf((absf(p.z) - half) / 12.0, 0.0, 1.0) * signf(p.z))
	var dir := (away + edge_push * 2.5).normalized()

	_jink_t -= delta
	if _jink_t <= 0.0:
		_jink_t = _rng.randf_range(Tuning.GAZELLE_JINK_INTERVAL.x, Tuning.GAZELLE_JINK_INTERVAL.y)
		# Jink harder when the cat is close.
		var close := clampf(1.0 - d / 25.0, 0.2, 1.0)
		_jink = (1.0 if _rng.randf() > 0.5 else -1.0) * Tuning.GAZELLE_JINK_ANGLE * close
	var desired := atan2(-dir.x, -dir.z) + _jink
	heading = lerp_angle(heading, desired, 1.0 - exp(-9.0 * delta))

	var top := Tuning.GAZELLE_FLEE_SPEED
	if _flee_t > Tuning.GAZELLE_TIRE_TIME:
		top *= Tuning.GAZELLE_TIRED_SPEED_MULT
	speed = move_toward(speed, top, Tuning.GAZELLE_ACCEL * delta)

	if _flee_t > Tuning.GAZELLE_FLEE_TIME and d > Tuning.SIGHT_RANGE * 1.1:
		state = State.ALERT
		awareness = Tuning.ALERT_THRESHOLD + 0.2
		if herd:
			herd.center = global_position


func die() -> void:
	is_dead = true
	state = State.DEAD
	speed = 0.0
	velocity = Vector3.ZERO
	remove_from_group("prey")
	marker.visible = false
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(rig, "rotation:z", PI * 0.5, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rig, "position:y", 0.22, 0.35)


# --- presentation ----------------------------------------------------------------

func _update_visuals(delta: float) -> void:
	var up := _floor_normal
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	var right := fwd.cross(up).normalized()
	fwd = up.cross(right).normalized()
	rig.global_basis = Basis(right, up, -fwd).scaled(Vector3.ONE * _size)
	head_down = lerpf(head_down, 1.0 if (_grazing and state == State.GRAZE) else 0.0, 1.0 - exp(-4.0 * delta))
	rig.animate(delta, speed, clampf(speed / Tuning.GAZELLE_FLEE_SPEED, 0.0, 1.0), 0.0, head_down)

	match state:
		State.FLEE:
			marker.visible = true
			marker.text = "!"
			marker.modulate = Color(1.0, 0.3, 0.2)
		State.ALERT:
			marker.visible = true
			marker.text = "?"
			marker.modulate = Color(1.0, 0.85, 0.3)
		_:
			marker.visible = awareness > 0.2
			marker.text = "?"
			marker.modulate = Color(1, 1, 1, clampf((awareness - 0.2) / 0.25, 0.0, 0.8))
