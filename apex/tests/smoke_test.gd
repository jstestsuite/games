extends SceneTree
## Headless smoke test: loads the game, starts a run, simulates a hunt with scripted
## input, and fails loudly on script errors or broken invariants.
##
## Run:  godot --headless --path . -s tests/smoke_test.gd
## Exit code 0 = pass.

var _frames := 0
var _main: Node
var _failed := false
var GS: Node      # autoloads aren't compile-time globals in a -s script
var TU: Node


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if GS == null:
		GS = root.get_node("GameState")
		TU = root.get_node("Tuning")
	if _frames == 5:
		_check(get_nodes_in_group("prey").size() >= TU.HERDS_PER_DAY * TU.GAZELLES_PER_HERD.x, "herds spawned")
		_main._start_run()
		_check(GS.phase == GS.Phase.HUNTING, "run started")
	if _frames == 10:
		# Teleport next to a gazelle and pounce at it.
		var g = get_nodes_in_group("prey")[0]
		var p = _main.player
		var to: Vector3 = g.global_position + Vector3(3, 0.5, 0)
		p.global_position = to
		var dir: Vector3 = g.global_position - to
		p.heading = atan2(-dir.x, -dir.z)
		p._start_pounce()
	if _frames == 60:
		_check(GS.kills >= 1, "pounce at point-blank range catches prey (kills=%d)" % GS.kills)
	if _frames == 70:
		# Skip to the end of the day and pick a trait.
		GS.day_time = TU.DAY_LENGTH
	if _frames == 75:
		_check(GS.phase == GS.Phase.NIGHT or GS.phase == GS.Phase.GAME_OVER, "day ended")
		if GS.phase == GS.Phase.NIGHT:
			_main.hud.pick_trait(0)
	if _frames == 80:
		_check(GS.day == 2 and GS.traits.size() == 1, "day 2 with one trait")
		_check(get_nodes_in_group("prey").size() > 0, "herds respawned")
	if _frames == 200:
		print("SMOKE TEST: ", "FAIL" if _failed else "PASS")
		quit(1 if _failed else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failed = true
