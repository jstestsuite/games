class_name Rival
extends BigCat
## A rival male: a nomad you can meet, the pride male you must beat, or a challenger.
## IDLE (lies at home or wanders) -> STANDOFF (faces you and roars) -> FIGHT.
## In a fight every attack has a visible tell: "!" (yellow) = swipe coming,
## "!!" (red, crouching) = lunge coming. Dodge it. Swipes never interrupt him, but a
## pounce that lands during any windup staggers him. Spam swipes and he answers back.
## At low health he YIELDs and runs off; that's a win.

signal yielded(rival: Rival)

enum RState { IDLE, WAIT, STANDOFF, FIGHT, YIELD }
enum Move { NONE, TELL_SWIPE, SWIPE, TELL_LUNGE, LUNGE, RECOVER, DODGE, STAGGER }

var title := "Rival"
var player: Lion
var home := Vector3.ZERO
var wanders := false          # nomads roam; the pride male lies at home
var forced := false           # walks to the player to start a fight
var can_disengage := true     # if false, running away doesn't end the fight
var rstate := RState.IDLE
var move := Move.NONE

var _t := 0.0                 # time in current move
var _st := 0.0                # time in current rstate
var _think_t := 1.0
var _roar_t := 0.0
var _hit_done := false
var _dodged_this_pounce := false
var _circle_dir := 1.0
var _wander_target := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var marker: Label3D
var name_tag: Label3D


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("rival")
	collision_layer = 4
	collision_mask = 1
	_rng.randomize()
	_init_body(true)
	health = health_max()
	refresh_look(clampf((strength - 1.0) / 1.2, 0.0, 1.0))

	marker = Label3D.new()
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.fixed_size = true
	marker.pixel_size = 0.0018
	marker.font_size = 56
	marker.outline_size = 14
	marker.position.y = 2.6
	marker.visible = false
	add_child(marker)

	name_tag = Label3D.new()
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.no_depth_test = true
	name_tag.fixed_size = true
	name_tag.pixel_size = 0.0012
	name_tag.font_size = 40
	name_tag.outline_size = 10
	name_tag.modulate = Color(1.0, 0.82, 0.35)
	name_tag.position.y = 3.2
	name_tag.text = title.to_upper()
	add_child(name_tag)
	_wander_target = home


func set_title(t: String) -> void:
	title = t
	if name_tag:
		name_tag.text = t.to_upper()


func in_fight() -> bool:
	return rstate == RState.FIGHT or rstate == RState.STANDOFF


## Bring a waiting challenger into the fight.
func engage() -> void:
	if rstate == RState.WAIT or rstate == RState.IDLE:
		_set_r(RState.STANDOFF)


func _set_r(s: RState) -> void:
	rstate = s
	_st = 0.0


func _set_move(m: Move) -> void:
	move = m
	_t = 0.0
	_hit_done = false


func _physics_process(delta: float) -> void:
	_t += delta
	_st += delta
	drift = Vector3.ZERO
	if player == null or not is_instance_valid(player):
		_move_body(delta)
		return
	var d := flat_dist(player)
	match rstate:
		RState.IDLE:
			_idle(delta, d)
		RState.WAIT:
			speed = move_toward(speed, 0.0, 10.0 * delta)
			face_towards(player.global_position, 3.0, delta)
		RState.STANDOFF:
			_standoff(delta, d)
		RState.FIGHT:
			_fight(delta, d)
		RState.YIELD:
			var away := global_position - player.global_position
			heading = lerp_angle(heading, atan2(-away.x, -away.z), 1.0 - exp(-6.0 * delta))
			speed = move_toward(speed, Tuning.RUN_SPEED, 20.0 * delta)
			if _st > 5.0:
				queue_free()
	_move_body(delta)
	_update_look(delta)


func _idle(delta: float, d: float) -> void:
	name_tag.visible = true
	if forced:
		face_towards(player.global_position, 4.0, delta)
		speed = move_toward(speed, Tuning.WALK_SPEED * 1.2, 10.0 * delta)
		if d < Tuning.STANDOFF_RANGE * 0.7:
			_set_r(RState.STANDOFF)
		return
	if d < Tuning.STANDOFF_RANGE and not player.is_dead:
		_set_r(RState.STANDOFF)
		if player.is_in_group("player"):
			GameState.message.emit("%s faces you." % title)
		return
	if wanders:
		var to := _wander_target - global_position
		to.y = 0
		if to.length() < 2.0:
			_wander_target = home + Vector3(_rng.randf_range(-30, 30), 0, _rng.randf_range(-30, 30))
		face_towards(_wander_target, 2.0, delta)
		speed = move_toward(speed, Tuning.WALK_SPEED * 0.6, 4.0 * delta)
	else:
		var to := home - global_position
		to.y = 0
		if to.length() > 3.0:
			face_towards(home, 3.0, delta)
			speed = move_toward(speed, Tuning.WALK_SPEED, 6.0 * delta)
		else:
			speed = move_toward(speed, 0.0, 6.0 * delta)


func _standoff(delta: float, d: float) -> void:
	face_towards(player.global_position, 5.0, delta)
	# Close in to about ten metres, then hold and roar.
	var want := Tuning.WALK_SPEED * 0.5 if d > 10.0 else 0.0
	speed = move_toward(speed, want, 8.0 * delta)
	_roar_t -= delta
	if _roar_t <= 0.0:
		_roar_t = 1.6
		_flash("ROAR", Color(1.0, 0.85, 0.5), 0.8)
	if player.is_dead:
		_set_r(RState.IDLE)
	elif d > Tuning.DISENGAGE_RANGE and can_disengage and not forced:
		_set_r(RState.IDLE)
	elif _st > Tuning.STANDOFF_TIME or d < 6.0:
		_set_r(RState.FIGHT)
		_set_move(Move.NONE)
		_think_t = Tuning.RIVAL_THINK_TIME


func _fight(delta: float, d: float) -> void:
	if player.is_dead:
		_set_r(RState.IDLE)
		_set_move(Move.NONE)
		return
	if d > Tuning.DISENGAGE_RANGE and can_disengage and not forced:
		_set_r(RState.IDLE)
		_set_move(Move.NONE)
		GameState.message.emit("%s lets you go." % title)
		return

	match move:
		Move.NONE:
			_spacing(delta, d)
		Move.TELL_SWIPE:
			# Inch in during the windup so the paw can reach.
			var want := Tuning.RIVAL_MOVE_SPEED if d > Tuning.SWIPE_RANGE * 0.75 else 0.0
			speed = move_toward(speed, want, 20.0 * delta)
			face_towards(player.global_position, 4.0, delta)
			if _t >= Tuning.RIVAL_SWIPE_TELL:
				_set_move(Move.SWIPE)
		Move.SWIPE:
			speed = Tuning.RIVAL_MOVE_SPEED if d > Tuning.SWIPE_RANGE * 0.6 else 0.0
			if not _hit_done and _t >= 0.05:
				_hit_done = true
				if _player_in_arc(Tuning.SWIPE_RANGE, Tuning.SWIPE_ARC):
					player.take_hit(scaled_damage(Tuning.SWIPE_DAMAGE), global_position, false)
			if _t >= 0.18:
				_after_attack()
		Move.TELL_LUNGE:
			speed = move_toward(speed, 0.0, 20.0 * delta)
			face_towards(player.global_position, 3.0, delta)
			if _t >= Tuning.RIVAL_LUNGE_TELL:
				_set_move(Move.LUNGE)
		Move.LUNGE:
			speed = Tuning.POUNCE_SPEED
			if not _hit_done and _player_in_arc(Tuning.POUNCE_CATCH_RADIUS + 0.4, 110.0):
				_hit_done = true
				player.take_hit(scaled_damage(Tuning.LUNGE_DAMAGE), global_position, true)
				speed *= 0.3
			if _t >= Tuning.POUNCE_DURATION:
				speed *= 0.4
				_after_attack()
		Move.RECOVER:
			speed = move_toward(speed, 0.0, 25.0 * delta)
			var rec := Tuning.RIVAL_RECOVER * (1.0 if _hit_done else 1.3)
			if _t >= rec:
				_set_move(Move.NONE)
		Move.DODGE:
			speed = 0.0
			var side := forward().cross(Vector3.UP) * _circle_dir
			drift = side * Tuning.DODGE_SPEED
			if _t >= Tuning.DODGE_TIME:
				_set_move(Move.NONE)
		Move.STAGGER:
			speed = move_toward(speed, 0.0, 25.0 * delta)
			if _t >= Tuning.STAGGER_TIME:
				_set_move(Move.NONE)


## Missed? Sometimes he chains straight into a quick swipe instead of leaving an opening.
func _after_attack() -> void:
	if not _hit_done and _rng.randf() < Tuning.RIVAL_COMBO_CHANCE:
		_quick_swipe()
	else:
		_set_move(Move.RECOVER)


func _quick_swipe() -> void:
	_set_move(Move.TELL_SWIPE)
	_t = Tuning.RIVAL_SWIPE_TELL * (1.0 - Tuning.RIVAL_COUNTER_TELL)


## Circle at fighting distance, pick attacks, and react to your pounces.
func _spacing(delta: float, d: float) -> void:
	face_towards(player.global_position, 6.0, delta)
	var want := Tuning.RIVAL_CIRCLE_DIST
	if d > want + 1.5:
		var spd := Tuning.RUN_SPEED if d > 12.0 else Tuning.RIVAL_MOVE_SPEED * 1.4
		speed = move_toward(speed, spd, 20.0 * delta)
	elif d < want - 1.0:
		speed = move_toward(speed, 0.0, 20.0 * delta)
		drift = -forward() * Tuning.RIVAL_MOVE_SPEED
	else:
		speed = move_toward(speed, 0.0, 20.0 * delta)
		drift = forward().cross(Vector3.UP) * _circle_dir * Tuning.RIVAL_MOVE_SPEED * 0.6
		if _rng.randf() < delta * 0.4:
			_circle_dir = -_circle_dir

	# See a pounce coming? Maybe sidestep it.
	if player.state == Lion.State.POUNCE:
		if not _dodged_this_pounce and d < 8.0:
			_dodged_this_pounce = true
			if _rng.randf() < Tuning.RIVAL_DODGE_CHANCE:
				_set_move(Move.DODGE)
				return
	else:
		_dodged_this_pounce = false

	_think_t -= delta
	if _think_t <= 0.0 and d < want + 2.0:
		_think_t = Tuning.RIVAL_THINK_TIME * _rng.randf_range(0.6, 1.4)
		# Out of paw reach, a lunge is the only real option.
		var in_reach := d < Tuning.SWIPE_RANGE + 1.2
		if not in_reach or _rng.randf() < Tuning.RIVAL_LUNGE_CHANCE:
			_set_move(Move.TELL_LUNGE)
		else:
			_set_move(Move.TELL_SWIPE)


func _player_in_arc(reach: float, arc_deg: float) -> bool:
	if player.is_invulnerable():
		return false
	var to := player.global_position - global_position
	to.y = 0
	var dist := to.length()
	if dist > reach + 0.4:
		return false
	return dist < 0.6 or rad_to_deg(forward().angle_to(to / dist)) <= arc_deg * 0.5


func health_max() -> float:
	return super.health_max() * Tuning.RIVAL_HEALTH_MULT


func is_invulnerable() -> bool:
	return is_dead or rstate == RState.YIELD or move == Move.DODGE


func take_hit(damage: float, from: Vector3, heavy: bool) -> void:
	if is_invulnerable():
		return
	if not heavy and _rng.randf() < Tuning.RIVAL_BLOCK_CHANCE:
		_flash("BLOCK", Color(0.8, 0.9, 1.0), 0.5)
		return
	super.take_hit(damage, from, heavy)
	if not is_dead and health <= health_max() * Tuning.RIVAL_YIELD_AT:
		_yield()


func _on_hit(_damage: float, heavy: bool) -> void:
	if rstate == RState.IDLE or rstate == RState.STANDOFF or rstate == RState.WAIT:
		_set_r(RState.FIGHT)
	# Only a pounce knocks him off his feet; swipes he shrugs through.
	if heavy:
		_set_move(Move.STAGGER)
		_flash("STAGGERED", Color(0.7, 1.0, 0.7), 0.6)
	elif move == Move.NONE and rstate == RState.FIGHT and _rng.randf() < Tuning.RIVAL_COUNTER_CHANCE:
		_quick_swipe()


func _on_health_gone() -> void:
	_yield()


func _yield() -> void:
	if rstate == RState.YIELD:
		return
	health = maxf(health, 1.0)
	_set_r(RState.YIELD)
	_set_move(Move.NONE)
	remove_from_group("enemy")
	_flash("YIELDS", Color(0.7, 1.0, 0.7), 2.0)
	yielded.emit(self)


var _flash_t := 0.0


func _flash(text: String, col: Color, time: float) -> void:
	marker.text = text
	marker.modulate = col
	_flash_t = time


func _update_look(delta: float) -> void:
	_flash_t -= delta
	match move:
		Move.TELL_SWIPE:
			marker.visible = true
			marker.text = "!"
			marker.modulate = Color(1.0, 0.85, 0.2)
		Move.TELL_LUNGE:
			marker.visible = true
			marker.text = "!!"
			marker.modulate = Color(1.0, 0.2, 0.15)
		_:
			marker.visible = _flash_t > 0.0
	name_tag.visible = rstate != RState.FIGHT

	var crouch := 0.0
	rig.paw = 0.0
	rig.lunge = 0.0
	var sn := clampf(speed / Tuning.CHARGE_SPEED, 0.0, 1.0)
	match move:
		Move.TELL_SWIPE:
			rig.paw = clampf(_t / Tuning.RIVAL_SWIPE_TELL, 0.0, 1.0) * 0.7
		Move.SWIPE:
			rig.paw = 1.0
		Move.TELL_LUNGE:
			crouch = clampf(_t / Tuning.RIVAL_LUNGE_TELL, 0.0, 1.0)
		Move.LUNGE:
			rig.lunge = 1.0
			sn = 1.0
	if rstate == RState.IDLE and not wanders and not forced and speed < 0.5:
		crouch = 0.8   # lying at the den
	_pose_rig(delta, sn, crouch, 0.0)
