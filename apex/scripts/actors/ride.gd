class_name Ride
extends RefCounted
## The takedown: you've landed on a running animal and it's trying to throw you.
##
## It runs, and every so often it cuts hard to one side (big animals sometimes shake
## instead). Its body tells you first: the head swings and the shoulder drops toward the
## cut, then a foot plants (a puff of dust) just before it goes. Some species lie with the
## head; the planted foot never lies. A shake is announced by the head tossing.
##
## Two feels to compare in play (RIDE_MODEL):
##   BALANCE: a cut flings you to the outside of the turn. Push the stick to keep your
##     weight over its back. `x` is how far off-centre you are (-1 left .. +1 right).
##   STEER: you run with it. Push the stick the way it's going. `x` is how far your
##     heading is off its heading, as a fraction of how far it takes to be thrown
##     (RIDE_HEADING_MAX, less on heavier animals).
## Either way a soft pull (RIDE_MAGNET) draws you back to centre, and your weight has
## momentum: overcorrect and you swing past. Inside the safe zone the animal's `fight`
## drains (the catch meter; at 0 it goes down). Outside it your `grip` drains (at 0, or
## at |x| = 1, you're thrown). Clamping (RT) drains it faster but shrinks the safe zone.
##
## This class only simulates. The lion moves the animal and applies the endings, so the
## probe bots (tests/ride_sim.gd) can run thousands of rides without a scene.

enum Model { BALANCE, STEER }
enum Phase { RUN, TELL, CUT, SHAKE }

const SHAKE_TIME := 0.9
const SHAKE_FREQ := 9.0

var model := Model.BALANCE
var phase := Phase.RUN
var t := 0.0                 # time in the current phase
var age := 0.0
var x := 0.0                 # how far off you are, -1..1
var xv := 0.0                # and how fast that's changing
var aim := 0.0               # STEER: your heading (world yaw)
var aim_v := 0.0             # STEER: your turn rate
var heading := 0.0           # the animal's heading (world yaw; + is a left turn)
var turn := 0.0              # its turn rate this frame, rad/s
var speed := 0.0
var fight := 1.0             # 1 = fresh, 0 = it goes down
var grip := 1.0
var clamp_amount := 0.0
var safe := 0.35             # half-width of the safe zone right now
var ratio := 1.0             # your power / its power
var helpers := 0             # lionesses holding on too
var side := 1.0              # the coming or current cut: +1 = to its right, -1 = to its left
var is_shake := false
# The tells, for the animal's body to show:
var head := 0.0              # head swing, -1 (its left) .. +1 (its right)
var lean := 0.0              # shoulder drop toward the cut, -1..1
var plant := 0.0             # a foot is planted on `side`, 0..1
var planted_now := false     # true on the frame the foot plants (for a dust puff)
# Stats, for the practice log:
var steady_time := 0.0
var cuts := 0
var reacts: Array[float] = []   # per cut: seconds from the cut to your counter (negative = you read it early)

var terrain: Terrain
var _fight_time := 8.0
var _cut_min := 1.0
var _cut_max := 2.0
var _cut_angle := 1.2
var _cut_rate := 5.0
var _tell := 0.4
var _fake := 0.0
var _double := 0.0
var _shake := 0.0
var _heavy := 1.0
var _run_speed := 10.0
var _next := 1.0
var _tell_len := 0.4
var _fake_now := false
var _cut_left := 0.0
var _doubled := false
var _shake_base := 0.0
var _cut_at := 0.0           # when the current cut does (or did) start
var _reacted := true
var _rng := RandomNumberGenerator.new()


## `params` maps a species key to its tuning value (e.g. "RIDE_FIGHT" -> ZEBRA_RIDE_FIGHT).
## `slow` scales its speed and cuts (the practice room's slow zebra).
func setup(params: Callable, power_ratio: float, start_heading: float, start_fight := 1.0,
		slow := 1.0, world: Terrain = null) -> void:
	_rng.randomize()
	model = Tuning.RIDE_MODEL as Model
	terrain = world
	ratio = power_ratio
	heading = start_heading
	aim = start_heading
	fight = clampf(start_fight, 0.05, 1.0)
	_fight_time = params.call("RIDE_FIGHT")
	_cut_min = params.call("CUT_MIN")
	_cut_max = maxf(_cut_min, params.call("CUT_MAX"))
	_cut_angle = deg_to_rad(params.call("CUT_ANGLE"))
	_cut_rate = params.call("CUT_RATE") * slow
	_tell = params.call("TELL") / slow
	_fake = params.call("FAKE")
	_double = params.call("DOUBLE")
	_shake = params.call("SHAKE")
	_heavy = params.call("HEAVY")
	_run_speed = params.call("SPEED") * Tuning.RIDE_SPEED_MULT * slow
	_next = Tuning.RIDE_FIRST_CUT
	speed = _run_speed


## Advance by delta. `u` is your push, -1..1 (BALANCE: + = toward its right; STEER: + = turn
## left). `c` is the clamp, 0..1. `pos` is where the animal is (for steering round things).
## Returns +1 when it goes down, -1 when you're thrown, 0 otherwise.
func update(delta: float, u: float, c: float, pos := Vector3.ZERO) -> int:
	if delta <= 0.0:
		return 0
	t += delta
	age += delta
	clamp_amount = clampf(c, 0.0, 1.0)
	var was := heading
	_animal(delta, pos)
	turn = wrapf(heading - was, -PI, PI) / delta
	speed = _run_speed * lerpf(0.6, 1.0, fight) / (1.0 + 0.35 * helpers)
	_rider(delta, clampf(u, -1.0, 1.0))
	_track_reaction(u)
	return _score(delta)


## STEER: how far off its heading (radians) you can be before you're thrown.
func heading_max() -> float:
	var heavy := _heavy / pow(clampf(ratio, 0.5, 2.0), Tuning.RIDE_STRENGTH_EFFECT)
	return deg_to_rad(Tuning.RIDE_HEADING_MAX) / sqrt(heavy)


## Which way you'd have to push to counter the current cut (+1 or -1 in `u`).
func counter_sign() -> float:
	return side if model == Model.BALANCE else -side


func steady_fraction() -> float:
	return steady_time / maxf(age, 0.01)


## The mean of `reacts`, or 0 if there were no cuts.
func mean_react() -> float:
	if reacts.is_empty():
		return 0.0
	var s := 0.0
	for r in reacts:
		s += r
	return s / reacts.size()


# --- the animal ---------------------------------------------------------------------

func _animal(delta: float, pos: Vector3) -> void:
	planted_now = false
	match phase:
		Phase.RUN:
			# Between cuts it runs on, bending round trees and away from the rim.
			var want := _open_heading(pos)
			heading += clampf(wrapf(want - heading, -PI, PI), -1.6 * delta, 1.6 * delta)
			head = move_toward(head, 0.0, 4.0 * delta)
			lean = move_toward(lean, 0.0, 4.0 * delta)
			plant = move_toward(plant, 0.0, 4.0 * delta)
			if t >= _next:
				_start_tell(pos)
		Phase.TELL:
			var f := t / _tell_len
			if is_shake:
				head = sin(t * 22.0)   # tossing its head
				lean = 0.0
			else:
				# The head goes first (maybe the wrong way); the foot plants for the last part.
				var head_side := -side if (_fake_now and f < 0.6) else side
				head = move_toward(head, head_side, 7.0 * delta)
				lean = head * 0.6
				if f >= 0.6 and plant == 0.0:
					planted_now = true
				if f >= 0.6:
					plant = 1.0
					lean = side
			if t >= _tell_len:
				t = 0.0
				if is_shake:
					phase = Phase.SHAKE
					_shake_base = heading
				else:
					phase = Phase.CUT
					_cut_left = _cut_angle * _rng.randf_range(0.85, 1.15)
					cuts += 1
		Phase.CUT:
			var step := minf(_cut_rate * delta, _cut_left)
			heading -= side * step
			_cut_left -= step
			head = side
			lean = side
			if _cut_left <= 0.0:
				if not _doubled and _rng.randf() < _double:
					# Straight back the other way, with less warning.
					_doubled = true
					side = -side
					_begin_tell(_tell * 0.6, false)
				else:
					_to_run()
		Phase.SHAKE:
			heading = _shake_base + sin(t * SHAKE_FREQ) * 0.5 * side
			head = sin(t * SHAKE_FREQ)
			lean = head
			if t >= SHAKE_TIME:
				_to_run()


func _start_tell(pos: Vector3) -> void:
	is_shake = _rng.randf() < _shake
	side = _pick_side(pos)
	_begin_tell(_tell * _rng.randf_range(0.85, 1.15), not is_shake and _rng.randf() < _fake)


func _begin_tell(length: float, fake: bool) -> void:
	phase = Phase.TELL
	t = 0.0
	_tell_len = maxf(0.08, length)
	_fake_now = fake
	plant = 0.0
	_cut_at = age + _tell_len
	_reacted = is_shake   # shakes aren't scored


func _to_run() -> void:
	phase = Phase.RUN
	t = 0.0
	is_shake = false
	_doubled = false
	_next = _rng.randf_range(_cut_min, _cut_max)


## Cut toward open ground: away from trees, rocks and the rim.
func _pick_side(pos: Vector3) -> float:
	var s := 1.0 if _rng.randf() < 0.5 else -1.0
	if terrain == null:
		return s
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	var a_ok := _clear(pos, fwd.rotated(Vector3.UP, -s * _cut_angle))
	var b_ok := _clear(pos, fwd.rotated(Vector3.UP, s * _cut_angle))
	if not a_ok and b_ok:
		return -s
	return s


func _clear(pos: Vector3, d: Vector3) -> bool:
	var ahead := pos + d * 14.0
	var half := Tuning.WORLD_SIZE * 0.5 - 45.0
	if absf(ahead.x) > half or absf(ahead.z) > half:
		return false
	return terrain.avoid(pos, d, 8.0).dot(d) > 0.95


func _open_heading(pos: Vector3) -> float:
	if terrain == null:
		return heading
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	var half := Tuning.WORLD_SIZE * 0.5 - 50.0
	var push := Vector3(
		-clampf((absf(pos.x) - half) / 12.0, 0.0, 1.0) * signf(pos.x), 0,
		-clampf((absf(pos.z) - half) / 12.0, 0.0, 1.0) * signf(pos.z))
	var dir := (fwd + push * 2.0).normalized()
	dir = terrain.avoid(pos, dir, 3.0 + speed * 0.4)
	return atan2(-dir.x, -dir.z)


# --- you ----------------------------------------------------------------------------

func _rider(delta: float, u: float) -> void:
	# Heavier animals throw harder; a stronger lion (or help) is harder to throw.
	var heavy := _heavy / pow(clampf(ratio, 0.5, 2.0), Tuning.RIDE_STRENGTH_EFFECT)
	if model == Model.BALANCE:
		# Turning left (turn > 0) flings you out to its right (+x).
		var fling := Tuning.RIDE_FLING * heavy * turn * speed
		xv += (fling + Tuning.RIDE_PUSH * u - Tuning.RIDE_MAGNET * x - Tuning.RIDE_DAMPING * xv) * delta
		x += xv * delta
	else:
		# Your heading has momentum; its turning opens the gap, the pull and your push close it.
		# Heavier animals throw you at a smaller angle.
		var maxr := heading_max()
		var e := wrapf(aim - heading, -PI, PI)
		aim_v += (Tuning.RIDE_PUSH * u * maxr - Tuning.RIDE_MAGNET * e \
				- Tuning.RIDE_DAMPING * (aim_v - turn)) * delta
		aim += aim_v * delta
		x = wrapf(aim - heading, -PI, PI) / maxr
		xv = (aim_v - turn) / maxr


func _track_reaction(u: float) -> void:
	if _reacted or is_shake:
		return
	if u * counter_sign() > 0.3:
		_reacted = true
		reacts.append(age - _cut_at)
	elif age - _cut_at > 0.8:
		_reacted = true
		reacts.append(0.8)


func _score(delta: float) -> int:
	safe = Tuning.RIDE_SAFE * (1.0 - Tuning.RIDE_CLAMP_NARROW * clamp_amount)
	var ax := absf(x)
	if ax <= safe:
		var rate := (1.0 + (Tuning.RIDE_CLAMP_DRAIN - 1.0) * clamp_amount) * sqrt(clampf(ratio, 0.5, 2.0))
		rate *= 1.0 + 0.5 * helpers
		fight -= rate / _fight_time * delta
		grip = minf(1.0, grip + Tuning.RIDE_GRIP_REGEN * delta)
		steady_time += delta
	else:
		grip -= Tuning.RIDE_GRIP_DRAIN * (ax - safe) / maxf(0.05, 1.0 - safe) * delta
	if fight <= 0.0:
		fight = 0.0
		return 1
	if grip <= 0.0 or ax >= 1.0:
		grip = maxf(grip, 0.0)
		return -1
	return 0
