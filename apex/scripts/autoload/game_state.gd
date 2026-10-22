extends Node
## Run state for one lion's life, plus the trait (upgrade) system and input setup.

signal hunger_changed(value: float)
signal message(text: String)
signal kill_made(total: int)

enum Phase { TITLE, HUNTING, NIGHT, GAME_OVER, VICTORY }
## NOMAD: alone. CHALLENGE: the day you fight for a pride. PRIDE: you lead it.
enum Act { NOMAD, CHALLENGE, PRIDE }

var phase: Phase = Phase.TITLE
var act: Act = Act.NOMAD
var day := 1
var day_time := 0.0          # seconds into the current day
var hunger := 0.0
var strength := 1.0
var kills := 0
var kills_today := 0
var rivals_beaten := 0
var pride_food := 0.0        # food the lionesses ate today
var lionesses := 0           # how many still follow you
var pride_since_day := 0     # the day you took the pride
var injured := false         # thrown or pinned badly: weaker charge until you sleep
var traits: Array[String] = []
var practice := ""            # "" = the full game, else a practice room (see main.PRACTICE)
var menu_index := 0           # last title-menu choice, kept across restarts

## Trait definitions. "mods" multiply values looked up through mod().
const TRAITS := {
	"thick_mane":  {"name": "Thick Mane",   "desc": "Take 20% less damage from lions.",            "mods": {"damage_taken": 0.8}},
	"heavy_paws":  {"name": "Heavy Paws",   "desc": "Swipes hit 35% harder.",                      "mods": {"swipe_damage": 1.35}},
	"crushing_jaws": {"name": "Crushing Jaws", "desc": "Grapple as if 25% stronger against prey. Lunges hit 30% harder.", "mods": {"lunge_damage": 1.3, "takedown": 1.25}},
	"wrestler":    {"name": "Wrestler",     "desc": "Clinch as if 25% stronger against lions.", "mods": {"clinch": 1.25}},
	"long_charge": {"name": "Long Charge",  "desc": "Your burst lasts 40% longer.",                "mods": {"charge_time": 1.4}},
	"deep_lungs":  {"name": "Deep Lungs",   "desc": "Run 50% longer before you're winded.",        "mods": {"run_time": 1.5}},
	"silent_paws": {"name": "Silent Paws",  "desc": "Stalking is 40% harder to notice.",           "mods": {"stalk_noise": 0.6}},
	"downwind":    {"name": "Downwind",     "desc": "Your scent carries half as strongly.",        "mods": {"scent": 0.5}},
	"iron_gut":    {"name": "Iron Gut",     "desc": "Hunger drains 25% slower.",                   "mods": {"hunger_drain": 0.75}},
	"gorger":      {"name": "Gorger",       "desc": "Eat 50% faster. Meals build 25% more strength.", "mods": {"eat_rate": 1.5, "strength_gain": 1.25}},
	"thunder":     {"name": "Thunder Roar", "desc": "Roar reaches 50% further and recharges faster.", "mods": {"roar_radius": 1.5, "roar_cd": 0.6}},
	"quick_feet":  {"name": "Quick Feet",   "desc": "Dodge recharges 40% faster.",                 "mods": {"dodge_cd": 0.6}},
	"tough_hide":  {"name": "Tough Hide",   "desc": "Kicks, horns and hyena bites hurt 40% less.", "mods": {"beast_damage": 0.6}},
	"fast_healer": {"name": "Fast Healer",  "desc": "Heal 60% faster, day and night.",             "mods": {"health_regen": 1.6}},
}


func _ready() -> void:
	_setup_input()


## Product of every owned trait's multiplier for `key` (1.0 if none).
func mod(key: String) -> float:
	var m := 1.0
	for t in traits:
		m *= TRAITS[t]["mods"].get(key, 1.0)
	return m


func new_run() -> void:
	day = 1
	act = Act.NOMAD
	day_time = 0.0
	hunger = Tuning.HUNGER_START
	strength = Tuning.STRENGTH_START
	kills = 0
	kills_today = 0
	rivals_beaten = 0
	pride_food = 0.0
	lionesses = 0
	pride_since_day = 0
	injured = false
	traits.clear()
	phase = Phase.HUNTING
	hunger_changed.emit(hunger)


func challenge_day() -> int:
	return Tuning.NOMAD_DAYS + 1


func last_day() -> int:
	return challenge_day() + Tuning.PRIDE_DAYS


func add_hunger(amount: float) -> void:
	hunger = clampf(hunger + amount, 0.0, Tuning.HUNGER_MAX)
	hunger_changed.emit(hunger)


func add_strength(amount: float) -> void:
	strength = clampf(strength + amount, 0.1, Tuning.STRENGTH_MAX)


## Food eaten by the player: feeds you and builds strength.
func eat(amount: float) -> void:
	add_hunger(amount)
	add_strength(amount * Tuning.STRENGTH_PER_FOOD * mod("strength_gain"))


## Eating past full: no hunger, but all of it becomes strength.
func gorge(amount: float) -> void:
	add_strength(amount * Tuning.STRENGTH_PER_FOOD * mod("strength_gain"))


func register_kill(species_name: String) -> void:
	kills += 1
	kills_today += 1
	kill_made.emit(kills)
	message.emit("%s down!" % species_name)


## 0 = pale young mane, 1 = the darkest mane strength allows.
func mane_darkness() -> float:
	return clampf((strength - Tuning.STRENGTH_START) / maxf(0.01, Tuning.STRENGTH_MAX - Tuning.STRENGTH_START), 0.0, 1.0)


## Three random traits the player doesn't own yet.
func roll_trait_choices() -> Array[String]:
	var pool: Array[String] = []
	for k in TRAITS.keys():
		if not traits.has(k):
			pool.append(k)
	pool.shuffle()
	return pool.slice(0, mini(3, pool.size()))


func _setup_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("sprint", [KEY_SHIFT])
	_bind("clamp", [KEY_SHIFT])
	_bind("stalk", [KEY_CTRL, KEY_C])
	_bind("pounce", [KEY_SPACE])
	_bind("swipe", [KEY_F])
	_bind("dodge", [KEY_ALT, KEY_V])
	_bind("roar", [KEY_Q])
	_bind("eat", [KEY_E])
	_bind("restart", [KEY_R])
	_bind("pause", [KEY_ESCAPE])
	_bind("tuning", [KEY_F1])
	_bind("choice_1", [KEY_1])
	_bind("choice_2", [KEY_2])
	_bind("choice_3", [KEY_3])
	_bind("start", [KEY_ENTER, KEY_SPACE])
	_bind_mouse("swipe", MOUSE_BUTTON_LEFT)
	_bind_mouse("dodge", MOUSE_BUTTON_RIGHT)
	_bind_mouse("clamp", MOUSE_BUTTON_LEFT)

	# Controller (Xbox names; PlayStation is the same positions).
	# Left stick move, right stick look, RT sprint (and clamp while riding), LT stalk, A pounce,
	# X swipe, B dodge (and let go while riding), Y roar, RB eat, Start pause / restart,
	# Back restart (menu), D-pad left/up/right = night choices.
	_bind_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_bind_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_bind_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_bind_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_bind_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_bind_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_bind_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_bind_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_bind_axis("sprint", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_bind_axis("clamp", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_bind_axis("stalk", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_bind_joy("pounce", JOY_BUTTON_A)
	_bind_joy("swipe", JOY_BUTTON_X)
	_bind_joy("dodge", JOY_BUTTON_B)
	_bind_joy("roar", JOY_BUTTON_Y)
	_bind_joy("eat", JOY_BUTTON_RIGHT_SHOULDER)
	_bind_joy("pause", JOY_BUTTON_START)
	_bind_joy("restart", JOY_BUTTON_START)
	_bind_joy("restart", JOY_BUTTON_BACK)
	_bind_joy("start", JOY_BUTTON_A)
	_bind_joy("start", JOY_BUTTON_START)
	_bind_joy("choice_1", JOY_BUTTON_DPAD_LEFT)
	_bind_joy("choice_2", JOY_BUTTON_DPAD_UP)
	_bind_joy("choice_3", JOY_BUTTON_DPAD_RIGHT)


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _bind_joy(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _bind_axis(action: String, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _bind_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var mb := InputEventMouseButton.new()
	mb.button_index = button
	InputMap.action_add_event(action, mb)
