extends SceneTree
## Fight probe: a scripted player fights a rival at several strength match-ups and
## reports win rate, fight length and health left. Not pass/fail. Use it after
## changing the fighting values in Tuning.
##
## The bot plays like a decent human: it needs REACTION_TIME to respond to a tell,
## then dodges REACT_CHANCE of the time; it swipes in range and sometimes pounces into
## a clinch. In a clinch it reads the arrows the same way (away from red bites).
##
## Run:  godot --headless --path . --fixed-fps 60 -s tests/fight_sim.gd

const RUNS := 10
const REACT_CHANCE := 0.7     # how often the bot dodges a tell it sees in time
const REACTION_TIME := 0.28   # seconds from a tell appearing to the bot's dodge
const MAX_TIME := 60.0

var _main: Node
var GS: Node
var TU: Node
var _step := 0
var _t := 0.0
var _scenario := 0
var _run := 0
var _r: Node
var _reacted_to := -1
var _tell_seen := -1
var _tell_t := 0.0
var _seen_ex := -1
var _seen_t := 0.0
var _commit := Vector2.ZERO
var _commit_dir := Vector2.ZERO
var _clinches := 0
var _was_clinch := false
var _rng := RandomNumberGenerator.new()
var _wins := 0
var _time_sum := 0.0
var _hp_sum := 0.0
var _log: Array[String] = []

# [label, player strength, rival strength]
var scenarios := [
	["even 1.0 v 1.0", 1.0, 1.0],
	["nomad 1.3 v 1.25", 1.3, 1.25],
	["pride 1.5 v 1.6", 1.5, 1.6],
	["pride 1.8 v 1.6", 1.8, 1.6],
	["weak 1.2 v 1.6", 1.2, 1.6],
]


func _initialize() -> void:
	_rng.seed = 7
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _physics_process(delta: float) -> bool:
	if GS == null:
		GS = root.get_node("GameState")
		TU = root.get_node("Tuning")
		return false
	if _step == 0:
		_main._start_run()
		for n in get_nodes_in_group("prey"):
			n.queue_free()
		_step = 1
		_setup()
		return false

	_t += delta
	GS.hunger = TU.HUNGER_MAX
	GS.day_time = 10.0
	var p = _main.player
	_bot(p)
	var over := false
	var won := false
	if not is_instance_valid(_r) or _r.rstate == 4:   # YIELD
		over = true
		won = true
	elif p.is_dead:
		over = true
	elif _t > MAX_TIME:
		over = true
	if over:
		if won:
			_wins += 1
			_time_sum += _t
			_hp_sum += p.health / p.health_max()
		_run += 1
		if _run >= RUNS:
			var sc = scenarios[_scenario]
			_log.append("%-18s -> won %d/%d  avg %.1fs  avg health left %d%%  clinches/fight %.1f" % [
				sc[0], _wins, RUNS, _time_sum / maxf(1.0, _wins), int(100.0 * _hp_sum / maxf(1.0, _wins)),
				float(_clinches) / RUNS])
			_clinches = 0
			_run = 0
			_wins = 0
			_time_sum = 0.0
			_hp_sum = 0.0
			_scenario += 1
			if _scenario >= scenarios.size():
				for l in _log:
					print(l)
				quit(0)
				return true
		_setup()
	return false


func _bot(p) -> void:
	for a in ["swipe", "dodge", "move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(a)
	if not is_instance_valid(_r) or p.is_dead:
		return
	var clinching: bool = p.state == p.State.CLINCH
	if clinching and not _was_clinch:
		_clinches += 1
	_was_clinch = clinching
	if clinching:
		Input.action_press("pounce")
		_clinch_bot(p)
		return
	Input.action_release("pounce")
	var to: Vector3 = _r.global_position - p.global_position
	to.y = 0
	var d := to.length()
	p._cam_yaw = atan2(-to.x, -to.z)
	var m: int = _r.move
	# Tells: TELL_SWIPE = 1, TELL_LUNGE = 3. Count from when this tell first showed.
	var tell_id: int = _r.get_instance_id() * 10 + m
	if (m == 1 or m == 3) and _tell_seen != tell_id:
		_tell_seen = tell_id
		_tell_t = 0.0
	_tell_t += 1.0 / 60.0
	if (m == 1 or m == 3) and _reacted_to != tell_id:
		if _tell_t >= REACTION_TIME:
			_reacted_to = tell_id
			if _rng.randf() < REACT_CHANCE:
				Input.action_press("move_left" if _rng.randf() < 0.5 else "move_right")
				p._start_dodge(Vector2(-1 if _rng.randf() < 0.5 else 1, 0))
				return
	if m != 1 and m != 3:
		_reacted_to = -1
		_tell_seen = -1
	if p.state != p.State.MOVE:
		return
	if d > 5.5:
		Input.action_press("move_forward")
		if d < 7.0 and p._pounce_cd <= 0.0 and p.pounces >= 1.0 and _rng.randf() < 0.05:
			Input.action_press("pounce")
			p.try_pounce()
	elif d < TU.SWIPE_RANGE + 0.3 and p._swipe_cd <= 0.0:
		p.heading = atan2(-to.x, -to.z)
		p._start_swipe()
	elif d >= TU.SWIPE_RANGE + 0.3:
		Input.action_press("move_forward")


## Inside a clinch: read each arrow late and not always right, like grapple_sim.
func _clinch_bot(p) -> void:
	var g = p.grapple
	if g == null:
		return
	if g.phase == 0:
		_commit = Vector2.ZERO
		return
	if g.exchanges != _seen_ex:
		_seen_ex = g.exchanges
		_seen_t = 0.0
		_commit = Vector2.ZERO
		_commit_dir = Vector2.ZERO
	_seen_t += 1.0 / 60.0
	if _commit_dir != g.dir and _seen_t >= REACTION_TIME:
		_commit_dir = g.dir
		_seen_t = 0.0
		var want: Vector2 = -g.dir if g.is_bite else g.dir
		_commit = want if _rng.randf() < REACT_CHANCE else Vector2.ZERO
	if _commit.x < -0.5:
		Input.action_press("move_left")
	elif _commit.x > 0.5:
		Input.action_press("move_right")
	elif _commit.y < -0.5:
		Input.action_press("move_forward")
	elif _commit.y > 0.5:
		Input.action_press("move_back")


func _setup() -> void:
	for n in get_nodes_in_group("rival"):
		n.queue_free()
	var sc = scenarios[_scenario]
	GS.strength = sc[1]
	var p = _main.player
	# A loss (or game over) in an earlier run must not leak into this one.
	GS.phase = GS.Phase.HUNTING
	Engine.time_scale = 1.0
	p.controls_enabled = true
	p.is_dead = false
	p.knock = Vector3.ZERO
	p.strength = sc[1]
	p.is_dead = false
	p.health = p.health_max()
	p.state = 0
	p.speed = 0.0
	p.grapple = null
	p.clinch_rival = null
	p.pounces = TU.POUNCE_STOCK
	GS.injured = false
	_seen_ex = -1
	var terrain = _main.terrain
	var at := Vector3(0, 0, -20)
	p.global_position = Vector3(at.x, terrain.height_at(at.x, at.z) + 0.5, at.z)
	_r = _main._make_rival("Sim", sc[2], at + Vector3(0, 0, -8))
	_r.can_disengage = false
	_r.rstate = 3   # FIGHT
	_t = 0.0
