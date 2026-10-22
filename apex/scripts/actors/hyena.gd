class_name Hyena
extends CharacterBody3D
## Hyenas come for carcasses. They feed if no lion is guarding it; otherwise they
## circle and dart in to bite the player ("!" = a bite is coming: swipe or dodge).
## A hit or a roar scatters them for a few seconds. Kill one and the rest still come back.
## Roamers are the local clan: they ROAM, shadowing you at a distance all day, and
## converge on any kill nearby. Others arrive at a kill and LEAVE when it's gone.

enum HState { APPROACH, CIRCLE, TELL, DART, RETREAT, FEED, SCATTER, LEAVE, DEAD, ROAM }

var hstate := HState.APPROACH
var roamer := false
var carcass: Prey
var player: Lion
var terrain: Terrain
var health := 30.0
var is_dead := false
var heading := 0.0
var speed := 0.0
var knock := Vector3.ZERO
var pack_size := 2
var _t := 0.0
var _dart_timer := 0.0
var _orbit := 0.0
var _orbit_dir := 1.0
var _floor_normal := Vector3.UP
var _rng := RandomNumberGenerator.new()
var rig: AnimalRig
var marker: Label3D


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("hyena")
	_rng.randomize()
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.8
	health = Tuning.HYENA_HEALTH
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.0
	col.shape = shape
	col.position.y = 0.55
	add_child(col)
	rig = AnimalRig.new()
	add_child(rig)
	rig.build({
		"body_len": 1.05, "body_r": 0.26, "leg_len": 0.6, "leg_r": 0.06,
		"neck_len": 0.32, "neck_r": 0.14, "neck_pitch": -0.8, "head_r": 0.15, "head_len": 1.3,
		"tail_len": 0.35, "ear": 1.0, "stride": 1.2, "back_slope": 0.18,
		"coat": {"base_color": Color(0.60, 0.50, 0.37), "belly_color": Color(0.70, 0.62, 0.5),
			"spot_color": Color(0.18, 0.13, 0.1), "spot_amount": 0.2, "spot_scale": 9.0,
			"belly_height": -0.05},
	})
	marker = Label3D.new()
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.fixed_size = true
	marker.pixel_size = 0.0016
	marker.font_size = 48
	marker.outline_size = 12
	marker.position.y = 1.7
	marker.visible = false
	add_child(marker)
	_orbit = _rng.randf() * TAU
	_orbit_dir = 1.0 if _rng.randf() > 0.5 else -1.0
	_reset_dart_timer()


func _go(s: HState) -> void:
	hstate = s
	_t = 0.0


func _reset_dart_timer() -> void:
	_dart_timer = Tuning.HYENA_DART_INTERVAL * _rng.randf_range(0.6, 1.4)


func _physics_process(delta: float) -> void:
	_t += delta
	if hstate == HState.DEAD:
		if _t > 6.0:
			queue_free()
		return
	var have_food := is_instance_valid(carcass) and carcass.food_left > 0.0
	if not have_food and hstate not in [HState.LEAVE, HState.SCATTER, HState.ROAM]:
		carcass = null
		_go(HState.ROAM if roamer else HState.LEAVE)
	var guarded := have_food and _guarded()

	match hstate:
		HState.ROAM:
			# Keep the lion in sight, at a respectful distance, from our own side.
			var spot := player.global_position + Vector3(cos(_orbit), 0, sin(_orbit)) * Tuning.HYENA_SHADOW_DIST
			_orbit += _orbit_dir * delta * 0.05
			if _flat(spot) > 4.0:
				_run_to(spot, Tuning.HYENA_SPEED * (0.4 if _flat(spot) < 25.0 else 0.8), delta)
			else:
				speed = move_toward(speed, 0.0, 10.0 * delta)
				_face(player.global_position, 3.0, delta)
		HState.APPROACH:
			_run_to(carcass.global_position, Tuning.HYENA_SPEED, delta)
			var d := _flat(carcass.global_position)
			if guarded and d < Tuning.HYENA_GUARD_RADIUS + 5.0:
				_go(HState.CIRCLE)
			elif not guarded and d < 1.6:
				_go(HState.FEED)
		HState.CIRCLE:
			if not guarded:
				_go(HState.APPROACH)
			else:
				_orbit += _orbit_dir * delta * 0.5
				var r := Tuning.HYENA_GUARD_RADIUS + 1.5 + sin(_t * 0.7) * 1.0
				var spot := carcass.global_position + Vector3(cos(_orbit), 0, sin(_orbit)) * r
				_run_to(spot, 5.5, delta)
				# Bolder in bigger packs, and when you're hurt.
				var bravery := 1.0 + 0.25 * (pack_size - 2)
				if player.health < player.health_max() * 0.5:
					bravery += 0.5
				_dart_timer -= delta * bravery
				if _dart_timer <= 0.0 and _flat(player.global_position) < r + 6.0:
					_go(HState.TELL)
		HState.TELL:
			speed = move_toward(speed, 0.0, 20.0 * delta)
			_face(player.global_position, 8.0, delta)
			if _t >= Tuning.HYENA_DART_TELL:
				_go(HState.DART)
		HState.DART:
			_run_to(player.global_position, Tuning.HYENA_SPEED * 1.2, delta)
			if _flat(player.global_position) < 1.7:
				if not player.is_invulnerable():
					player.take_beast_hit(Tuning.HYENA_BITE_DAMAGE, global_position, false, "hyenas")
				_reset_dart_timer()
				_go(HState.RETREAT)
			elif _t > 1.5:
				_reset_dart_timer()
				_go(HState.RETREAT)
		HState.RETREAT:
			_run_away_from(player.global_position, Tuning.HYENA_SPEED, delta)
			if _t > 0.9:
				_go(HState.CIRCLE)
		HState.FEED:
			speed = move_toward(speed, 0.0, 20.0 * delta)
			_face(carcass.global_position, 5.0, delta)
			carcass.take_food(Tuning.HYENA_EAT_RATE * delta)
			if guarded:
				_go(HState.CIRCLE)
		HState.SCATTER:
			_run_away_from(player.global_position, Tuning.HYENA_SPEED, delta)
			if _t > Tuning.HYENA_SCATTER_TIME:
				if have_food:
					_go(HState.APPROACH)
				else:
					_go(HState.ROAM if roamer else HState.LEAVE)
		HState.LEAVE:
			_run_away_from(player.global_position, Tuning.HYENA_SPEED * 0.7, delta)
			if _t > 8.0:
				queue_free()

	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	velocity.x = fwd.x * speed + knock.x
	velocity.z = fwd.z * speed + knock.z
	knock = knock.move_toward(Vector3.ZERO, 18.0 * delta)
	if not is_on_floor():
		velocity.y -= 30.0 * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()
	if is_on_floor():
		_floor_normal = _floor_normal.lerp(get_floor_normal(), 1.0 - exp(-8.0 * delta)).normalized()
	_update_look(delta)


## A lion near the carcass keeps hyenas off it. Lionesses count too.
func _guarded() -> bool:
	var r := Tuning.HYENA_GUARD_RADIUS
	if player and not player.is_dead and player.global_position.distance_to(carcass.global_position) < r:
		return true
	for n in get_tree().get_nodes_in_group("lioness"):
		var l := n as Node3D
		if l.global_position.distance_to(carcass.global_position) < r * 0.6:
			return true
	return false


func _flat(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _face(p: Vector3, rate: float, delta: float) -> void:
	var to := p - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		heading = lerp_angle(heading, atan2(-to.x, -to.z), 1.0 - exp(-rate * delta))


## Turn toward a direction, bent around rocks and trees.
func _steer(dir: Vector3, rate: float, delta: float) -> void:
	if terrain:
		dir = terrain.avoid(global_position, dir, 3.0 + speed * 0.4, 0.5)
	heading = lerp_angle(heading, atan2(-dir.x, -dir.z), 1.0 - exp(-rate * delta))


## Head for a kill (roamers are told when one happens nearby).
func go_to_carcass(c: Prey) -> void:
	if hstate == HState.DEAD:
		return
	carcass = c
	_go(HState.APPROACH)


func _run_to(p: Vector3, spd: float, delta: float) -> void:
	var to := p - global_position
	to.y = 0
	if to.length() > 0.05:
		_steer(to.normalized(), 7.0, delta)
	var want := spd if _flat(p) > 1.0 else 0.0
	speed = move_toward(speed, want, 25.0 * delta)


func _run_away_from(p: Vector3, spd: float, delta: float) -> void:
	var away := global_position - p
	away.y = 0
	if away.length() > 0.05:
		_steer(away.normalized(), 6.0, delta)
	speed = move_toward(speed, spd, 25.0 * delta)


## Roars scare hyenas (most of the time).
func scare() -> void:
	if hstate != HState.DEAD and _rng.randf() < Tuning.ROAR_SCARE_CHANCE:
		_go(HState.SCATTER)


func is_invulnerable() -> bool:
	return is_dead


func take_hit(damage: float, from: Vector3, heavy: bool) -> void:
	if is_dead:
		return
	health -= damage
	var away := global_position - from
	away.y = 0
	if away.length() > 0.01:
		knock = away.normalized() * Tuning.KNOCKBACK * (1.8 if heavy else 1.2)
	if health <= 0.0:
		is_dead = true
		remove_from_group("enemy")
		collision_layer = 0
		_go(HState.DEAD)
		marker.visible = false
		var tw := create_tween()
		tw.tween_property(rig, "rotation:z", PI * 0.5, 0.3)
		GameState.message.emit("Hyena killed.")
	else:
		_go(HState.SCATTER)


func _update_look(delta: float) -> void:
	var up := _floor_normal
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	var right := fwd.cross(up).normalized()
	fwd = up.cross(right).normalized()
	rig.global_basis = Basis(right, up, -fwd)
	var feeding := hstate == HState.FEED
	rig.animate(delta, speed, clampf(speed / Tuning.HYENA_SPEED, 0.0, 1.0), 0.3 if hstate == HState.TELL else 0.0, 1.0 if feeding else 0.0)
	marker.visible = hstate == HState.TELL
	marker.text = "!"
	marker.modulate = Color(1.0, 0.55, 0.15)
