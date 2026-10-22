extends SceneTree
## Headless smoke test: loads the game and drives a whole life with shortcuts:
## a takedown and a meal, hyenas, a night, the challenge fight, the pride days and
## the dusk challengers, ending in victory. Fails loudly on broken invariants.
##
## Run:  godot --headless --path . --fixed-fps 60 -s tests/smoke_test.gd
## Exit code 0 = pass.

var _main: Node
var _failed := false
var GS: Node      # autoloads aren't compile-time globals in a -s script
var TU: Node
var _step := 0
var _f := 0       # frames in this step
var _prey: Node


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _physics_process(_delta: float) -> bool:
	if GS == null:
		GS = root.get_node("GameState")
		TU = root.get_node("Tuning")
		return false
	_f += 1
	var p = _main.player
	match _step:
		0:
			if _f == 3:
				_check(get_nodes_in_group("prey").size() >= 6, "herds spawned")
				_main._start_run()
				_check(GS.phase == GS.Phase.HUNTING and GS.act == GS.Act.NOMAD, "run started as a nomad")
				_next()
		1:
			# Teleport behind a zebra and pounce, holding the grip.
			_prey = _first_prey("ZEBRA")
			var to: Vector3 = _prey.global_position + Vector3(2.5, 0.5, 0)
			p.global_position = to
			var dir: Vector3 = _prey.global_position - to
			p.heading = atan2(-dir.x, -dir.z)
			Input.action_press("pounce")
			p._start_pounce()
			_next()
		2:
			if p.state == p.State.EATING or _f > 600:
				Input.action_release("pounce")
				_check(GS.kills >= 1, "takedown kills the zebra (kills=%d)" % GS.kills)
				_check(p.state == p.State.EATING, "lion eats after the kill")
				_next()
		3:
			if _f == 60:
				_check(GS.strength > TU.STRENGTH_START, "eating builds strength (%.3f)" % GS.strength)
				var c = get_nodes_in_group("carcass")[0]
				_main._spawn_hyenas(c, 2)
				_check(get_nodes_in_group("hyena").size() == 2, "hyenas spawn at a carcass")
			if _f == 200:
				var h = get_nodes_in_group("hyena")[0]
				h.take_hit(999.0, p.global_position, true)
				_check(h.is_dead, "hyenas can be killed")
				p._roar()
				_next()
		4:
			# Sprint check: a burst, then a slower run.
			if _f == 1:
				p.state = p.State.MOVE
				p.charge = p.max_charge()
				p.winded_t = 0.0
				Input.action_press("move_forward")
				Input.action_press("sprint")
			if _f == 90:
				_check(p.bursting and p.speed > TU.RUN_SPEED + 1.0, "sprint starts with a burst (%.1f m/s)" % p.speed)
			if _f == 300:
				_check(p.sprinting and not p.bursting and p.speed < TU.CHARGE_SPEED - 2.0, "burst fades into a run (%.1f m/s)" % p.speed)
				Input.action_release("sprint")
				Input.action_release("move_forward")
				_next()
		5:
			GS.day_time = TU.DAY_LENGTH
			_next()
		6:
			if _f == 5:
				_check(GS.phase == GS.Phase.NIGHT, "day ends in night")
				_main.hud.pick_trait(0)
			if _f == 10:
				_check(GS.day == 2 and GS.traits.size() == 1, "day 2 with one trait")
				_check(get_nodes_in_group("prey").size() > 0, "herds respawned")
				# Skip to the challenge day.
				GS.day = GS.challenge_day() - 1
				GS.hunger = TU.HUNGER_MAX
				GS.day_time = TU.DAY_LENGTH
			if _f == 15:
				_main.hud.pick_trait(0)
			if _f == 20:
				_check(GS.act == GS.Act.CHALLENGE, "challenge day")
				_check(is_instance_valid(_main.pride_male), "pride male at the den")
				_check(get_nodes_in_group("lioness").size() == TU.LIONESS_COUNT, "lionesses at the den")
				var m = _main.pride_male
				p.global_position = m.global_position + Vector3(12, 1, 0)
				_next()
		7:
			var m = _main.pride_male
			if _f == 30:
				_check(m.in_fight(), "pride male squares up when you come close")
			if _f == 40:
				m.take_hit(9999.0, p.global_position, true)
				_check(GS.act == GS.Act.PRIDE, "beating the male gives you the pride")
				_check(GS.lionesses == TU.LIONESS_COUNT, "lionesses join you (%d)" % GS.lionesses)
				_next()
		8:
			if _f == 30:
				GS.pride_food = TU.PRIDE_FOOD_NEED
				GS.day_time = TU.DAY_LENGTH
			if _f == 40:
				_check(GS.phase == GS.Phase.NIGHT, "night after the challenge")
				_main.hud.pick_trait(0)
			if _f == 50:
				_check(GS.act == GS.Act.PRIDE and GS.day == GS.last_day(), "last day, holding the pride")
				_check(get_nodes_in_group("lioness").size() == GS.lionesses, "lionesses follow you into the day")
				GS.day_time = TU.DAY_LENGTH
			if _f == 60:
				_check(_main.challengers.size() == TU.CHALLENGER_COUNT, "challengers arrive at dusk")
				_next()
		9:
			if _f % 20 == 0 and _main.challengers.size() > 0:
				_main.challengers[0].take_hit(9999.0, p.global_position, true)
			if GS.phase == GS.Phase.VICTORY:
				_check(true, "beating the challengers wins the run")
				_finish()
			elif _f > 600:
				_check(false, "victory reached (phase=%d)" % GS.phase)
				_finish()
	return false


func _first_prey(sp: String) -> Node:
	for n in get_nodes_in_group("prey"):
		if n.species == sp:
			return n
	return get_nodes_in_group("prey")[0]


func _next() -> void:
	_step += 1
	_f = 0


func _finish() -> void:
	_check(not root.get_node("GameState").phase == GS.Phase.GAME_OVER, "never died along the way")
	print("SMOKE TEST: ", "FAIL" if _failed else "PASS")
	quit(1 if _failed else 0)
	_step = 99


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failed = true
