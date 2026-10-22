extends SceneTree
## Renders a few screenshots to res://screenshots/ for a quick visual check.
## Needs a real (or virtual) display, not --headless:
##   godot --path . --fixed-fps 30 -s tests/screenshot.gd

var _main: Node
var _f := 0
var GS: Node
var shots := [
	# [name, day fraction, setup]
	["morning_zebras", 0.08, "ZEBRA"],
	["midday_buffalo", 0.45, "BUFFALO"],
	["dusk_stalk", 0.94, "WILDEBEEST"],
	["rival_lunge_tell", 0.3, "rival"],
	["pride_at_den", 0.7, "den"],
	["hyenas_at_kill", 0.6, "hyenas"],
	["grapple_zebra", 0.35, "grapple"],
	["clinch", 0.4, "clinch"],
]
var _shot := 0
var _rival: Node


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
	var pl = _main.player if _main else null
	if pl and pl.grapple != null:
		# Freeze the struggle mid-warning so the arrow shows.
		pl.grapple.phase = 1
		pl.grapple.t = 0.35
		pl.grapple.dir = Vector2(-1, 0)
		pl.grapple.is_bite = pl.grapple.kind == 1
		pl.grapple._tell_len = 0.5
		pl.grapple.grip = 0.6
		pl.grapple.progress = 0.45
		pl.grapple.balance = 0.3
	elif is_instance_valid(_rival):
		# Hold the rival in his lunge windup so the tell shows.
		_rival.move = 3
		_rival._t = 0.5
	if _f > 3 and (_f - 4) % 90 == 80 and _shot < shots.size():
		DirAccess.make_dir_recursive_absolute("res://screenshots")
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("res://screenshots/%s.png" % shots[_shot][0])
		print("saved ", shots[_shot][0])
		_shot += 1
		if _shot >= shots.size():
			quit(0)
	return false


func _herd_center(sp: String) -> Vector3:
	for n in get_nodes_in_group("prey"):
		if n.species == sp:
			return n.herd.center
	return _main.herds[0].center


func _place_cam(p, pos: Vector3, look_at: Vector3, pitch: float, yaw_off: float) -> void:
	pos.y = _main.terrain.height_at(pos.x, pos.z) + 0.3
	p.global_position = pos
	var to: Vector3 = look_at - pos
	p.heading = atan2(-to.x, -to.z)
	p._cam_yaw = p.heading + yaw_off
	p._cam_pitch = pitch
	p.cam_pivot.global_position = pos + Vector3(0, 2.6, 0)
	p.controls_enabled = false


func _setup(s: Array) -> void:
	GS.day_time = s[1] * root.get_node("Tuning").DAY_LENGTH
	_main._set_sun(s[1])
	var p = _main.player
	p.stalking = false
	match s[2]:
		"rival":
			var at: Vector3 = p.global_position + Vector3(0, 0, -5)
			_rival = _main._make_rival("Pride male", 1.6, at)
			_rival.rstate = 3
			_place_cam(p, p.global_position, at, -0.15, 0.5)
		"den":
			_rival = null
			_main._clear_actors()
			_main._spawn_pride_at_den()
			var den: Vector3 = _main.den
			_place_cam(p, den + Vector3(14, 0, 8), den, -0.2, 0.3)
		"grapple":
			_rival = null
			if get_nodes_in_group("prey").is_empty():
				_main._spawn_herds()
			var z = null
			for n in get_nodes_in_group("prey"):
				if n.species == "ZEBRA":
					z = n
					break
			p.global_position = z.global_position + Vector3(1.0, 0.4, 0)
			z.grab(p)
			p._start_takedown(z)
			p._cam_yaw = p.heading
			p.controls_enabled = false
		"clinch":
			if is_instance_valid(p.grab_target):
				p.grab_target.release(p)
			p._end_grapple()
			p.state = 0
			var at: Vector3 = p.global_position + Vector3(0, 0, -2)
			_rival = _main._make_rival("Pride male", 1.6, at)
			_rival.rstate = 3
			p.controls_enabled = false
			p.start_clinch(_rival, 0.2)
			p._cam_yaw = p.heading
		"hyenas":
			if get_nodes_in_group("prey").is_empty():
				_main._spawn_herds()
			var g = null
			for n in get_nodes_in_group("prey"):
				if n.species == "ZEBRA":
					g = n
					break
			g.die()
			_main._spawn_hyenas(g, 3)
			for h in get_nodes_in_group("hyena"):
				var a := randf() * TAU
				h.global_position = g.global_position + Vector3(cos(a), 0.4, sin(a)) * 8.0
			_place_cam(p, g.global_position + Vector3(3, 0, 3), g.global_position, -0.25, 0.6)
			p.state = p.State.EATING
			p.eat_target = g
		_:
			_rival = null
			var c: Vector3 = _herd_center(s[2])
			var dist := 13.0 if s[2] != "BUFFALO" else 22.0
			_place_cam(p, c + Vector3(0.5, 0, 1).normalized() * dist, c, -0.18, 0.4)
			if s[0] == "dusk_stalk":
				p.stalking = true
