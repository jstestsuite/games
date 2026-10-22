class_name Grapple
extends RefCounted
## A close-quarters struggle, shared by prey takedowns and rival clinches.
##
## The opponent telegraphs a lurch with an arrow (screen directions: left, right,
## up = away from the camera, down = toward it). When the warning ends you get a short
## window: push the stick the right way and you win the exchange, push the wrong way or
## nothing and you lose it. Committing early is fine, but fake-outs switch the arrow
## partway through the warning.
##
## PREY: always push WITH the arrow. Wins fill `progress` (1 = brought down); losses
##   drain `grip` (0 = thrown off) and cost you a kick.
## RIVAL: a tug-of-war on `balance` (+1 = you pin him, -1 = he pins you). Yellow arrow =
##   a shove, push WITH it to brace. Red arrow = a bite, push AWAY from it.
##
## This class only keeps score. The lion applies damage, movement and the endings.

enum Kind { PREY, RIVAL }
enum Phase { WAIT, TELL, WINDOW }

const DIRS_2: Array[Vector2] = [Vector2(-1, 0), Vector2(1, 0)]
const DIRS_4: Array[Vector2] = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]

var kind := Kind.PREY
var phase := Phase.WAIT
var t := 0.0                  # time in the current phase
var age := 0.0                # time since the grapple started
var dir := Vector2.ZERO       # the current arrow, in input space
var is_bite := false          # rival only
var grip := 1.0
var progress := 0.0
var balance := 0.0
var ratio := 1.0              # your power / theirs; > 1 makes everything kinder
var assist := 0.0             # prey: extra power from lionesses holding on
var assist_progress := 0.0    # prey: passive progress per second from them
var last_result := 0          # +1 won the last exchange, -1 lost it (for the HUD)
var result_t := 9.0           # seconds since last_result changed
var exchanges := 0

# Tuned per opponent by setup_prey / setup_rival.
var tell_time := 0.5
var wait_min := 0.35
var wait_max := 1.0
var dirs: Array[Vector2] = DIRS_4
var fake_chance := 0.0
var double_chance := 0.0
var bite_chance := 0.0
var hits := 4
var grip_loss := 0.3

var _wait := 0.7
var _tell_len := 0.5
var _fake_at := -1.0
var _rng := RandomNumberGenerator.new()


func setup_prey(prey: Prey, power: float) -> void:
	kind = Kind.PREY
	_rng.randomize()
	tell_time = prey.p("GRAB_TELL")
	wait_min = Tuning.GRAB_WAIT_MIN
	wait_max = Tuning.GRAB_WAIT_MAX
	dirs = DIRS_2 if int(prey.p("GRAB_DIRS")) <= 2 else DIRS_4
	fake_chance = prey.p("GRAB_FAKE")
	double_chance = prey.p("GRAB_DOUBLE")
	hits = maxi(1, int(prey.p("GRAB_HITS")))
	grip_loss = prey.p("GRAB_GRIP_LOSS")
	ratio = power / maxf(0.05, prey.p("POWER"))
	_wait = Tuning.GRAB_FIRST_WAIT


func setup_rival(my_strength: float, his_strength: float, edge: float) -> void:
	kind = Kind.RIVAL
	_rng.randomize()
	tell_time = Tuning.CLINCH_TELL
	wait_min = Tuning.CLINCH_WAIT_MIN
	wait_max = Tuning.CLINCH_WAIT_MAX
	dirs = DIRS_4
	fake_chance = Tuning.CLINCH_FAKE_CHANCE
	bite_chance = Tuning.CLINCH_BITE_CHANCE
	ratio = my_strength / maxf(0.05, his_strength)
	balance = edge
	_wait = Tuning.GRAB_FIRST_WAIT * 0.6


## The power ratio including helpers: what the warnings and penalties scale with.
func effective_ratio() -> float:
	return ratio + assist


## Advance by delta with the player's stick. Returns +1 when an exchange is won,
## -1 when lost, 0 otherwise.
func update(delta: float, input: Vector2) -> int:
	t += delta
	age += delta
	result_t += delta
	var out := 0
	match phase:
		Phase.WAIT:
			if kind == Kind.PREY:
				grip = minf(1.0, grip + Tuning.GRAB_GRIP_REGEN * delta)
				progress += assist_progress * delta
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
			if out == 0 and t >= Tuning.GRAB_WINDOW:
				out = _resolve(false)
	return out


## How far through the current warning we are, 0..1 (the HUD fills the arrow with it).
func tell_fraction() -> float:
	return clampf(t / _tell_len, 0.0, 1.0) if phase == Phase.TELL else 0.0


func _start_tell() -> void:
	phase = Phase.TELL
	t = 0.0
	dir = dirs[_rng.randi() % dirs.size()]
	is_bite = kind == Kind.RIVAL and _rng.randf() < bite_chance
	# Stronger than it? You get longer to read it.
	_tell_len = tell_time * clampf(sqrt(effective_ratio()), 0.75, 1.3)
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
	var r := effective_ratio()
	if kind == Kind.PREY:
		if won:
			progress += (1.0 / float(hits)) * clampf(r, 0.6, 1.6)
			grip = minf(1.0, grip + Tuning.GRAB_SUCCESS_GRIP)
		else:
			grip -= grip_loss / clampf(r, 0.5, 2.0)
	else:
		# Losing an exchange costs more than winning one gains: only a stronger lion,
		# or a sharper reader, comes out on top.
		var rr := clampf(r, 0.6, 1.6)
		balance += Tuning.CLINCH_SHIFT_WIN * rr if won else -Tuning.CLINCH_SHIFT_LOSE / rr
	last_result = 1 if won else -1
	result_t = 0.0
	phase = Phase.WAIT
	t = 0.0
	_wait = 0.12 if (won and _rng.randf() < double_chance) else _rng.randf_range(wait_min, wait_max)
	return last_result
