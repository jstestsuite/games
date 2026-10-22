extends SceneTree
## Tuning probe: puts the cheetah near an isolated gazelle in different postures and
## reports how the gazelle reacts, then runs scripted chases from several distances.
## Not pass/fail. Use it to sanity-check numbers after changing Tuning.
##
## Run:  godot --headless --path . --fixed-fps 60 -s tests/hunt_sim.gd

var _main: Node
var GS: Node
var TU: Node
var _step := 0
var _t := 0.0
var _scenario := 0
var _g: Node
var _min_d := 999.0
var _log: Array[String] = []

# [label, posture action or "", start distance, seconds, chase?]
var scenarios := [
	["stalk 14m", "stalk", 14.0, 4.0, false],
	["walk 14m", "", 14.0, 4.0, false],
	["walk 30m", "", 30.0, 4.0, false],
	["chase from 14m", "sprint", 14.0, 6.0, true],
	["chase from 20m", "sprint", 20.0, 6.0, true],
	["chase from 28m", "sprint", 28.0, 6.0, true],
	["chase from 36m", "sprint", 36.0, 7.0, true],
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
		GS.hunger = 100.0
		_step = 1
		_setup()
		return false

	_t += delta
	var p = _main.player
	var d: float = p.global_position.distance_to(_g.global_position)
	_min_d = minf(_min_d, d)
	var sc = scenarios[_scenario]
	if sc[4]:
		# Steer straight at the gazelle by aiming the camera at it.
		var to: Vector3 = _g.global_position - p.global_position
		p._cam_yaw = atan2(-to.x, -to.z)
		if d < 3.5 and p.state == 0:
			p._start_pounce()
	if _t >= sc[3] or _g.is_dead:
		var states := ["GRAZE", "ALERT", "FLEE", "DEAD"]
		_log.append("%-16s -> %-5s awareness=%.2f  min_dist=%.1f  kills=%d" % [
			sc[0], states[_g.state], _g.awareness, _min_d, GS.kills])
		_scenario += 1
		if _scenario >= scenarios.size():
			for l in _log:
				print(l)
			quit(0)
			return true
		_setup()
	return false


func _setup() -> void:
	Input.action_release("sprint")
	Input.action_release("stalk")
	Input.action_release("move_forward")
	# Clear the map and place one gazelle in the open, wind blowing sideways.
	for n in get_nodes_in_group("gazelle_all"):
		n.queue_free()
	var sc = scenarios[_scenario]
	var terrain = _main.terrain
	_main.wind = Vector2(1, 0)
	var gp := Vector3(0, 0, -40)
	_g = load("res://scripts/actors/gazelle.gd").new()
	_g.terrain = terrain
	_g.player = _main.player
	_g.wind = Vector2(1, 0)
	_g.add_to_group("gazelle_all")
	_main.add_child(_g)
	_g.global_position = Vector3(gp.x, terrain.height_at(gp.x, gp.z) + 0.3, gp.z)
	_g._grazing = false   # head up: worst case for the cat
	_g._graze_timer = 99.0
	var pp := gp + Vector3(0, 0, sc[2])
	var p = _main.player
	p.global_position = Vector3(pp.x, terrain.height_at(pp.x, pp.z) + 0.5, pp.z)
	p.heading = 0.0
	p._cam_yaw = 0.0
	p.speed = 0.0
	p.stamina = TU.STAMINA_MAX
	p.exhausted = false
	p.state = 0
	Input.action_press("move_forward")
	if sc[1] != "":
		Input.action_press(sc[1])
	_t = 0.0
	_min_d = 999.0
