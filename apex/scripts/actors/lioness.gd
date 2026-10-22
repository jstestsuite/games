class_name Lioness
extends BigCat
## A lioness of the pride. Before you take the pride she rests at the den (DEN).
## After, she FOLLOWs you: close behind while you walk, fanned out wide on your flanks
## while you stalk, so a herd that bolts from you often runs into her.
## She HUNTs anything fleeing nearby (or helps HOLD what you've grabbed), then EATs.
## Whatever the lionesses eat counts toward the pride's daily food.

enum LState { DEN, FOLLOW, HUNT, HOLD, EAT, LEAVE }

var lstate := LState.DEN
var player: Lion
var den := Vector3.ZERO
var slot := 0                 # 0, 1, 2...: alternates left/right, further out each pair
var stalking := false
var in_cover := false
var notice_mult := 1.0
var target: Prey
var _t := 0.0
var _charge_left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("hunter")
	add_to_group("lioness")
	collision_layer = 4
	collision_mask = 1
	_rng.randomize()
	_init_body(false)
	notice_mult = Tuning.LIONESS_NOTICE_MULT
	health = health_max()


func join() -> void:
	_go(LState.FOLLOW)


func leave() -> void:
	_go(LState.LEAVE)
	remove_from_group("hunter")


func thrown_off() -> void:
	knock = -forward() * Tuning.KNOCKBACK * 1.5
	target = null
	_go(LState.FOLLOW)


func _go(s: LState) -> void:
	lstate = s
	_t = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	notice_mult = Tuning.LIONESS_NOTICE_MULT
	stalking = false
	match lstate:
		LState.DEN:
			speed = move_toward(speed, 0.0, 6.0 * delta)
			if global_position.distance_to(den) > 6.0:
				steer_towards(den, 3.0, delta)
				speed = Tuning.WALK_SPEED * 0.7
		LState.FOLLOW:
			_follow(delta)
		LState.HUNT:
			_hunt(delta)
		LState.HOLD:
			_hold(delta)
		LState.EAT:
			_eat(delta)
		LState.LEAVE:
			if player:
				var away := global_position - player.global_position
				heading = lerp_angle(heading, atan2(-away.x, -away.z), 1.0 - exp(-3.0 * delta))
			speed = move_toward(speed, Tuning.WALK_SPEED, 6.0 * delta)
			if _t > 12.0:
				queue_free()
	_move_body(delta)
	in_cover = terrain != null and terrain.is_in_tall_grass(global_position)
	_update_look(delta)


func _follow(delta: float) -> void:
	if player == null or player.is_dead:
		speed = move_toward(speed, 0.0, 6.0 * delta)
		return
	stalking = player.stalking
	var side := -1.0 if slot % 2 == 0 else 1.0
	var rank := float(slot / 2) + 1.0
	var fwd := player.forward()
	var right := fwd.cross(Vector3.UP)
	var spot: Vector3
	if player.stalking:
		spot = player.global_position + right * side * Tuning.LIONESS_FLANK_SPREAD * rank + fwd * 3.0
	else:
		spot = player.global_position + right * side * Tuning.LIONESS_FOLLOW_SPREAD * 0.6 * rank - fwd * 4.0 * rank
	var to := spot - global_position
	to.y = 0
	var d := to.length()
	if d > 1.5:
		steer_towards(spot, 5.0, delta)
		var want := Tuning.WALK_SPEED * clampf(d / 4.0, 0.3, 1.3)
		if stalking:
			# Creep when in position; slink up faster (still low) when behind.
			want = Tuning.STALK_SPEED * clampf(d / 3.0, 0.5, 2.2)
		elif d > 22.0:
			want = Tuning.LIONESS_RUN_SPEED
		speed = move_toward(speed, want, 12.0 * delta)
	else:
		speed = move_toward(speed, 0.0, 8.0 * delta)
		face_towards(global_position + fwd, 2.0, delta)

	# Join in when something nearby is running or already caught.
	var prey := _find_target()
	if prey:
		target = prey
		_charge_left = Tuning.LIONESS_CHARGE_TIME
		_go(LState.HUNT)
		return
	# Eat when you're eating, or a carcass is right here.
	var c := _nearest_carcass(12.0)
	if c and (player.state == Lion.State.EATING or flat_dist(player) < 30.0) and not player.sprinting:
		target = c
		_go(LState.EAT)


func _find_target() -> Prey:
	var best: Prey = null
	var best_d := Tuning.LIONESS_ENGAGE_RANGE
	for node in get_tree().get_nodes_in_group("prey"):
		var g := node as Prey
		if g == null or g.is_dead:
			continue
		if g.state != Prey.State.FLEE and g.state != Prey.State.GRABBED:
			continue
		var d := flat_dist(g)
		if g.state == Prey.State.GRABBED:
			d *= 0.5   # helping hold something is the priority
		if d < best_d:
			best_d = d
			best = g
	return best


func _hunt(delta: float) -> void:
	if not is_instance_valid(target):
		_go(LState.FOLLOW)
		return
	if target.is_dead:
		_go(LState.EAT)
		return
	var d := flat_dist(target)
	if _t > Tuning.LIONESS_CHASE_MAX or d > Tuning.LIONESS_ENGAGE_RANGE * 1.8 \
			or target.state == Prey.State.GRAZE or target.state == Prey.State.ALERT:
		target = null
		_go(LState.FOLLOW)
		return
	# Run to where it will be, not where it is.
	var lead := target.global_position + target.velocity * clampf(d / maxf(speed, 5.0), 0.0, 1.2)
	steer_towards(lead, 7.0, delta)
	var want := Tuning.LIONESS_RUN_SPEED
	if _charge_left > 0.0:
		_charge_left -= delta
		want = Tuning.LIONESS_CHARGE_SPEED
	if target.state == Prey.State.GRABBED and d < 6.0:
		want = Tuning.WALK_SPEED
	speed = move_toward(speed, want, 20.0 * delta)
	if d < Tuning.POUNCE_CATCH_RADIUS + 0.3:
		if target.grab(self):
			_go(LState.HOLD)


func _hold(delta: float) -> void:
	if not is_instance_valid(target):
		_go(LState.FOLLOW)
		return
	if target.is_dead:
		_go(LState.EAT)
		return
	if target.state != Prey.State.GRABBED or not target.grabbers.has(self):
		target = null
		_go(LState.FOLLOW)
		return
	var pf := Vector3(-sin(target.heading), 0, -cos(target.heading))
	var pr := pf.cross(Vector3.UP)
	var idx := target.grabbers.find(self)
	var spot := target.global_position - pr * 0.9 + pf * (0.2 - idx * 0.6)
	global_position.x = lerpf(global_position.x, spot.x, 1.0 - exp(-12.0 * delta))
	global_position.z = lerpf(global_position.z, spot.z, 1.0 - exp(-12.0 * delta))
	face_towards(target.global_position, 10.0, delta)
	speed = 0.0


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


func _eat(delta: float) -> void:
	# They stay with their own kill; at yours, they don't wander off far from you.
	if not is_instance_valid(target) or target.food_left <= 0.0 \
			or (player and not target.killed_by_pride and flat_dist(player) > 40.0):
		target = null
		_go(LState.FOLLOW)
		return
	var d := flat_dist(target)
	if d > 2.2:
		steer_towards(target.global_position, 6.0, delta)
		speed = move_toward(speed, Tuning.WALK_SPEED, 10.0 * delta)
		return
	speed = 0.0
	face_towards(target.global_position, 4.0, delta)
	GameState.pride_food += target.take_food(Tuning.LIONESS_EAT_RATE * delta)
	# Something new to chase beats finishing a meal.
	if _t > 1.0:
		var prey := _find_target()
		if prey and prey.state == Prey.State.GRABBED:
			target = prey
			_go(LState.HUNT)


func get_posture() -> float:
	match lstate:
		LState.HUNT, LState.HOLD:
			return Tuning.POSTURE_SPRINT
		LState.EAT:
			return Tuning.POSTURE_WALK * 0.6
		LState.DEN:
			return Tuning.POSTURE_STALK * 0.5
	if stalking:
		# Slinking fast is less hidden than creeping.
		return Tuning.POSTURE_STALK * maxf(1.0, speed / Tuning.STALK_SPEED)
	if speed < 0.3:
		return Tuning.POSTURE_STALK * 0.7
	return Tuning.POSTURE_WALK


func _update_look(delta: float) -> void:
	var crouch := 0.0
	var head_down := 0.0
	rig.lunge = 0.0
	match lstate:
		LState.DEN:
			crouch = 0.9 if speed < 0.5 else 0.0
		LState.EAT:
			if speed < 0.5:
				crouch = 0.6
				head_down = 1.0
		LState.HOLD:
			crouch = 0.4
			rig.lunge = 0.6
	if stalking and lstate == LState.FOLLOW:
		crouch = 1.0
	_pose_rig(delta, clampf(speed / Tuning.CHARGE_SPEED, 0.0, 1.0), crouch, head_down)
