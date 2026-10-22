class_name Grapple
extends RefCounted
## A clinch with a rival lion (prey takedowns are a Ride now; see ride.gd).
##
## He telegraphs a move with an arrow (screen directions: left, right, up = away from
## the camera, down = toward it). When the warning ends you get a short window: push the
## stick the right way and you win the exchange, push the wrong way or nothing and you
## lose it. Committing early is fine, but fake-outs switch the arrow partway through.
##
## A tug-of-war on `balance` (+1 = you pin him, -1 = he pins you). Yellow arrow = a
## shove, push WITH it to brace. Red arrow = a bite, push AWAY from it.
##
## This class only keeps score. The lion applies damage, movement and the endings.

enum Kind { RIVAL }
enum Phase { WAIT, TELL, WINDOW }

const DIRS_4: Array[Vector2] = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]

var kind := Kind.RIVAL
var phase := Phase.WAIT
var t := 0.0                  # time in the current phase
var age := 0.0                # time since the clinch started
var dir := Vector2.ZERO       # the current arrow, in input space
var is_bite := false
var balance := 0.0
var ratio := 1.0              # your strength / his; > 1 makes everything kinder
var last_result := 0          # +1 won the last exchange, -1 lost it (for the HUD)
var result_t := 9.0           # seconds since last_result changed
var exchanges := 0

var tell_time := 0.5
var wait_min := 0.35
var wait_max := 1.0
var dirs: Array[Vector2] = DIRS_4
var fake_chance := 0.0
var bite_chance := 0.0

var _wait := 0.7
var _tell_len := 0.5
var _fake_at := -1.0
var _rng := RandomNumberGenerator.new()


func setup_rival(my_strength: float, his_strength: float, edge: float) -> void:
	_rng.randomize()
	tell_time = Tuning.CLINCH_TELL
	wait_min = Tuning.CLINCH_WAIT_MIN
	wait_max = Tuning.CLINCH_WAIT_MAX
	fake_chance = Tuning.CLINCH_FAKE_CHANCE
	bite_chance = Tuning.CLINCH_BITE_CHANCE
	ratio = my_strength / maxf(0.05, his_strength)
	balance = edge
	_wait = Tuning.CLINCH_FIRST_WAIT


## Advance by delta with the player's stick. Returns +1 when an exchange is won,
## -1 when lost, 0 otherwise.
func update(delta: float, input: Vector2) -> int:
	t += delta
	age += delta
	result_t += delta
	var out := 0
	match phase:
		Phase.WAIT:
			if t >= _wait:
				_start_tell()
		Phase.TELL:
			if _fake_at >= 0.0 and t >= _fake_at:
				_fake_at = -1.0
				var others := dirs.filter(func(d): return d != dir)
				dir = others[_rng.randi() % others.size()]
			if t >= _tell_len:
				phase = Phase.WINDOW
				t = 0.0
				out = _judge(input)
		Phase.WINDOW:
			out = _judge(input)
			if out == 0 and t >= Tuning.CLINCH_WINDOW:
				out = _resolve(false)
	return out


## How far through the current warning we are, 0..1 (the HUD fills the arrow with it).
func tell_fraction() -> float:
	return clampf(t / _tell_len, 0.0, 1.0) if phase == Phase.TELL else 0.0


func _start_tell() -> void:
	phase = Phase.TELL
	t = 0.0
	dir = dirs[_rng.randi() % dirs.size()]
	is_bite = _rng.randf() < bite_chance
	# Stronger than him? You get longer to read it.
	_tell_len = tell_time * clampf(sqrt(ratio), 0.75, 1.3)
	_fake_at = -1.0
	if _rng.randf() < fake_chance:
		_fake_at = _tell_len * 0.5
		_tell_len += _tell_len * 0.6   # time to react to the switch


func _judge(input: Vector2) -> int:
	if input.length() < 0.55:
		return 0
	var want := -dir if is_bite else dir
	return _resolve(input.normalized().dot(want) > 0.7)


func _resolve(won: bool) -> int:
	exchanges += 1
	# Losing an exchange costs more than winning one gains: only a stronger lion,
	# or a sharper reader, comes out on top.
	var rr := clampf(ratio, 0.6, 1.6)
	balance += Tuning.CLINCH_SHIFT_WIN * rr if won else -Tuning.CLINCH_SHIFT_LOSE / rr
	last_result = 1 if won else -1
	result_t = 0.0
	phase = Phase.WAIT
	t = 0.0
	_wait = _rng.randf_range(wait_min, wait_max)
	return last_result
