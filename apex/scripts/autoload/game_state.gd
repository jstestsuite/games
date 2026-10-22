extends Node
## Run state for one season, plus the trait (upgrade) system and input setup.

signal hunger_changed(value: float)
signal message(text: String)
signal kill_made(total: int)

enum Phase { TITLE, HUNTING, NIGHT, GAME_OVER, VICTORY }

var phase: Phase = Phase.TITLE
var day := 1
var day_time := 0.0          # seconds into the current day
var hunger := 0.0
var kills := 0
var kills_today := 0
var traits: Array[String] = []

## Trait definitions. "mods" multiply Tuning values looked up through mod().
const TRAITS := {
	"long_lungs":   {"name": "Long Lungs",    "desc": "+35% sprint stamina.",                   "mods": {"stamina": 1.35}},
	"silent_paws":  {"name": "Silent Paws",   "desc": "Stalking is 40% harder to notice.",      "mods": {"stalk_noise": 0.6}},
	"coiled":       {"name": "Coiled Spring", "desc": "Pounce reaches 40% further.",            "mods": {"pounce_range": 1.4}},
	"iron_gut":     {"name": "Iron Gut",      "desc": "Hunger drains 25% slower.",              "mods": {"hunger_drain": 0.75}},
	"burst":        {"name": "Burst",         "desc": "+8% top sprint speed.",                  "mods": {"sprint_speed": 1.08}},
	"tight_turns":  {"name": "Tight Turns",   "desc": "Turn 40% sharper while sprinting.",      "mods": {"sprint_turn": 1.4}},
	"second_wind":  {"name": "Second Wind",   "desc": "Rest and kills restore 50% more stamina.", "mods": {"stamina_regen": 1.5}},
	"downwind":     {"name": "Downwind",      "desc": "Your scent carries half as strongly.",   "mods": {"scent": 0.5}},
	"big_stomach":  {"name": "Big Stomach",   "desc": "Each kill feeds you 30% more.",          "mods": {"food": 1.3}},
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
	day_time = 0.0
	hunger = Tuning.HUNGER_START
	kills = 0
	kills_today = 0
	traits.clear()
	phase = Phase.HUNTING
	hunger_changed.emit(hunger)


func add_hunger(amount: float) -> void:
	hunger = clampf(hunger + amount, 0.0, Tuning.HUNGER_MAX)
	hunger_changed.emit(hunger)


func register_kill() -> void:
	kills += 1
	kills_today += 1
	add_hunger(Tuning.GAZELLE_FOOD * mod("food"))
	kill_made.emit(kills)
	message.emit("Kill! +%d food" % int(Tuning.GAZELLE_FOOD * mod("food")))


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
	_bind("stalk", [KEY_CTRL, KEY_C])
	_bind("pounce", [KEY_SPACE])
	_bind("restart", [KEY_R])
	_bind("pause", [KEY_ESCAPE])
	_bind("choice_1", [KEY_1])
	_bind("choice_2", [KEY_2])
	_bind("choice_3", [KEY_3])
	_bind("start", [KEY_ENTER, KEY_SPACE])
	# Mouse: left click also pounces.
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("pounce", mb)


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
