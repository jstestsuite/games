extends SceneTree
## Renders a few screenshots to res://screenshots/ for a quick visual check.
## Needs a real (or virtual) display, not --headless:
##   godot --path . -s tests/screenshot.gd

var _main: Node
var _f := 0
var GS: Node
var shots := [
	# [name, day fraction, distance from herd, camera pitch, yaw offset]
	["morning_herd", 0.08, 14.0, -0.18, 0.4],
	["midday_wide", 0.5, 30.0, -0.35, 2.0],
	["dusk_stalk", 0.94, 11.0, -0.12, -0.6],
]
var _shot := 0


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_d: float) -> bool:
	_f += 1
	if GS == null:
		GS = root.get_node("GameState")
	if _f == 3:
		_main._start_run()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _f > 3 and (_f - 4) % 90 == 0 and _shot < shots.size():
		_setup(shots[_shot])
	if _f > 3 and (_f - 4) % 90 == 80 and _shot < shots.size():
		DirAccess.make_dir_recursive_absolute("res://screenshots")
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("res://screenshots/%s.png" % shots[_shot][0])
		print("saved ", shots[_shot][0])
		_shot += 1
		if _shot >= shots.size():
			quit(0)
	return false


func _setup(s: Array) -> void:
	GS.day_time = s[1] * root.get_node("Tuning").DAY_LENGTH
	_main._set_sun(s[1])
	var herd = _main.herds[0]
	var p = _main.player
	var c: Vector3 = herd.center
	var a: float = s[4]
	var pos: Vector3 = c + Vector3(sin(a), 0, cos(a)) * s[2]
	pos.y = _main.terrain.height_at(pos.x, pos.z) + 0.3
	p.global_position = pos
	var to: Vector3 = c - pos
	p.heading = atan2(-to.x, -to.z)
	p._cam_yaw = p.heading + 0.35
	p._cam_pitch = s[3]
	p.cam_pivot.global_position = pos + Vector3(0, 2.2, 0)
	p.controls_enabled = false
	if s[0] == "dusk_stalk":
		p.stalking = true
