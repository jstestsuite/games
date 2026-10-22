extends Node3D
## Top-level game flow: builds the world, runs the day loop and the three acts
## (NOMAD -> CHALLENGE -> PRIDE), spawns herds, rivals, the pride and hyenas,
## moves the sun, and wires the HUD. Gameplay numbers live in Tuning.

const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const TUNING_PANEL := preload("res://scripts/ui/tuning_panel.gd")
const SPECIES := ["WARTHOG", "ZEBRA", "WILDEBEEST", "BUFFALO"]
## The title menu: the full game, then practice rooms (a debug tool: one animal at a
## time near you, a fresh one after each ride, no day, hunger or hyenas).
const PRACTICE := [
	["Full game", ""],
	["Practice: slow zebra", "ZEBRA_SLOW"],
	["Practice: zebra", "ZEBRA"],
	["Practice: warthog", "WARTHOG"],
	["Practice: wildebeest", "WILDEBEEST"],
	["Practice: buffalo", "BUFFALO"],
]

var terrain: Terrain
var player: Lion
var hud: Hud
var tuning_panel: CanvasLayer
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var herds: Array[Herd] = []
var wind := Vector2(1, 0)
var rng := RandomNumberGenerator.new()
var den := Vector3.ZERO
var den_label: Label3D
var pride_male: Rival
var challengers: Array[Rival] = []
var cubs: Array[AnimalRig] = []
var _challengers_sent := false
var _male_forced := false
var _title_orbit := 0.0
var _practice_prey: Prey
var _practice_wait := 0.0
var _ride_log: Array[String] = []
var _rides := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_build_environment()

	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.generate(rng.randi())

	var start := terrain.random_open_point(60.0)
	den = _far_point_from(start, 90.0)
	_build_den()

	player = Lion.new()
	player.name = "Lion"
	player.terrain = terrain
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.global_position = start + Vector3(0, 1.0, 0)
	player.controls_enabled = false
	player.roared.connect(_on_roar)
	player.died.connect(_on_player_died)
	player.ride_ended.connect(_on_ride_ended)

	hud = HUD_SCRIPT.new()
	hud.name = "HUD"
	add_child(hud)
	hud.trait_chosen.connect(_on_trait_chosen)
	hud.start_pressed.connect(_start_run)
	hud.main = self

	tuning_panel = TUNING_PANEL.new()
	tuning_panel.name = "TuningPanel"
	add_child(tuning_panel)
	tuning_panel.restart_requested.connect(_restart)

	_new_wind()
	_spawn_herds()
	_set_sun(0.15)
	hud.show_title(_menu_names(), GameState.menu_index)
	GameState.phase = GameState.Phase.TITLE


func _unhandled_input(event: InputEvent) -> void:
	match GameState.phase:
		GameState.Phase.TITLE:
			var step := 0
			if event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
				step = -1
			elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
				step = 1
			if step != 0:
				GameState.menu_index = wrapi(GameState.menu_index + step, 0, PRACTICE.size())
				hud.show_title(_menu_names(), GameState.menu_index)
			elif event.is_action_pressed("start") or (event is InputEventMouseButton and event.pressed):
				_start_run()
		GameState.Phase.GAME_OVER, GameState.Phase.VICTORY:
			if event.is_action_pressed("restart"):
				_restart()
		GameState.Phase.NIGHT:
			for i in 3:
				if event.is_action_pressed("choice_%d" % (i + 1)):
					hud.pick_trait(i)
		GameState.Phase.HUNTING:
			if event.is_action_pressed("pause"):
				_toggle_pause()
			elif event.is_action_pressed("restart") and (get_tree().paused or GameState.practice != ""):
				_restart()   # back to the menu
			elif event is InputEventMouseButton and event.pressed and get_tree().paused:
				_toggle_pause()


func _restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED
	hud.set_paused(p)


func _menu_names() -> Array:
	return PRACTICE.map(func(e): return e[0])


func _start_run() -> void:
	if GameState.phase != GameState.Phase.TITLE:
		return
	GameState.practice = PRACTICE[GameState.menu_index][1]
	if GameState.practice != "":
		_start_practice()
		return
	GameState.new_run()
	player.strength = GameState.strength
	player.health = player.health_max()
	player.wake()
	hud.hide_overlays()
	player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_start_day()


func _process(delta: float) -> void:
	hud.update_from(player, wind)
	_animate_cubs(delta)
	match GameState.phase:
		GameState.Phase.TITLE:
			# Slow cinematic orbit while the title is up.
			_title_orbit += delta * 0.08
			player._cam_yaw = _title_orbit
		GameState.Phase.HUNTING:
			if get_tree().paused:
				return
			if GameState.practice != "":
				_tick_practice(delta)
			else:
				_tick_day(delta)


func _tick_day(delta: float) -> void:
	if not (Tuning.PAUSE_DAY_IN_FIGHTS and lion_fight_on()):
		GameState.day_time = minf(GameState.day_time + delta, Tuning.DAY_LENGTH)
	var drain := Tuning.HUNGER_DRAIN
	if player.sprinting:
		drain += Tuning.HUNGER_DRAIN_RUN
	GameState.add_hunger(-drain * GameState.mod("hunger_drain") * delta)
	if GameState.hunger <= 0.0:
		player.starve(Tuning.STARVE_DAMAGE * delta)
	_set_sun(GameState.day_time / Tuning.DAY_LENGTH)
	if GameState.phase != GameState.Phase.HUNTING:
		return
	if GameState.day_time >= Tuning.DAY_LENGTH:
		_dusk()


## The day is over: but some fights happen at dusk before you get to sleep.
func _dusk() -> void:
	if GameState.act == GameState.Act.CHALLENGE and is_instance_valid(pride_male):
		if not _male_forced:
			_male_forced = true
			pride_male.forced = true
			pride_male.can_disengage = false
			pride_male.wanders = false
			GameState.message.emit("Dusk. The pride male comes for you.")
		return
	if GameState.day >= GameState.last_day() and GameState.act == GameState.Act.PRIDE:
		if not _challengers_sent:
			_challengers_sent = true
			_send_challengers()
			return
		return   # victory comes when the last challenger yields
	_end_day()


func lion_fight_on() -> bool:
	for n in get_tree().get_nodes_in_group("rival"):
		var r := n as Rival
		if r and r.in_fight():
			return true
	return false


## The rival that matters right now (for the HUD): fighting you, else the closest.
func focus_rival() -> Rival:
	var best: Rival = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("rival"):
		var r := n as Rival
		if r == null or r.rstate == Rival.RState.YIELD:
			continue
		var d := r.global_position.distance_to(player.global_position)
		if r.in_fight():
			d -= 1000.0
		if d < best_d and d < 40.0:
			best_d = d
			best = r
	return best


func _start_day() -> void:
	GameState.day_time = 0.0
	GameState.kills_today = 0
	GameState.pride_food = 0.0
	_male_forced = false
	_challengers_sent = false
	challengers.clear()
	_new_wind()
	_clear_actors()
	_spawn_herds()
	_spawn_roamers()
	var cd := GameState.challenge_day()
	if GameState.day < cd:
		GameState.act = GameState.Act.NOMAD
		if GameState.day > 1 and rng.randf() < Tuning.NOMAD_RIVAL_CHANCE:
			_spawn_nomad()
		var left := cd - GameState.day
		GameState.message.emit("Day %d. Eat. Grow strong. %d day%s until the challenge." % [
			GameState.day, left, "" if left == 1 else "s"])
	elif GameState.day == cd:
		GameState.act = GameState.Act.CHALLENGE
		_spawn_pride_at_den()
		GameState.message.emit("Challenge day. Take the pride from its male at the rocks.")
	else:
		GameState.act = GameState.Act.PRIDE
		_spawn_cubs()
		_spawn_following_lionesses()
		if GameState.day >= GameState.last_day():
			GameState.message.emit("Day %d. Feed the pride. Challengers come at dusk." % GameState.day)
		else:
			GameState.message.emit("Day %d. Feed the pride." % GameState.day)
	den_label.visible = GameState.act == GameState.Act.CHALLENGE


func _end_day() -> void:
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.add_hunger(-Tuning.HUNGER_NIGHT_COST * GameState.mod("hunger_drain"))
	var report: Array[String] = []
	if GameState.hunger <= 0.0:
		report.append("You went to sleep starving.")
	# The pride's daily meal only counts on days you led it from the start.
	if GameState.act == GameState.Act.PRIDE and GameState.lionesses > 0 \
			and GameState.day > GameState.pride_since_day:
		if GameState.pride_food < Tuning.PRIDE_FOOD_NEED:
			GameState.lionesses -= 1
			report.append("The pride went hungry (%d / %d food). A lioness left." % [
				int(GameState.pride_food), int(Tuning.PRIDE_FOOD_NEED)])
		else:
			report.append("The pride ate well (%d / %d food)." % [
				int(GameState.pride_food), int(Tuning.PRIDE_FOOD_NEED)])
	GameState.phase = GameState.Phase.NIGHT
	hud.show_night(GameState.day, GameState.kills_today, report, GameState.roll_trait_choices())


func _on_trait_chosen(trait_id: String) -> void:
	GameState.traits.append(trait_id)
	GameState.day += 1
	GameState.injured = false   # a night's sleep heals the limp
	GameState.phase = GameState.Phase.HUNTING
	hud.hide_overlays()
	player.wake()
	player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_start_day()
	GameState.message.emit("%s acquired." % GameState.TRAITS[trait_id]["name"])


func _on_player_died() -> void:
	if GameState.phase != GameState.Phase.HUNTING:
		return
	var cause := player.last_hurt_by
	var text: String
	match cause:
		"a rival lion":
			text = "You lost the fight on day %d." % GameState.day
		"hunger":
			text = "You starved on day %d." % GameState.day
		"hyenas":
			text = "The hyenas brought you down on day %d." % GameState.day
		_:
			text = "You died on day %d (%s)." % [GameState.day, cause]
	get_tree().create_timer(1.6).timeout.connect(_game_over.bind(text))


func _game_over(reason: String) -> void:
	if GameState.phase != GameState.Phase.HUNTING:
		return
	GameState.phase = GameState.Phase.GAME_OVER
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_end(false, "%s\n%d kills · strength %.2f · %d rivals beaten." % [
		reason, GameState.kills, GameState.strength, GameState.rivals_beaten])


func _victory() -> void:
	GameState.phase = GameState.Phase.VICTORY
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_end(true, "The challengers fled. Your cubs will grow up.\n%d kills · strength %.2f · %d lioness%s · %d rivals beaten." % [
		GameState.kills, GameState.strength, GameState.lionesses,
		"" if GameState.lionesses == 1 else "es", GameState.rivals_beaten])


# --- rivals and the pride ---------------------------------------------------------

func _make_rival(title: String, str_value: float, at: Vector3) -> Rival:
	var r := Rival.new()
	r.terrain = terrain
	r.player = player
	r.strength = str_value
	r.title = title
	r.home = at
	r.process_mode = Node.PROCESS_MODE_PAUSABLE
	r.add_to_group("day_actor")
	add_child(r)
	r.global_position = Vector3(at.x, terrain.height_at(at.x, at.z) + 0.5, at.z)
	r.heading = rng.randf() * TAU
	r.yielded.connect(_on_rival_yielded)
	return r


func _spawn_nomad() -> void:
	var at := _far_point_from(player.global_position, 70.0)
	var s := Tuning.NOMAD_RIVAL_STRENGTH + Tuning.NOMAD_RIVAL_STRENGTH_PER_DAY * (GameState.day - 1)
	var r := _make_rival("Nomad", s, at)
	r.wanders = true


func _spawn_pride_at_den() -> void:
	pride_male = _make_rival("Pride male", Tuning.PRIDE_MALE_STRENGTH, den)
	pride_male.can_disengage = true
	for i in Tuning.LIONESS_COUNT:
		var l := _make_lioness(i, den + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)))
		l.lstate = Lioness.LState.DEN
	_spawn_cubs()


func _make_lioness(i: int, at: Vector3) -> Lioness:
	var l := Lioness.new()
	l.terrain = terrain
	l.player = player
	l.den = den
	l.slot = i
	l.process_mode = Node.PROCESS_MODE_PAUSABLE
	l.add_to_group("day_actor")
	add_child(l)
	l.global_position = Vector3(at.x, terrain.height_at(at.x, at.z) + 0.5, at.z)
	l.heading = rng.randf() * TAU
	return l


func _spawn_following_lionesses() -> void:
	for i in GameState.lionesses:
		var a := rng.randf() * TAU
		var at := player.global_position + Vector3(cos(a), 0, sin(a)) * 6.0
		_make_lioness(i, at).join()


func _send_challengers() -> void:
	var n := Tuning.CHALLENGER_COUNT
	if GameState.lionesses > 0 and GameState.pride_food >= Tuning.PRIDE_FOOD_NEED and n > 1:
		# A well-fed pride stands with you.
		n -= 1
		GameState.message.emit("Dusk. Challengers come, but your well-fed lionesses drive one off!")
	else:
		GameState.message.emit("Dusk. Challengers have come for your pride!")
	for i in n:
		var a := rng.randf() * TAU
		var at := player.global_position + Vector3(cos(a), 0, sin(a)) * 32.0
		at.x = clampf(at.x, -Tuning.WORLD_SIZE * 0.4, Tuning.WORLD_SIZE * 0.4)
		at.z = clampf(at.z, -Tuning.WORLD_SIZE * 0.4, Tuning.WORLD_SIZE * 0.4)
		var r := _make_rival("Challenger" if n == 1 else "Challenger %d" % (i + 1), Tuning.CHALLENGER_STRENGTH, at)
		r.can_disengage = false
		r.forced = Tuning.CHALLENGERS_TOGETHER or i == 0
		if not r.forced:
			r.rstate = Rival.RState.WAIT
		challengers.append(r)


func _on_rival_yielded(r: Rival) -> void:
	GameState.rivals_beaten += 1
	if r == pride_male:
		pride_male = null
		GameState.act = GameState.Act.PRIDE
		den_label.visible = false
		var n := 0
		for l in get_tree().get_nodes_in_group("lioness"):
			(l as Lioness).join()
			n += 1
		GameState.lionesses = n
		GameState.pride_since_day = GameState.day
		GameState.message.emit("The pride is yours.")
		# If this was the dusk fight, give it a moment to sink in before night falls.
		GameState.day_time = minf(GameState.day_time, Tuning.DAY_LENGTH - 3.0)
	elif challengers.has(r):
		challengers.erase(r)
		if challengers.size() > 0:
			challengers[0].forced = true
			challengers[0].engage()
			GameState.message.emit("Another challenger steps up.")
		else:
			get_tree().create_timer(2.0).timeout.connect(_victory_if_hunting)
	else:
		GameState.add_strength(Tuning.RIVAL_WIN_STRENGTH)
		GameState.message.emit("%s runs off. You feel stronger." % r.title)


func _victory_if_hunting() -> void:
	if GameState.phase == GameState.Phase.HUNTING and not player.is_dead:
		_victory()


# --- practice rooms ------------------------------------------------------------------

func _start_practice() -> void:
	GameState.new_run()
	GameState.day_time = Tuning.DAY_LENGTH * 0.35
	_set_sun(0.35)
	player.practice = true
	player.strength = GameState.strength
	player.wake()
	player.health = player.health_max()
	hud.hide_overlays()
	player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_clear_actors()
	_ride_log.clear()
	_rides = 0
	hud.set_ride_log(_ride_log)
	_spawn_practice_prey()
	GameState.message.emit("%s. Chase it down, pounce, and ride it." % PRACTICE[GameState.menu_index][0])


func _tick_practice(delta: float) -> void:
	GameState.hunger = Tuning.HUNGER_MAX
	GameState.injured = false
	if player.state == Lion.State.RIDE:
		return
	var gone := not is_instance_valid(_practice_prey) or _practice_prey.is_dead \
			or _practice_prey.global_position.distance_to(player.global_position) > 90.0
	if not gone:
		_practice_wait = 1.5
		return
	_practice_wait -= delta
	if _practice_wait <= 0.0:
		_spawn_practice_prey()


## A fresh animal 16 m ahead of you, grazing, facing away. Clears the last one.
func _spawn_practice_prey() -> void:
	for group in ["prey", "carcass"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	if player.state == Lion.State.RIDE:
		return
	player.health = player.health_max()
	var key: String = GameState.practice
	var g := Prey.new()
	g.species = key.trim_suffix("_SLOW")
	g.terrain = terrain
	g.wind = wind
	g.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(g)
	g.weak = false
	g._size = 1.0
	if key.ends_with("_SLOW"):
		g.practice_slow = Tuning.PRACTICE_SLOW
	var fwd := Vector3(-sin(player._cam_yaw), 0, -cos(player._cam_yaw))
	var at := player.global_position + fwd * 16.0
	var half := Tuning.WORLD_SIZE * 0.5 - 60.0
	at.x = clampf(at.x, -half, half)
	at.z = clampf(at.z, -half, half)
	g.global_position = Vector3(at.x, terrain.height_at(at.x, at.z) + 0.3, at.z)
	g.heading = atan2(-fwd.x, -fwd.z)
	g._wander_target = g.global_position
	_practice_prey = g
	_practice_wait = 1.5


func _on_ride_ended(info: Dictionary) -> void:
	_rides += 1
	var line := "%d. %s %s in %.1f s  ·  steady %d%%  ·  reaction %+.2f s over %d cuts" % [
		_rides, info.species, info.result, info.time, int(info.steady * 100.0), info.react, info.cuts]
	print("RIDE ", line)
	if GameState.practice == "":
		return
	_ride_log.push_front(line)
	if _ride_log.size() > 8:
		_ride_log.resize(8)
	hud.set_ride_log(_ride_log)


# --- spawning ---------------------------------------------------------------------

func _clear_actors() -> void:
	for group in ["prey", "carcass", "hyena", "day_actor"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	herds.clear()
	pride_male = null


func _spawn_herds() -> void:
	for node in get_tree().get_nodes_in_group("prey"):
		node.queue_free()
	herds.clear()
	for sp in SPECIES:
		var count := int(Tuning.get(sp + "_HERDS"))
		for h in count:
			var center := terrain.random_open_point(35.0)
			var tries := 0
			while (center.distance_to(player.global_position) < 70.0 or center.distance_to(den) < 30.0) and tries < 30:
				center = terrain.random_open_point(35.0)
				tries += 1
			var herd := Herd.new()
			herd.center = center
			herds.append(herd)
			var lo := int(Tuning.get(sp + "_HERD_MIN"))
			var hi := maxi(lo, int(Tuning.get(sp + "_HERD_MAX")))
			for i in rng.randi_range(lo, hi):
				var g := Prey.new()
				g.species = sp
				g.herd = herd
				g.terrain = terrain
				g.wind = wind
				g.process_mode = Node.PROCESS_MODE_PAUSABLE
				g.became_carcass.connect(_on_carcass)
				add_child(g)
				var off := Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-7, 7))
				var p := center + off
				g.global_position = Vector3(p.x, terrain.height_at(p.x, p.z) + 0.3, p.z)
				herd.members.append(g)


func _on_carcass(c: Prey) -> void:
	# The clan was watching: roamers nearby head straight for it.
	for n in get_tree().get_nodes_in_group("hyena"):
		var h := n as Hyena
		if h and h.roamer and h.carcass == null and h.global_position.distance_to(c.global_position) < Tuning.HYENA_NOTICE_RANGE:
			h.go_to_carcass(c)
	if rng.randf() > Tuning.HYENA_CHANCE:
		return
	var n := Tuning.HYENA_BASE + int(Tuning.HYENA_PER_DAY * (GameState.day - 1))
	if n <= 0:
		return
	# Bind the id, not the node: the carcass may be gone by the time they arrive.
	var cid := c.get_instance_id()
	get_tree().create_timer(Tuning.HYENA_ARRIVE_DELAY, false).timeout.connect(
		func(): _spawn_hyenas(instance_from_id(cid) as Prey, n))


## The day's clan: they shadow you from a distance and come for anything you kill.
func _spawn_roamers() -> void:
	var n := Tuning.HYENA_ROAMERS + int(Tuning.HYENA_ROAMERS_PER_DAY * (GameState.day - 1))
	if n <= 0:
		return
	var a := rng.randf() * TAU
	for i in n:
		var h := Hyena.new()
		h.roamer = true
		h.hstate = Hyena.HState.ROAM
		h.player = player
		h.terrain = terrain
		h.pack_size = n
		h.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(h)
		var p := player.global_position + Vector3(cos(a + i * 0.4), 0, sin(a + i * 0.4)) * 60.0
		p.x = clampf(p.x, -Tuning.WORLD_SIZE * 0.42, Tuning.WORLD_SIZE * 0.42)
		p.z = clampf(p.z, -Tuning.WORLD_SIZE * 0.42, Tuning.WORLD_SIZE * 0.42)
		h.global_position = Vector3(p.x, terrain.height_at(p.x, p.z) + 0.4, p.z)
		h._orbit = a + i * 0.4


func _spawn_hyenas(c: Prey, n: int) -> void:
	if not is_instance_valid(c) or c.food_left <= 0.0 or GameState.phase != GameState.Phase.HUNTING:
		return
	var a := rng.randf() * TAU
	for i in n:
		var h := Hyena.new()
		h.carcass = c
		h.player = player
		h.terrain = terrain
		h.pack_size = n
		h.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(h)
		var p := c.global_position + Vector3(cos(a + i * 0.3), 0, sin(a + i * 0.3)) * 55.0
		p.x = clampf(p.x, -Tuning.WORLD_SIZE * 0.42, Tuning.WORLD_SIZE * 0.42)
		p.z = clampf(p.z, -Tuning.WORLD_SIZE * 0.42, Tuning.WORLD_SIZE * 0.42)
		h.global_position = Vector3(p.x, terrain.height_at(p.x, p.z) + 0.4, p.z)
	GameState.message.emit("Hyenas are coming.")


func _on_roar(at: Vector3, radius: float) -> void:
	if GameState.practice != "":
		_spawn_practice_prey()   # in practice, roar = a fresh animal
		return
	GameState.message.emit("ROAR")
	for n in get_tree().get_nodes_in_group("hyena"):
		var h := n as Hyena
		if h and h.global_position.distance_to(at) < radius:
			h.scare()
	for n in get_tree().get_nodes_in_group("prey"):
		var g := n as Prey
		if g and g.global_position.distance_to(at) < Tuning.ROAR_PREY_ALERT:
			g.awareness = Tuning.FLEE_THRESHOLD
			g.spook(rng.randf_range(0.1, 0.5))


func _new_wind() -> void:
	var a := rng.randf() * TAU
	wind = Vector2(cos(a), sin(a))
	terrain.set_wind(wind)
	for node in get_tree().get_nodes_in_group("prey"):
		(node as Prey).wind = wind


func _far_point_from(from: Vector3, min_dist: float) -> Vector3:
	var p := terrain.random_open_point(40.0)
	for i in 40:
		if p.distance_to(from) >= min_dist:
			break
		p = terrain.random_open_point(40.0)
	return p


# --- the den ---------------------------------------------------------------------

## A kopje: a pile of big boulders where the pride rests.
func _build_den() -> void:
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.55, 0.5, 0.45)
	rock.roughness = 0.95
	var body := StaticBody3D.new()
	body.name = "Den"
	add_child(body)
	for i in 6:
		var a := float(i) / 6.0 * TAU + rng.randf_range(-0.3, 0.3)
		var r := rng.randf_range(1.6, 3.0)
		var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(7.0, 10.0)
		if i == 0:
			off = Vector3.ZERO
			r = 3.4
		var p := den + off
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 1.6
		mi.mesh = sm
		mi.material_override = rock
		mi.position = Vector3(p.x, terrain.height_at(p.x, p.z) + r * 0.25, p.z)
		mi.rotation.y = rng.randf() * TAU
		body.add_child(mi)
		var col := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = r * 0.8
		col.shape = sh
		col.position = mi.position
		body.add_child(col)
		terrain.obstacles.append(Vector3(p.x, p.z, sh.radius))
	den_label = Label3D.new()
	den_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	den_label.no_depth_test = true
	den_label.fixed_size = true
	den_label.pixel_size = 0.0014
	den_label.font_size = 44
	den_label.outline_size = 12
	den_label.modulate = Color(1.0, 0.82, 0.35)
	den_label.text = "THE PRIDE"
	den_label.position = den + Vector3(0, terrain.height_at(den.x, den.z) + 8.0, 0)
	den_label.visible = false
	add_child(den_label)


func _spawn_cubs() -> void:
	for c in cubs:
		if is_instance_valid(c):
			c.queue_free()
	cubs.clear()
	for i in Tuning.CUB_COUNT:
		var rig := AnimalRig.new()
		add_child(rig)
		rig.build({
			"body_len": 1.55, "body_r": 0.31, "leg_len": 0.8, "leg_r": 0.09,
			"neck_len": 0.3, "neck_r": 0.17, "neck_pitch": -1.0, "head_r": 0.24, "head_len": 0.95,
			"tail_len": 0.8, "tail_tip": true, "ear": 0.9, "stride": 1.5,
			"coat": {"base_color": Color(0.84, 0.7, 0.48), "belly_color": Color(0.93, 0.86, 0.72),
				"spot_color": Color(0.55, 0.42, 0.28), "spot_amount": 0.15, "spot_scale": 8.0,
				"belly_height": -0.1},
		})
		var a := float(i) / maxf(1.0, Tuning.CUB_COUNT) * TAU
		var p := den + Vector3(cos(a), 0, sin(a)) * 5.0
		rig.position = Vector3(p.x, terrain.height_at(p.x, p.z), p.z)
		rig.scale = Vector3.ONE * 0.38
		rig.rotation.y = rng.randf() * TAU
		cubs.append(rig)


func _animate_cubs(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in cubs.size():
		var c := cubs[i]
		if not is_instance_valid(c):
			continue
		var play := sin(t * 0.7 + i * 2.1) > 0.3
		c.rotation.y += (1.2 if play else 0.0) * delta * (1.0 if i % 2 == 0 else -1.0)
		var fwd := -c.global_basis.z.normalized()
		if play:
			c.position += fwd * delta * 0.8
			var to_den := den - c.position
			to_den.y = 0
			if to_den.length() > 7.0:
				c.position += to_den.normalized() * delta * 1.2
			c.position.y = terrain.height_at(c.position.x, c.position.z)
		c.animate(delta, 0.8 if play else 0.0, 0.3 if play else 0.0, 0.0 if play else 0.8, 0.0)


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
