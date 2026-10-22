extends SceneTree
## Grapple probe: a bot with human reaction time wrestles each species at several
## strengths, alone and with lionesses, and reports how it goes. Not pass/fail.
## Use it after changing the grapple values in Tuning.
##
## The bot needs REACTION_TIME to read an arrow, then gets it right REACT_CHANCE of the
## time. If the arrow switches (a fake-out) it needs another REACTION_TIME to adjust.
##
## Run:  godot --headless --path . --fixed-fps 60 -s tests/grapple_sim.gd

const ProbeLog := preload("res://tests/probe_log.gd")
const RUNS := 12
const REACT_CHANCE := 0.8
const REACTION_TIME := 0.28
const MAX_TIME := 40.0

var _main: Node
var GS: Node
var TU: Node
var _step := 0
var _t := 0.0
var _scenario := 0
var _run := 0
var _g: Node
var _helpers: Array = []
var _rng := RandomNumberGenerator.new()
var _seen_ex := -1
var _seen_t := 0.0
var _commit := Vector2.ZERO
var _commit_dir := Vector2.ZERO
var _hp0 := 0.0
var _stats := {}
var _log: Array[String] = []

# [label, species, strength, lionesses helping]
var scenarios := [
	["warthog  day 1", "WARTHOG", 1.0, 0],
	["zebra    day 1", "ZEBRA", 1.0, 0],
	["zebra    day 2", "ZEBRA", 1.4, 0],
	["wildeb.  day 1", "WILDEBEEST", 1.0, 0],
	["wildeb.  day 2", "WILDEBEEST", 1.4, 0],
	["wildeb.  pride", "WILDEBEEST", 1.6, 2],
	["buffalo  solo ", "BUFFALO", 1.6, 0],
	["buffalo  pride", "BUFFALO", 1.6, 3],
]


func _initialize() -> void:
	_rng.seed = 11
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _physics_process(delta: float) -> bool:
	if GS == null:
		GS = root.get_node("GameState")
		TU = root.get_node("Tuning")
		return false
	if _step == 0:
		_main._start_run()
		_step = 1
		_setup()
		return false

	_t += delta
	GS.day_time = 10.0
	GS.hunger = TU.HUNGER_MAX * 0.6
	var p = _main.player
	_bot(p, delta)

	var won: bool = is_instance_valid(_g) and _g.is_dead
	var lost: bool = p.is_dead or (p.state != p.State.TAKEDOWN and not won)
	if won or lost or _t > MAX_TIME:
		_record(p, won)
		_run += 1
		if _run >= RUNS:
			_report()
			_run = 0
			_scenario += 1
			if _scenario >= scenarios.size():
				for l in _log:
					print(l)
				ProbeLog.save(self, "grapple_sim", _log)
				quit(0)
				return true
		_setup()
	return false


## React to the arrow like a person: late, and not always right.
func _bot(p, delta: float) -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)
	var g = p.grapple
	if g == null:
		return
	if g.phase == 0:   # WAIT: hands off the stick
		_commit = Vector2.ZERO
		return
	if g.exchanges != _seen_ex:
		_seen_ex = g.exchanges
		_seen_t = 0.0
		_commit = Vector2.ZERO
		_commit_dir = Vector2.ZERO
	_seen_t += delta
	if _commit_dir != g.dir and _seen_t >= REACTION_TIME:
		# First read, or re-read after a switch.
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


func _record(p, won: bool) -> void:
	var st: Dictionary = _stats
	st["n"] = st.get("n", 0) + 1
	if won:
		st["won"] = st.get("won", 0) + 1
		st["time"] = st.get("time", 0.0) + _t
	if GS.injured:
		st["injured"] = st.get("injured", 0) + 1
	if p.is_dead:
		st["dead"] = st.get("dead", 0) + 1
	st["dmg"] = st.get("dmg", 0.0) + (_hp0 - p.health) / p.health_max()


func _report() -> void:
	var sc = scenarios[_scenario]
	var st := _stats
	var n: int = st.get("n", 1)
	var w: int = st.get("won", 0)
	_log.append("%s -> won %2d/%d  avg %4.1fs  health lost %3d%%  injured %2d  died %d" % [
		sc[0], w, n, st.get("time", 0.0) / maxf(1.0, w), int(100.0 * st.get("dmg", 0.0) / n),
		st.get("injured", 0), st.get("dead", 0)])
	_stats = {}


func _setup() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)
	for n in _helpers:
		if is_instance_valid(n):
			n.queue_free()
	_helpers.clear()
	for group in ["prey", "carcass", "hyena", "rival"]:
		for n in get_nodes_in_group(group):
			n.queue_free()
	var sc = scenarios[_scenario]
	var p = _main.player
	# A loss in an earlier run must not leak into this one.
	GS.phase = GS.Phase.HUNTING
	Engine.time_scale = 1.0
	GS.strength = sc[2]
	GS.injured = false
	p.controls_enabled = true
	p.is_dead = false
	p.strength = sc[2]
	p.health = p.health_max()
	_hp0 = p.health
	p.state = 0
	p.grapple = null
	p.grab_target = null
	p.knock = Vector3.ZERO
	var terrain = _main.terrain
	var gp := Vector3(0, 0, -40)
	_g = load("res://scripts/actors/prey.gd").new()
	_g.species = sc[1]
	_g.terrain = terrain
	_main.add_child(_g)
	_g.global_position = Vector3(gp.x, terrain.height_at(gp.x, gp.z) + 0.3, gp.z)
	_g.weak = false
	p.global_position = _g.global_position + Vector3(1.5, 0.3, 0)
	var to: Vector3 = _g.global_position - p.global_position
	p.heading = atan2(-to.x, -to.z)
	p._cam_yaw = p.heading
	for i in sc[3]:
		var l = _main._make_lioness(i, _g.global_position + Vector3(-1.5, 0, i))
		l.join()
		_helpers.append(l)
	Input.action_press("pounce")
	_g.grab(p)
	for l in _helpers:
		_g.grab(l)
		l.target = _g
		l._go(3)   # HOLD
	p._start_takedown(_g)
	_seen_ex = -1
	_t = 0.0
