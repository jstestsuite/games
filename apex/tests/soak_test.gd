extends SceneTree
## Soak test: a bot plays two minutes of a pride day (stalk, charge, pounce, ride
## like a person, eat, fight hyenas) while the test watches the whole world for things
## that break quietly: animals leaving the map or going NaN, fleeing prey stuck on rocks
## (the v2 "running in circles" bug), lionesses that never hunt, a hyena clan that never
## shows up. Pass/fail.
##
## Run:  godot --headless --path . --fixed-fps 60 -s tests/soak_test.gd
## Exit code 0 = pass. Results are random from run to run (the world is random).

const DURATION := 120.0
const REACT_CHANCE := 0.85
const REACTION_TIME := 0.28
const STUCK_LIMIT := 3.0      # seconds a fleeing animal may go nowhere before it counts as stuck

var _main: Node
var GS: Node
var TU: Node
var _f := 0
var _t := 0.0
var _failed := false
var _rng := RandomNumberGenerator.new()
var _check_t := 0.0
var _last_pos := {}           # instance id -> position at the last check
var _stuck_for := {}          # instance id -> seconds barely moving while fleeing
var _worst_stuck := 0.0
var _lioness_hunted := false
var _hyena_at_kill := false
var _max_hyenas := 0
var _escaped := ""
var _stuck_note := ""
var _seen_ex := -1
var _seen_t := 0.0
var _commit := Vector2.ZERO
var _commit_dir := Vector2.ZERO


func _initialize() -> void:
	_rng.seed = 5
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _physics_process(delta: float) -> bool:
	_f += 1
	if GS == null:
		GS = root.get_node("GameState")
		TU = root.get_node("Tuning")
		return false
	var p = _main.player
	if _f == 3:
		_main._start_run()
		GS.day = GS.last_day()
		GS.act = GS.Act.PRIDE
		GS.lionesses = TU.LIONESS_COUNT
		GS.pride_since_day = GS.day - 1
		GS.strength = 1.6   # about what a lion has by the last day
		p.health = p.health_max()
		_main._start_day()
		var c := _zebra_center()
		var start: Vector3 = c + Vector3(0, 0, 45)
		p.global_position = Vector3(start.x, _main.terrain.height_at(start.x, start.z) + 0.5, start.z)
		for l in get_nodes_in_group("lioness"):
			l.global_position = p.global_position + Vector3(_rng.randf_range(-5, 5), 0, 6)
		return false
	if _f < 3:
		return false

	_t += delta
	GS.day_time = 20.0   # stay mid-day: no dusk challengers in this test
	GS.hunger = minf(GS.hunger, TU.HUNGER_MAX * 0.7)   # always hungry enough to hunt
	_bot(p, delta)
	_watch(delta)
	if _t >= DURATION or p.is_dead:
		_finish(p)
	return false


# --- the bot ---------------------------------------------------------------------

func _bot(p, delta: float) -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "sprint", "stalk", "swipe", "roar"]:
		Input.action_release(a)
	match p.state:
		p.State.RIDE:
			_ride_bot(p)
			return
		p.State.CLINCH:
			Input.action_press("pounce")
			_grapple_bot(p, delta)
			return
		p.State.EATING:
			Input.action_release("pounce")
			# Defend the meal: roar when hyenas crowd in, swipe one that's biting.
			var close := 0
			for h in get_nodes_in_group("hyena"):
				if not h.is_dead and h.global_position.distance_to(p.global_position) < 8.0:
					close += 1
					if h.hstate == h.HState.TELL and p._swipe_cd <= 0.0:
						p._start_swipe()
						return
			if close >= 2 and p.roar_cd <= 0.0:
				p._roar()
			return
	Input.action_release("pounce")
	if p.state != p.State.MOVE:
		return
	var tgt = _nearest_prey(p)
	if tgt == null:
		return
	var to: Vector3 = tgt.global_position - p.global_position
	to.y = 0
	var d := to.length()
	p._cam_yaw = atan2(-to.x, -to.z)
	Input.action_press("move_forward")
	if d > 18.0 and tgt.state == tgt.State.GRAZE:
		Input.action_press("stalk")
	else:
		Input.action_press("sprint")
	if d < 4.0 and p._pounce_cd <= 0.0 and p.pounces >= 1.0:
		Input.action_press("pounce")
		p.try_pounce()


## Keep our weight over its back: push against the drift (assumes the BALANCE feel and a
## camera behind the animal, so screen-right is its right).
func _ride_bot(p) -> void:
	var r = p.ride
	if r == null:
		return
	var u := clampf(-(3.0 * r.x + 0.6 * r.xv), -1.0, 1.0)
	if u > 0.05:
		Input.action_press("move_right", u)
	elif u < -0.05:
		Input.action_press("move_left", -u)


func _grapple_bot(p, delta: float) -> void:
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
	_seen_t += delta
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


func _nearest_prey(p) -> Node:
	var best = null
	var best_d := 999.0
	for g in get_nodes_in_group("prey"):
		# Only things a lion with a pride should take on.
		if g.species == "BUFFALO" and GS.lionesses == 0:
			continue
		var d: float = g.global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = g
	return best


func _zebra_center() -> Vector3:
	for h in _main.herds:
		if h.members.size() > 0 and h.members[0].species == "ZEBRA":
			return h.center
	return _main.herds[0].center


# --- watching the world ---------------------------------------------------------

func _watch(delta: float) -> void:
	for l in get_nodes_in_group("lioness"):
		if l.lstate == l.LState.HUNT or l.lstate == l.LState.HOLD:
			_lioness_hunted = true
	var hyenas := get_nodes_in_group("hyena")
	_max_hyenas = maxi(_max_hyenas, hyenas.size())
	for h in hyenas:
		if is_instance_valid(h.carcass) and h.global_position.distance_to(h.carcass.global_position) < TU.HYENA_GUARD_RADIUS + 6.0:
			_hyena_at_kill = true

	_check_t += delta
	if _check_t < 0.5:
		return
	_check_t = 0.0
	var half: float = TU.WORLD_SIZE * 0.5 + 5.0
	for group in ["player", "prey", "carcass", "hyena", "lioness", "rival"]:
		for n in get_nodes_in_group(group):
			var pos: Vector3 = n.global_position
			var bad: bool = not (is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z)) \
					or absf(pos.x) > half or absf(pos.z) > half \
					or pos.y < _main.terrain.height_at(pos.x, pos.z) - 5.0
			if bad and _escaped == "":
				_escaped = "%s %s at %s" % [group, n.name, pos]
	# Fleeing prey that barely moves for a while is stuck on something.
	for g in get_nodes_in_group("prey"):
		var id: int = g.get_instance_id()
		var pos: Vector3 = g.global_position
		if _last_pos.has(id) and g.state == g.State.FLEE and g.speed > 3.0:
			var moved := Vector2(pos.x - _last_pos[id].x, pos.z - _last_pos[id].z).length()
			if moved < g.speed * 0.5 * 0.25:   # under a quarter of where it should have got to
				_stuck_for[id] = _stuck_for.get(id, 0.0) + 0.5
				if _stuck_for[id] > _worst_stuck:
					_worst_stuck = _stuck_for[id]
					_stuck_note = _describe_stuck(g)
			else:
				_stuck_for[id] = 0.0
		else:
			_stuck_for[id] = 0.0
		_last_pos[id] = pos


## Where and why: nearest obstacle, map edge, wall contact. For fixing it.
func _describe_stuck(g) -> String:
	var pos: Vector3 = g.global_position
	var near := 999.0
	for o in _main.terrain.obstacles:
		near = minf(near, Vector2(o.x - pos.x, o.y - pos.z).length() - o.z)
	var edge: float = TU.WORLD_SIZE * 0.5 - maxf(absf(pos.x), absf(pos.z))
	return "%s at (%.0f, %.0f): nearest obstacle %.1fm, map edge %.0fm, on wall %s, slope %.2f" % [
		g.species, pos.x, pos.z, near, edge, g.is_on_wall(), 1.0 - g._floor_normal.y]


func _finish(p) -> void:
	print("  kills %d · pride food %d · health %d%% · strength %.2f · most hyenas at once %d · worst stuck %.1fs" % [
		GS.kills, int(GS.pride_food), int(100.0 * p.health / p.health_max()), GS.strength, _max_hyenas, _worst_stuck])
	_check(_escaped == "", "nothing left the world or went NaN %s" % ("" if _escaped == "" else "(" + _escaped + ")"))
	if _stuck_note != "":
		print("  worst stuck: " + _stuck_note)
	if p.is_dead:
		print("  (the bot died at %.0fs: %s; that's difficulty, not a bug)" % [_t, p.last_hurt_by])
	_check(_worst_stuck < STUCK_LIMIT, "no fleeing animal stuck for %.0fs+ (worst %.1fs)" % [STUCK_LIMIT, _worst_stuck])
	_check(GS.kills >= 1 or GS.pride_food > 0.0 or p.is_dead, "the bot or the pride made a kill")
	_check(_lioness_hunted, "lionesses joined a hunt")
	_check(_max_hyenas >= TU.HYENA_ROAMERS, "the hyena clan was out")
	_check(_hyena_at_kill or get_nodes_in_group("carcass").is_empty(), "hyenas came to a kill")
	print("SOAK TEST: ", "FAIL" if _failed else "PASS")
	quit(1 if _failed else 0)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failed = true
