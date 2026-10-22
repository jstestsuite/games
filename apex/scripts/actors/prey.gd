class_name Prey
extends CharacterBody3D
## Prey AI for every species (warthog, zebra, wildebeest, buffalo). Numbers come from
## Tuning, looked up by species prefix (e.g. ZEBRA_SPEED).
## Senses every hunter (the player and lionesses) by sight and scent, builds an
## awareness meter: GRAZE -> ALERT -> FLEE. Buffalo may DEFEND (charge you) instead.
## When grabbed it struggles and kicks until the takedown finishes, then it becomes a
## carcass that lions and hyenas eat from.

signal became_carcass(prey: Prey)

enum State { GRAZE, ALERT, FLEE, DEFEND, GRABBED, DEAD }

const NAMES := {"WARTHOG": "Warthog", "ZEBRA": "Zebra", "WILDEBEEST": "Wildebeest", "BUFFALO": "Buffalo"}

var species := "ZEBRA"
var state := State.GRAZE
var awareness := 0.0
var is_dead := false
var herd: Herd
var terrain: Terrain
var wind := Vector2(1, 0)          # set by main; direction the wind blows TOWARD

var heading := 0.0
var speed := 0.0
var head_down := 0.0
var food_left := 0.0
var food_total := 1.0
var killed_by_pride := false
var weak := false                  # young or old: smaller and slower
var grabbers: Array[Node3D] = []
var takedown := 0.0                # 0..1

var _grazing := true
var _graze_timer := 0.0
var _wander_target := Vector3.ZERO
var _wander_pause := 0.0
var _flee_t := 0.0
var _jink_t := 0.0
var _jink := 0.0
var _panic_t := -1.0
var _kick_t := 0.0
var _defend_target: Node3D
var _defend_t := 0.0
var _defend_rolled := false
var _carcass_t := 0.0
var _floor_normal := Vector3.UP
var _rng := RandomNumberGenerator.new()
var _size := 1.0
var _height := 1.5
var rig: AnimalRig
var marker: Label3D


## Tuning value for this species, e.g. p("SPEED") -> Tuning.ZEBRA_SPEED.
func p(key: String) -> float:
	return float(Tuning.get(species + "_" + key))


func display_name() -> String:
	return NAMES.get(species, species.capitalize())


func _ready() -> void:
	add_to_group("prey")
	_rng.randomize()
	floor_snap_length = 0.8
	collision_layer = 2           # prey don't block the camera spring arm
	collision_mask = 1 | 2

	var spec := _spec()
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = spec.body_r
	shape.height = maxf(spec.leg_len + spec.body_r * 2.0, shape.radius * 2.0 + 0.05)
	col.shape = shape
	col.position.y = shape.height * 0.5
	add_child(col)

	rig = AnimalRig.new()
	add_child(rig)
	weak = _rng.randf() < Tuning.PREY_WEAK_CHANCE
	_size = _rng.randf_range(0.92, 1.08) * (0.78 if weak else 1.0)
	rig.build(spec)
	_height = spec.leg_len + spec.body_r + spec.neck_len + 0.5

	marker = Label3D.new()
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.fixed_size = true
	marker.pixel_size = 0.0016
	marker.font_size = 48
	marker.outline_size = 12
	marker.position.y = _height + 0.3
	marker.visible = false
	add_child(marker)

	heading = _rng.randf() * TAU
	_graze_timer = _rng.randf_range(1.0, 5.0)
	_pick_wander()


func _spec() -> Dictionary:
	match species:
		"WARTHOG":
			return {"body_len": 0.8, "body_r": 0.24, "leg_len": 0.36, "leg_r": 0.05,
				"neck_len": 0.12, "neck_r": 0.13, "neck_pitch": -0.25, "head_r": 0.16, "head_len": 1.5,
				"tail_len": 0.32, "ear": 0.8, "tusks": true, "hooves": true, "stride": 0.8,
				"coat": {"base_color": Color(0.40, 0.34, 0.30), "belly_color": Color(0.36, 0.31, 0.27),
					"belly_height": 0.0, "roughness_val": 0.95}}
		"WILDEBEEST":
			return {"body_len": 1.45, "body_r": 0.32, "leg_len": 0.85, "leg_r": 0.06,
				"neck_len": 0.42, "neck_r": 0.15, "neck_pitch": -0.45, "head_r": 0.15, "head_len": 1.8,
				"tail_len": 0.55, "ear": 0.9, "horns": true, "horn_scale": 0.9, "hooves": true,
				"stride": 1.5, "back_slope": 0.1,
				"coat": {"base_color": Color(0.38, 0.36, 0.35), "belly_color": Color(0.30, 0.28, 0.27),
					"belly_height": 0.0, "stripe_amount": 0.12, "stripe_scale": 14.0,
					"stripe_color": Color(0.18, 0.16, 0.15), "roughness_val": 0.9}}
		"BUFFALO":
			return {"body_len": 1.8, "body_r": 0.45, "leg_len": 0.75, "leg_r": 0.1,
				"neck_len": 0.3, "neck_r": 0.25, "neck_pitch": -0.25, "head_r": 0.22, "head_len": 1.4,
				"tail_len": 0.6, "ear": 1.1, "horns": true, "horn_scale": 1.4, "hooves": true, "stride": 1.6,
				"coat": {"base_color": Color(0.16, 0.14, 0.13), "belly_color": Color(0.13, 0.12, 0.11),
					"belly_height": 0.0, "roughness_val": 0.8}}
		_:
			return {"body_len": 1.4, "body_r": 0.3, "leg_len": 0.9, "leg_r": 0.06,
				"neck_len": 0.55, "neck_r": 0.13, "neck_pitch": -0.6, "head_r": 0.14, "head_len": 1.9,
				"tail_len": 0.5, "ear": 1.2, "hooves": true, "stride": 1.5,
				"coat": {"base_color": Color(0.93, 0.91, 0.87), "belly_color": Color(0.95, 0.94, 0.9),
					"belly_height": -0.15, "stripe_amount": 0.45, "stripe_scale": 26.0,
					"stripe_color": Color(0.06, 0.06, 0.06), "roughness_val": 0.85}}


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_carcass_tick(delta)
		return
	if state != State.GRABBED:
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
	var gain := 0.0
	for node in get_tree().get_nodes_in_group("hunter"):
		var h := node as Node3D
		if h == null or h.get("is_dead"):
			continue
		gain += _sense_one(h)

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


func _sense_one(h: Node3D) -> float:
	var to_me := global_position - h.global_position
	to_me.y = 0
	var d := to_me.length()
	var notice: float = h.get("notice_mult") if h.get("notice_mult") != null else 1.0
	var in_cover: bool = h.get("in_cover") == true
	var gain := 0.0
	if d < Tuning.SIGHT_RANGE:
		var closeness := 1.0 - d / Tuning.SIGHT_RANGE
		var sight: float = h.get_posture() * closeness * p("VIGILANCE")
		if in_cover:
			sight *= Tuning.COVER_MULT
		if _grazing and state == State.GRAZE:
			sight *= Tuning.GRAZE_SIGHT_MULT   # head in the grass: this is your window
		elif state == State.ALERT:
			sight *= 1.5
		gain += sight
		if d < Tuning.PERSONAL_SPACE:
			gain += Tuning.PERSONAL_SPACE_RATE * (1.0 - d / Tuning.PERSONAL_SPACE) \
					* (0.5 if in_cover else 1.0) * (0.6 if _grazing else 1.0)
	if d < Tuning.SCENT_RANGE and d > 0.01:
		var w3 := Vector3(wind.x, 0, wind.y)
		var downwind := w3.dot(to_me / d)   # 1 = I'm directly downwind of the hunter
		if downwind > 0.5:
			var scent_mod := GameState.mod("scent") if h.is_in_group("player") else 1.0
			gain += Tuning.SCENT_STRENGTH * (1.0 - d / Tuning.SCENT_RANGE) * (downwind - 0.5) * 2.0 * scent_mod
	return gain * notice


func spook(delay: float) -> void:
	if state in [State.FLEE, State.DEAD, State.GRABBED, State.DEFEND] or _panic_t >= 0.0:
		return
	_panic_t = delay


func _nearest_hunter() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("hunter"):
		var h := node as Node3D
		if h == null or h.get("is_dead"):
			continue
		var d := h.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = h
	return best


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
			var h := _nearest_hunter()
			if h:
				var to := h.global_position - global_position
				heading = lerp_angle(heading, atan2(-to.x, -to.z), 1.0 - exp(-3.0 * delta))
				if species == "BUFFALO" and not _defend_rolled and to.length() < Tuning.BUFFALO_CHARGE_RANGE:
					_defend_rolled = true
					if _rng.randf() < Tuning.BUFFALO_DEFEND_CHANCE:
						_start_defend(h)
						return
			if awareness >= Tuning.FLEE_THRESHOLD:
				_start_flee()
			elif awareness < Tuning.ALERT_THRESHOLD * 0.5:
				state = State.GRAZE
				_defend_rolled = false
		State.FLEE:
			_flee(delta)
		State.DEFEND:
			_defend(delta)
		State.GRABBED:
			_struggle(delta)


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
		speed = move_toward(speed, Tuning.GRAZE_SPEED, 3.0 * delta)


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
	var h := _nearest_hunter()
	if h:
		var away := global_position - h.global_position
		heading = atan2(-away.x, -away.z)
	# Panic spreads to anything nearby, herd or not.
	for node in get_tree().get_nodes_in_group("prey"):
		var g := node as Prey
		if g and g != self and not g.is_dead \
				and g.global_position.distance_to(global_position) < Tuning.PANIC_RADIUS:
			g.spook(_rng.randf_range(Tuning.PANIC_DELAY_MIN, Tuning.PANIC_DELAY_MAX))


func _flee(delta: float) -> void:
	_flee_t += delta
	var away := Vector3.FORWARD
	var d := 999.0
	var h := _nearest_hunter()
	if h:
		away = global_position - h.global_position
		away.y = 0
		d = away.length()
		away = away.normalized()

	var dir := (away + _edge_push() * 2.5).normalized()

	_jink_t -= delta
	if _jink_t <= 0.0:
		_jink_t = _rng.randf_range(Tuning.JINK_INTERVAL_MIN, Tuning.JINK_INTERVAL_MAX)
		# Jink harder when the hunter is close.
		var close := clampf(1.0 - d / 25.0, 0.2, 1.0)
		_jink = (1.0 if _rng.randf() > 0.5 else -1.0) * p("JINK") * close
	var desired := atan2(-dir.x, -dir.z) + _jink
	heading = lerp_angle(heading, desired, 1.0 - exp(-9.0 * delta))

	var top := p("SPEED") * (Tuning.PREY_WEAK_SPEED_MULT if weak else 1.0)
	if _flee_t > Tuning.TIRE_TIME:
		top *= Tuning.TIRED_SPEED_MULT
	speed = move_toward(speed, top, Tuning.PREY_ACCEL * delta)

	if _flee_t > Tuning.FLEE_TIME and d > Tuning.SIGHT_RANGE * 1.1:
		state = State.ALERT
		awareness = Tuning.ALERT_THRESHOLD + 0.2
		if herd:
			herd.center = global_position


func _edge_push() -> Vector3:
	var half := Tuning.WORLD_SIZE * 0.5 - 30.0
	var pos := global_position
	return Vector3(
		-clampf((absf(pos.x) - half) / 12.0, 0.0, 1.0) * signf(pos.x), 0,
		-clampf((absf(pos.z) - half) / 12.0, 0.0, 1.0) * signf(pos.z))


# --- buffalo defence ---------------------------------------------------------------

func _start_defend(target: Node3D) -> void:
	state = State.DEFEND
	_defend_target = target
	_defend_t = 0.0
	if target.is_in_group("player"):
		GameState.message.emit("The buffalo charges!")


func _defend(delta: float) -> void:
	_defend_t += delta
	if not is_instance_valid(_defend_target) or _defend_t > 3.5:
		_start_flee()
		return
	var to := _defend_target.global_position - global_position
	to.y = 0
	heading = lerp_angle(heading, atan2(-to.x, -to.z), 1.0 - exp(-5.0 * delta))
	speed = move_toward(speed, p("SPEED"), Tuning.PREY_ACCEL * delta)
	if to.length() < 2.2:
		if _defend_target.has_method("take_beast_hit"):
			_defend_target.take_beast_hit(Tuning.BUFFALO_CHARGE_DAMAGE, global_position, true)
		_start_flee()


# --- takedown -------------------------------------------------------------------

## A hunter grabs on. Returns false if it can't (already dead).
func grab(by: Node3D) -> bool:
	if is_dead:
		return false
	if not grabbers.has(by):
		grabbers.append(by)
	if state != State.GRABBED:
		state = State.GRABBED
		_kick_t = Tuning.KICK_INTERVAL
		_spread_panic()
	return true


func release(by: Node3D) -> void:
	grabbers.erase(by)
	if grabbers.is_empty() and state == State.GRABBED:
		takedown = 0.0
		awareness = Tuning.FLEE_THRESHOLD
		_start_flee()


func _spread_panic() -> void:
	for node in get_tree().get_nodes_in_group("prey"):
		var g := node as Prey
		if g and g != self and g.global_position.distance_to(global_position) < Tuning.PANIC_RADIUS * 1.5:
			g.spook(_rng.randf_range(Tuning.PANIC_DELAY_MIN, Tuning.PANIC_DELAY_MAX))


func _struggle(delta: float) -> void:
	# Drop anyone who let go or got knocked off.
	for g in grabbers.duplicate():
		if not is_instance_valid(g) or g.get("is_dead"):
			grabbers.erase(g)
	if grabbers.is_empty():
		release(null)
		return
	var power := 0.0
	var player_on := false
	var lionesses_on := 0
	for g in grabbers:
		if g.is_in_group("player"):
			power += GameState.strength * GameState.mod("takedown")
			player_on = true
		else:
			power += Tuning.LIONESS_TAKEDOWN_POWER
			lionesses_on += 1
	takedown += power / (Tuning.TAKEDOWN_TIME * p("TOUGHNESS")) * delta
	speed = move_toward(speed, Tuning.TAKEDOWN_DRAG_SPEED, 20.0 * delta)
	heading += sin(Time.get_ticks_msec() * 0.004 + get_instance_id()) * 1.5 * delta

	_kick_t -= delta
	if _kick_t <= 0.0:
		_kick_t = Tuning.KICK_INTERVAL
		if _rng.randf() < Tuning.KICK_CHANCE:
			if player_on:
				for g in grabbers:
					if g.is_in_group("player") and g.has_method("take_beast_hit"):
						g.take_beast_hit(p("KICK"), global_position, false)
			elif p("TOUGHNESS") > Tuning.LIONESS_TOUGHNESS_LIMIT * lionesses_on:
				# Too big for the lionesses alone: it throws them off.
				for g in grabbers.duplicate():
					if g.has_method("thrown_off"):
						g.thrown_off()
				grabbers.clear()
				release(null)
				return

	if takedown >= 1.0:
		killed_by_pride = not player_on
		if killed_by_pride:
			GameState.message.emit("Your lionesses brought down a %s." % display_name().to_lower())
		die()


func die() -> void:
	is_dead = true
	state = State.DEAD
	speed = 0.0
	velocity = Vector3.ZERO
	grabbers.clear()
	remove_from_group("prey")
	add_to_group("carcass")
	marker.visible = false
	collision_layer = 0
	food_total = p("FOOD") * (Tuning.PREY_WEAK_FOOD_MULT if weak else 1.0)
	food_left = food_total
	_carcass_t = 0.0
	var tw := create_tween()
	tw.tween_property(rig, "rotation:z", PI * 0.5, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rig, "position:y", 0.22, 0.35)
	became_carcass.emit(self)


## Take up to `amount` food from the carcass. Returns what was actually taken.
func take_food(amount: float) -> float:
	var got := minf(amount, food_left)
	food_left -= got
	return got


func _carcass_tick(delta: float) -> void:
	_carcass_t += delta
	var frac := clampf(food_left / maxf(food_total, 1.0), 0.0, 1.0)
	rig.scale = Vector3.ONE * lerpf(0.55, 1.0, frac)
	if food_left <= 0.0 or _carcass_t > Tuning.CARCASS_LIFETIME:
		remove_from_group("carcass")
		queue_free()


# --- presentation ----------------------------------------------------------------

func _update_visuals(delta: float) -> void:
	var up := _floor_normal
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	var right := fwd.cross(up).normalized()
	fwd = up.cross(right).normalized()
	rig.global_basis = Basis(right, up, -fwd).scaled(Vector3.ONE * _size)
	head_down = lerpf(head_down, 1.0 if (_grazing and state == State.GRAZE) else 0.0, 1.0 - exp(-4.0 * delta))
	var sn := clampf(speed / maxf(p("SPEED"), 1.0), 0.0, 1.0)
	if state == State.GRABBED:
		sn = 0.9   # thrashing
	rig.animate(delta, speed, sn, 0.0, head_down)

	match state:
		State.FLEE, State.GRABBED:
			marker.visible = true
			marker.text = "!"
			marker.modulate = Color(1.0, 0.3, 0.2)
		State.DEFEND:
			marker.visible = true
			marker.text = "!!"
			marker.modulate = Color(1.0, 0.1, 0.1)
		State.ALERT:
			marker.visible = true
			marker.text = "?"
			marker.modulate = Color(1.0, 0.85, 0.3)
		_:
			marker.visible = awareness > 0.2
			marker.text = "?"
			marker.modulate = Color(1, 1, 1, clampf((awareness - 0.2) / 0.25, 0.0, 0.8))
