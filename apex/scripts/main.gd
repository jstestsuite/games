extends Node3D
## Top-level game flow: builds the world, runs the day/season loop, spawns herds,
## moves the sun, and wires the HUD. Gameplay numbers live in Tuning.

const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")

var terrain: Terrain
var player: Cheetah
var hud: Hud
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var herds: Array[Herd] = []
var wind := Vector2(1, 0)
var rng := RandomNumberGenerator.new()
var _title_orbit := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_build_environment()

	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.generate(rng.randi())

	player = Cheetah.new()
	player.name = "Cheetah"
	player.terrain = terrain
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	var start := terrain.random_open_point(60.0)
	player.global_position = start + Vector3(0, 1.0, 0)
	player.controls_enabled = false

	hud = HUD_SCRIPT.new()
	hud.name = "HUD"
	add_child(hud)
	hud.trait_chosen.connect(_on_trait_chosen)
	hud.start_pressed.connect(_start_run)

	_new_wind()
	_spawn_herds()
	_set_sun(0.15)
	hud.show_title()
	GameState.phase = GameState.Phase.TITLE


func _unhandled_input(event: InputEvent) -> void:
	match GameState.phase:
		GameState.Phase.TITLE:
			if event.is_action_pressed("start") or (event is InputEventMouseButton and event.pressed):
				_start_run()
		GameState.Phase.GAME_OVER, GameState.Phase.VICTORY:
			if event.is_action_pressed("restart"):
				get_tree().paused = false
				get_tree().reload_current_scene()
		GameState.Phase.NIGHT:
			for i in 3:
				if event.is_action_pressed("choice_%d" % (i + 1)):
					hud.pick_trait(i)
		GameState.Phase.HUNTING:
			if event.is_action_pressed("pause"):
				_toggle_pause()
			elif event is InputEventMouseButton and event.pressed and get_tree().paused:
				_toggle_pause()


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED
	hud.set_paused(p)


func _start_run() -> void:
	if GameState.phase != GameState.Phase.TITLE:
		return
	GameState.new_run()
	hud.hide_overlays()
	player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.message.emit("Day 1. Find a herd. Stay downwind.")


func _process(delta: float) -> void:
	hud.update_from(player, wind)
	match GameState.phase:
		GameState.Phase.TITLE:
			# Slow cinematic orbit while the title is up.
			_title_orbit += delta * 0.08
			player._cam_yaw = _title_orbit
		GameState.Phase.HUNTING:
			if get_tree().paused:
				return
			_tick_day(delta)


func _tick_day(delta: float) -> void:
	GameState.day_time += delta
	var drain := Tuning.HUNGER_DRAIN
	if player.sprinting:
		drain += Tuning.HUNGER_DRAIN_SPRINT
	GameState.add_hunger(-drain * GameState.mod("hunger_drain") * delta)
	_set_sun(GameState.day_time / Tuning.DAY_LENGTH)

	if GameState.hunger <= 0.0:
		_game_over("You starved on day %d." % GameState.day)
	elif GameState.day_time >= Tuning.DAY_LENGTH:
		_end_day()


func _end_day() -> void:
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if GameState.day >= Tuning.DAYS_PER_SEASON:
		GameState.phase = GameState.Phase.VICTORY
		hud.show_end(true, "You survived the season.\n%d kills." % GameState.kills)
		return
	GameState.add_hunger(-Tuning.HUNGER_NIGHT_COST * GameState.mod("hunger_drain"))
	if GameState.hunger <= 0.0:
		_game_over("You starved in the night after day %d." % GameState.day)
		return
	GameState.phase = GameState.Phase.NIGHT
	hud.show_night(GameState.day, GameState.kills_today, GameState.roll_trait_choices())


func _on_trait_chosen(trait_id: String) -> void:
	GameState.traits.append(trait_id)
	GameState.day += 1
	GameState.day_time = 0.0
	GameState.kills_today = 0
	GameState.phase = GameState.Phase.HUNTING
	hud.hide_overlays()
	_new_wind()
	_spawn_herds()
	player.controls_enabled = true
	player.stamina = Tuning.STAMINA_MAX * GameState.mod("stamina")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.message.emit("Day %d. %s" % [GameState.day, GameState.TRAITS[trait_id]["name"] + " acquired."])


func _game_over(reason: String) -> void:
	GameState.phase = GameState.Phase.GAME_OVER
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_end(false, "%s\n%d kills." % [reason, GameState.kills])


# --- spawning ---------------------------------------------------------------------

func _spawn_herds() -> void:
	for node in get_tree().get_nodes_in_group("gazelle_all"):
		node.queue_free()
	herds.clear()
	for h in Tuning.HERDS_PER_DAY:
		var center := terrain.random_open_point(35.0)
		var tries := 0
		while center.distance_to(player.global_position) < 70.0 and tries < 30:
			center = terrain.random_open_point(35.0)
			tries += 1
		var herd := Herd.new()
		herd.center = center
		herds.append(herd)
		var n := rng.randi_range(Tuning.GAZELLES_PER_HERD.x, Tuning.GAZELLES_PER_HERD.y)
		for i in n:
			var g := Gazelle.new()
			g.herd = herd
			g.terrain = terrain
			g.player = player
			g.wind = wind
			g.add_to_group("gazelle_all")
			g.process_mode = Node.PROCESS_MODE_PAUSABLE
			add_child(g)
			var off := Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-7, 7))
			var p := center + off
			g.global_position = Vector3(p.x, terrain.height_at(p.x, p.z) + 0.3, p.z)
			herd.members.append(g)


func _new_wind() -> void:
	var a := rng.randf() * TAU
	wind = Vector2(cos(a), sin(a))
	terrain.set_wind(wind)
	for node in get_tree().get_nodes_in_group("gazelle_all"):
		(node as Gazelle).wind = wind


# --- look ------------------------------------------------------------------------

func _build_environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.35, 0.28, 0.2)
	sky_mat.ground_horizon_color = Color(0.85, 0.66, 0.45)
	sky_mat.sun_angle_max = 18.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.tonemap_white = 4.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.95, 0.78, 0.6)
	env.fog_density = 0.0022
	env.fog_sun_scatter = 0.35
	env.fog_aerial_perspective = 0.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.12

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 1.0
	add_child(sun)


## t: 0 = dawn, 0.5 = noon, 1 = dusk. Golden light at both ends.
func _set_sun(t: float) -> void:
	t = clampf(t, 0.0, 1.0)
	var elevation := deg_to_rad(3.5 + sin(t * PI) * 55.0)
	var azimuth := deg_to_rad(lerpf(80.0, 280.0, t))
	sun.rotation = Vector3(-elevation, azimuth, 0)

	var low := 1.0 - sin(t * PI)        # 1 at dawn/dusk, 0 at noon
	var golden := Color(1.0, 0.62, 0.32)
	var noon := Color(1.0, 0.94, 0.84)
	sun.light_color = noon.lerp(golden, pow(low, 2.5))
	sun.light_energy = lerpf(1.25, 1.2, pow(low, 2.0))

	sky_mat.sky_top_color = Color(0.22, 0.43, 0.78).lerp(Color(0.26, 0.33, 0.58), pow(low, 2.0))
	sky_mat.sky_horizon_color = Color(0.72, 0.80, 0.88).lerp(Color(1.0, 0.62, 0.36), pow(low, 2.5))
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color.darkened(0.1)
	env.fog_light_color = Color(0.80, 0.82, 0.84).lerp(Color(1.0, 0.68, 0.45), pow(low, 2.5))
	env.ambient_light_energy = lerpf(0.8, 0.6, low)
