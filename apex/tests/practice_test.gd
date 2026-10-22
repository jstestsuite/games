extends SceneTree
## Practice rooms (the title menu's debug tool): a room starts with one animal near you,
## no herds or hyenas; landing on it starts a ride; being thrown hurts and is logged;
## a fresh animal comes after each ride, or at once on roar.
##
## Run:  godot --headless --path . --fixed-fps 60 -s tests/practice_test.gd
## Exit code 0 = pass.

var _main: Node
var _failed := false
var GS: Node
var TU: Node
var _step := 0
var _f := 0
var _first: Node


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
				GS.menu_index = 1   # slow zebra
				_main._start_run()
				_next()
		1:
			if _f == 5:
				var prey := get_nodes_in_group("prey")
				_check(GS.practice == "ZEBRA_SLOW" and GS.phase == GS.Phase.HUNTING, "the slow-zebra room starts")
				_check(prey.size() == 1 and get_nodes_in_group("hyena").is_empty(), "one animal, no hyenas (prey=%d)" % prey.size())
				_first = prey[0]
				_check(_first.practice_slow < 1.0, "the slow zebra is slow")
				_check(_first.global_position.distance_to(p.global_position) < 25.0, "it's close by")
				# Pounce from right behind it.
				var to: Vector3 = _first.global_position + Vector3(2.0, 0.5, 0)
				p.global_position = to
				var dir: Vector3 = _first.global_position - to
				p.heading = atan2(-dir.x, -dir.z)
				p.try_pounce()
				_next()
		2:
			if p.state == p.State.RIDE:
				_check(true, "landing on it starts a ride")
				var hp: float = p.health
				p.ride.x = 0.9   # far off balance, and out of grip: thrown
				p.ride.grip = 0.0
				_f = 0
				_step = 3
				_m_hp = hp
			elif _f > 300:
				_check(false, "landing on it starts a ride (state=%d)" % p.state)
				_finish()
		3:
			if _f == 3:
				_check(p.state != p.State.RIDE, "off balance, you're thrown")
				_check(p.health < _m_hp, "being thrown hurts")
				_check(Engine.time_scale == 1.0, "game speed is back to normal")
				_check(_main._ride_log.size() == 1 and _main._ride_log[0].contains("thrown"), "the ride is logged")
			if _f == 30:
				# Roar: a fresh animal right away.
				p._roar()
			if _f == 33:
				var prey := get_nodes_in_group("prey")
				_check(prey.size() == 1 and prey[0] != _first, "roar brings a fresh animal")
				_check(p.health == p.health_max(), "and your health back")
				_finish()
	return false


var _m_hp := 0.0


func _next() -> void:
	_step += 1
	_f = 0


func _finish() -> void:
	print("PRACTICE TEST: ", "FAIL" if _failed else "PASS")
	quit(1 if _failed else 0)
	_step = 99


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failed = true
