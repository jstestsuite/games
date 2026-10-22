class_name BigCat
extends CharacterBody3D
## Shared body for every lion: the player, rival males and lionesses.
## Handles the rig, health, strength scaling, taking hits, and moving on the terrain.
## Subclasses decide what to do each frame and call _move_body(delta) at the end.

signal died

var terrain: Terrain
var heading := 0.0            # yaw, radians
var speed := 0.0
var strength := 1.0
var health := 100.0
var is_dead := false
var is_male := true
var knock := Vector3.ZERO     # knockback velocity, decays
var drift := Vector3.ZERO     # sideways/backwards movement set by AI each frame (cats don't strafe, but fighters circle)
var rig: AnimalRig
var _floor_normal := Vector3.UP
var _since_hurt := 99.0
var _size := 1.0


func _init_body(male: bool, body_scale := 1.0) -> void:
	is_male = male
	floor_snap_length = 0.8
	floor_max_angle = deg_to_rad(50)
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.4
	col.shape = shape
	col.position.y = 0.72
	add_child(col)

	rig = AnimalRig.new()
	rig.name = "Rig"
	add_child(rig)
	var base := Color(0.80, 0.62, 0.36) if male else Color(0.84, 0.68, 0.43)
	rig.build({
		"body_len": 1.7 if male else 1.55, "body_r": 0.36 if male else 0.31,
		"leg_len": 0.8, "leg_r": 0.1 if male else 0.085,
		"neck_len": 0.36, "neck_r": 0.2 if male else 0.16, "neck_pitch": -1.1,
		"head_r": 0.22 if male else 0.19, "head_len": 1.05,
		"tail_len": 0.95, "tail_tip": true, "ear": 0.6, "stride": 1.7,
		"mane": male,
		"coat": {
			"base_color": base, "belly_color": Color(0.93, 0.85, 0.7),
			"belly_height": -0.1, "roughness_val": 0.9,
		},
	})
	_size = body_scale


func health_max() -> float:
	return Tuning.HEALTH_MAX * (1.0 + (strength - 1.0) * Tuning.HEALTH_PER_STRENGTH)


## Visual size grows with strength, and males' manes darken.
func refresh_look(mane_darkness: float) -> void:
	_size = 1.0 + (strength - 1.0) * Tuning.STRENGTH_SIZE
	rig.set_mane(mane_darkness)


func forward() -> Vector3:
	return Vector3(-sin(heading), 0, -cos(heading))


func face_towards(p: Vector3, rate: float, delta: float) -> void:
	var to := p - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		heading = lerp_angle(heading, atan2(-to.x, -to.z), 1.0 - exp(-rate * delta))


## Like face_towards, but bends around rocks and trees on the way.
func steer_towards(p: Vector3, rate: float, delta: float) -> void:
	var to := p - global_position
	to.y = 0
	if to.length() < 0.05:
		return
	var dir := to.normalized()
	if terrain:
		dir = terrain.avoid(global_position, dir, 3.0 + speed * 0.4, 0.7)
	heading = lerp_angle(heading, atan2(-dir.x, -dir.z), 1.0 - exp(-rate * delta))


func flat_dist(n: Node3D) -> float:
	var d := n.global_position - global_position
	d.y = 0
	return d.length()


## Override for i-frames (dodging).
func is_invulnerable() -> bool:
	return is_dead


## Every fighter implements take_hit. `heavy` hits (lunges) stagger.
func take_hit(damage: float, from: Vector3, heavy: bool) -> void:
	if is_invulnerable():
		return
	health -= damage
	_since_hurt = 0.0
	var away := global_position - from
	away.y = 0
	if away.length() > 0.01:
		knock = away.normalized() * Tuning.KNOCKBACK * (1.6 if heavy else 1.0)
	_on_hit(damage, heavy)
	if health <= 0.0:
		health = 0.0
		_on_health_gone()


func _on_hit(_damage: float, _heavy: bool) -> void:
	pass


func _on_health_gone() -> void:
	is_dead = true
	died.emit()


## Damage this cat deals with a base value, scaled by strength.
func scaled_damage(base: float) -> float:
	return base * pow(strength, Tuning.DAMAGE_STRENGTH_POWER)


## Everything in `group` within `reach` and inside a cone of `arc_deg` in front of me.
func targets_in_arc(group: String, reach: float, arc_deg: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var fwd := forward()
	for n in get_tree().get_nodes_in_group(group):
		var t := n as Node3D
		if t == null or t == self or t.get("is_dead"):
			continue
		var to := t.global_position - global_position
		to.y = 0
		var d := to.length()
		if d > reach + 0.4:
			continue
		if d > 0.6 and rad_to_deg(fwd.angle_to(to / d)) > arc_deg * 0.5:
			continue
		out.append(t)
	return out


func _move_body(delta: float) -> void:
	_since_hurt += delta
	var fwd := forward()
	velocity.x = fwd.x * speed + knock.x + drift.x
	velocity.z = fwd.z * speed + knock.z + drift.z
	knock = knock.move_toward(Vector3.ZERO, 18.0 * delta)
	if not is_on_floor():
		velocity.y -= 30.0 * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()
	if is_on_floor():
		_floor_normal = _floor_normal.lerp(get_floor_normal(), 1.0 - exp(-8.0 * delta)).normalized()
	# Never fall out of the world.
	if terrain and global_position.y < terrain.height_at(global_position.x, global_position.z) - 2.0:
		global_position.y = terrain.height_at(global_position.x, global_position.z) + 0.5


func _pose_rig(delta: float, speed_norm: float, crouch: float, head_down: float) -> void:
	var up := _floor_normal
	var fwd := forward()
	var right := fwd.cross(up).normalized()
	fwd = up.cross(right).normalized()
	rig.global_basis = Basis(right, up, -fwd).scaled(Vector3.ONE * _size)
	rig.animate(delta, speed, speed_norm, crouch, head_down)
