extends SceneTree
## Tuning probe: puts the lion near one animal in different postures and reports how
## it reacts, then runs scripted chases (burst, run, pounce, hold the grip) against each
## species from several distances. Not pass/fail. Use it after changing Tuning.
## Each chase runs RUNS times; results show catches / runs and the average time.
##
## Run:  godot --headless --path . --fixed-fps 60 -s tests/hunt_sim.gd

const RUNS := 4

var _main: Node
var GS: Node
var TU: Node
var _step := 0
var _t := 0.0
var _scenario := 0
var _run := 0
var _g: Node
var _min_d := 999.0
var _results := {}   # label -> [catches, total_time_of_catches]
var _log: Array[String] = []

# [label, species, posture action or "", start distance, seconds, chase?]
var scenarios := [
	["stalk 14m", "ZEBRA", "stalk", 14.0, 4.0, false],
	["walk 14m", "ZEBRA", "", 14.0, 4.0, false],
	["walk 30m", "ZEBRA", "", 30.0, 4.0, false],
	["zebra 12m", "ZEBRA", "sprint", 12.0, 16.0, true],
	["zebra 20m", "ZEBRA", "sprint", 20.0, 16.0, true],
	["zebra 28m", "ZEBRA", "sprint", 28.0, 16.0, true],
	["zebra 40m", "ZEBRA", "sprint", 40.0, 18.0, true],
	["young zebra 28m", "ZEBRA", "sprint", 28.0, 16.0, true],
	["young zebra 40m", "ZEBRA", "sprint", 40.0, 18.0, true],
	["warthog 20m", "WARTHOG", "sprint", 20.0, 14.0, true],
	["wildebeest 20m", "WILDEBEEST", "sprint", 20.0, 16.0, true],
	["buffalo 15m", "BUFFALO", "sprint", 15.0, 16.0, true],
]


func _initialize() -> void:
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
	GS.hunger = TU.HUNGER_MAX * 0.6
	GS.day_time = 10.0   # never let night fall mid-probe
	var p = _main.player
	p.health = p.health_max()
	var sc = scenarios[_scenario]
	var done := false
	if is_instance_valid(_g):
		var d: float = p.global_position.distance_to(_g.global_position)
		_min_d = minf(_min_d, d)
		if sc[5]:
			# Steer at the animal by aiming the camera at it; pounce when close; hold the grip.
			var to: Vector3 = _g.global_position - p.global_position
			p._cam_yaw = atan2(-to.x, -to.z)
			if d < 4.0 and p.state == p.State.MOVE and p._pounce_cd <= 0.0:
				Input.action_press("pounce")   # held from here: keeps the grip once it lands
				p._start_pounce()
		done = _g.is_dead
	if _t >= sc[4] or done:
		_record(sc, done)
		_run += 1
		if not sc[5] or _run >= RUNS:
			_run = 0
			_scenario += 1
		if _scenario >= scenarios.size():
			for l in _log:
				print(l)
			quit(0)
			return true
		_setup()
	return false


func _record(sc: Array, caught: bool) -> void:
	var states := ["GRAZE", "ALERT", "FLEE", "DEFEND", "GRABBED", "DEAD"]
	if not sc[5]:
		_log.append("%-15s -> %-7s awareness=%.2f  min_dist=%.1f" % [
			sc[0], states[_g.state], _g.awareness, _min_d])
		return
	var r: Array = _results.get(sc[0], [0, 0.0])
	if caught:
		r[0] += 1
		r[1] += _t
	_results[sc[0]] = r
	if _run == RUNS - 1:
		var avg: float = r[1] / maxf(1.0, r[0])
		_log.append("%-15s -> caught %d/%d  avg %.1fs" % [sc[0], r[0], RUNS, avg])


func _setup() -> void:
	Input.action_release("sprint")
	Input.action_release("stalk")
	Input.action_release("move_forward")
	Input.action_release("pounce")
	for group in ["prey", "carcass", "hyena"]:
		for n in get_nodes_in_group(group):
			n.queue_free()
	var sc = scenarios[_scenario]
	var terrain = _main.terrain
	_main.wind = Vector2(1, 0)
	var gp := Vector3(0, 0, -40)
	_g = load("res://scripts/actors/prey.gd").new()
	_g.species = sc[1]
	_g.terrain = terrain
	_g.wind = Vector2(1, 0)
	_main.add_child(_g)
	_g.global_position = Vector3(gp.x, terrain.height_at(gp.x, gp.z) + 0.3, gp.z)
	_g.weak = (sc[0] as String).begins_with("young")
	_g._grazing = false   # head up: worst case for the lion
	_g._graze_timer = 99.0
	_g._defend_rolled = true   # no buffalo counter-charges in the probe
	var pp := gp + Vector3(0, 0, sc[3])
	var p = _main.player
	# A loss (or game over) in an earlier run must not leak into this one.
	GS.phase = GS.Phase.HUNTING
	Engine.time_scale = 1.0
	p.controls_enabled = true
	p.is_dead = false
	p.knock = Vector3.ZERO
	p.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.5, pp.z)
	p.heading = 0.0
	p._cam_yaw = 0.0
	p.speed = 0.0
	p.charge = p.max_charge()
	p.winded_t = 0.0
	p.sprinting = false
	p.state = 0
	p.grab_target = null
	Input.action_press("move_forward")
	if sc[2] != "":
		Input.action_press(sc[2])
	_t = 0.0
	_min_d = 999.0
