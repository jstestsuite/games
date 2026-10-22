extends Node
## Every gameplay number lives here so it can be tweaked in one place.
## Traits (see game_state.gd) multiply some of these at runtime via GameState.mod().
##
## Two ways to tune:
##   1. Edit a default below and press F5 in Godot.
##   2. In game, press F1 for the tuning panel. Changes apply live and are saved to
##      user://tuning.cfg, which overrides these defaults until you hit "Reset all".
##      "Copy changes" puts just the values you changed on the clipboard.
## Values marked (new day) only take effect when the next day spawns.

const SAVE_PATH := "user://tuning.cfg"

# --- Run ---------------------------------------------------------------
@export_group("Run")
@export_range(30, 600, 5) var DAY_LENGTH := 150.0         ## seconds of real time per day
@export_range(1, 8, 1) var NOMAD_DAYS := 3                ## days alone before the challenge day
@export_range(0, 5, 1) var PRIDE_DAYS := 1                ## full days holding the pride after the challenge day
@export var PAUSE_DAY_IN_FIGHTS := true                   ## the clock stops while a lion fight is on

# --- World -------------------------------------------------------------
@export_group("World (restart)")
@export_range(128, 512, 16) var WORLD_SIZE := 256.0       ## metres, square
@export_range(32, 256, 16) var TERRAIN_RES := 128         ## quads per side (mesh + collision)
@export_range(0, 30, 0.5) var HILL_HEIGHT := 9.0          ## max rolling-hill height
@export_range(0, 60, 1) var TALL_GRASS_PATCHES := 26
@export_range(0, 120, 1) var TREE_COUNT := 38
@export_range(0, 120, 1) var ROCK_COUNT := 30

# --- Hunger, health, strength --------------------------------------------
@export_group("Hunger")
@export_range(10, 300, 5) var HUNGER_MAX := 100.0
@export_range(0, 300, 5) var HUNGER_START := 70.0
@export_range(0, 3, 0.01) var HUNGER_DRAIN := 0.25        ## per second, always
@export_range(0, 5, 0.05) var HUNGER_DRAIN_RUN := 0.8     ## extra per second while charging or running
@export_range(0, 100, 1) var HUNGER_NIGHT_COST := 20.0    ## paid when sleeping between days
@export_range(0, 20, 0.5) var STARVE_DAMAGE := 2.0        ## health per second lost at 0 hunger

@export_group("Health")
@export_range(10, 400, 5) var HEALTH_MAX := 100.0         ## at strength 1.0
@export_range(0, 2, 0.05) var HEALTH_PER_STRENGTH := 0.6  ## +60% max health per +1.0 strength
@export_range(0, 5, 0.05) var HEALTH_REGEN := 0.5         ## per second, after a few seconds unhurt
@export_range(0, 20, 0.5) var HEALTH_REGEN_DELAY := 6.0
@export_range(0, 100, 1) var HEALTH_NIGHT_HEAL := 30.0    ## restored while sleeping

@export_group("Strength and mane")
@export_range(0.3, 3, 0.05) var STRENGTH_START := 1.0
@export_range(0, 0.02, 0.0005) var STRENGTH_PER_FOOD := 0.003  ## strength gained per point of food eaten
@export_range(1, 5, 0.05) var STRENGTH_MAX := 2.5
@export_range(0, 1, 0.01) var STRENGTH_SIZE := 0.1        ## body scale gained per +1.0 strength
@export_range(0, 1, 0.01) var RIVAL_WIN_STRENGTH := 0.15  ## bonus for beating a nomad rival
@export_range(0, 1, 0.05) var HUNGRY_FIGHT_MULT := 0.75   ## damage dealt when hunger is under 30%
@export_range(0, 3, 0.05) var DAMAGE_STRENGTH_POWER := 1.5 ## damage = base x strength^this (higher = strength matters more)

# --- Lion movement -------------------------------------------------------
@export_group("Lion movement")
@export_range(1, 15, 0.1) var WALK_SPEED := 6.0
@export_range(0.5, 6, 0.1) var STALK_SPEED := 2.4
@export_range(5, 40, 0.5) var CHARGE_SPEED := 22.0        ## top speed during the burst
@export_range(3, 30, 0.5) var RUN_SPEED := 15.0           ## sustained speed once the burst fades
@export_range(0.2, 6, 0.1) var CHARGE_TIME := 2.2         ## seconds of full-speed burst (a full charge)
@export_range(0.1, 4, 0.1) var CHARGE_FADE := 1.2         ## seconds to ease from charge to run speed
@export_range(0.05, 3, 0.05) var CHARGE_RECOVER := 0.35   ## charge seconds regained per second when not sprinting
@export_range(1, 5, 0.1) var CHARGE_RECOVER_IDLE_MULT := 2.0  ## faster recovery standing still or stalking
@export_range(0, 3, 0.05) var CHARGE_MIN_TO_START := 0.4  ## need this much charge to burst; otherwise you just run
@export_range(2, 60, 0.5) var RUN_WINDED_TIME := 12.0     ## continuous sprint seconds before you're winded
@export_range(0, 20, 0.5) var WINDED_TIME := 5.0          ## winded: no sprint for this long
@export_range(1, 60, 0.5) var ACCEL_WALK := 16.0
@export_range(1, 60, 0.5) var ACCEL_SPRINT := 16.0
@export_range(1, 20, 0.1) var TURN_RATE_WALK := 8.0       ## radians/sec
@export_range(0.5, 10, 0.1) var TURN_RATE_SPRINT := 2.4   ## lower = wider turns at speed

# --- Pounce and takedown ---------------------------------------------------
@export_group("Pounce and takedown")
@export_range(5, 50, 0.5) var POUNCE_SPEED := 26.0
@export_range(0.1, 1, 0.01) var POUNCE_DURATION := 0.34
@export_range(0.5, 5, 0.1) var POUNCE_CATCH_RADIUS := 2.4
@export_range(0, 3, 0.05) var POUNCE_COOLDOWN := 0.9
@export_range(0, 20, 0.5) var POUNCE_HOMING := 6.0         ## how hard a pounce curves toward nearby prey
@export_range(0.2, 10, 0.1) var TAKEDOWN_TIME := 1.6       ## seconds to bring down toughness-1 prey at strength 1
@export_range(0, 6, 0.1) var TAKEDOWN_DRAG_SPEED := 1.5  ## m/s a grabbed animal still drags you
@export_range(0.1, 3, 0.05) var KICK_INTERVAL := 0.6       ## seconds between kick attempts while grabbed
@export_range(0, 1, 0.05) var KICK_CHANCE := 0.35
@export_range(0, 2, 0.05) var LIONESS_TAKEDOWN_POWER := 0.8 ## each lioness holding on adds this (lion = strength)
@export_range(0.5, 20, 0.5) var EAT_RATE := 9.0            ## food per second while eating
@export_range(5, 300, 5) var CARCASS_LIFETIME := 90.0      ## seconds before a carcass is gone

# --- Fighting --------------------------------------------------------------
@export_group("Fighting (both sides)")
@export_range(0, 60, 0.5) var SWIPE_DAMAGE := 9.0
@export_range(0.5, 6, 0.1) var SWIPE_RANGE := 2.8
@export_range(10, 180, 5) var SWIPE_ARC := 80.0            ## degrees
@export_range(0.05, 1, 0.01) var SWIPE_TIME := 0.32        ## whole swipe animation
@export_range(0, 1, 0.01) var SWIPE_HIT_AT := 0.14         ## when in the swipe the paw lands
@export_range(0, 2, 0.05) var SWIPE_COOLDOWN := 0.55
@export_range(0, 100, 1) var LUNGE_DAMAGE := 22.0          ## pounce into a lion or hyena
@export_range(5, 30, 0.5) var DODGE_SPEED := 13.0
@export_range(0.05, 1, 0.01) var DODGE_TIME := 0.28        ## you can't be hit while dodging
@export_range(0, 3, 0.05) var DODGE_COOLDOWN := 0.6
@export_range(0, 2, 0.05) var STAGGER_TIME := 0.6          ## after a lunge hits you, or a hit lands mid-windup
@export_range(0, 20, 0.5) var KNOCKBACK := 5.0
@export_range(0.5, 3, 0.1) var SOFT_AIM_ANGLE := 0.7       ## radians: swipes snap toward an enemy this far off-centre

@export_group("Rival lions")
@export_range(0.2, 5, 0.05) var RIVAL_HEALTH_MULT := 1.6    ## rivals have this much more health than you at equal strength
@export_range(0.05, 2, 0.01) var RIVAL_SWIPE_TELL := 0.45  ## warning before a rival swipe lands
@export_range(0.05, 2, 0.01) var RIVAL_LUNGE_TELL := 0.75  ## warning before a rival lunge
@export_range(0.1, 3, 0.05) var RIVAL_RECOVER := 0.55      ## open window after a rival attack
@export_range(0.1, 3, 0.05) var RIVAL_THINK_TIME := 0.5    ## average gap between rival decisions
@export_range(0, 1, 0.05) var RIVAL_LUNGE_CHANCE := 0.4    ## share of attacks that are lunges
@export_range(0, 1, 0.05) var RIVAL_DODGE_CHANCE := 0.35   ## chance to dodge your pounce
@export_range(0, 1, 0.05) var RIVAL_BLOCK_CHANCE := 0.3    ## chance a swipe is shrugged off (no damage)
@export_range(0, 1, 0.05) var RIVAL_COUNTER_CHANCE := 0.45 ## chance he answers a swipe with a quick swipe of his own
@export_range(0, 1, 0.05) var RIVAL_COMBO_CHANCE := 0.45   ## after a miss, chance to chain a quick swipe instead of recovering
@export_range(0.2, 1, 0.05) var RIVAL_COUNTER_TELL := 0.6  ## a counter's warning, as a fraction of the normal swipe tell
@export_range(0, 1, 0.01) var RIVAL_YIELD_AT := 0.15       ## rivals give up at this fraction of health
@export_range(1, 10, 0.5) var RIVAL_CIRCLE_DIST := 3.6
@export_range(1, 12, 0.5) var RIVAL_MOVE_SPEED := 4.5
@export_range(5, 60, 1) var STANDOFF_RANGE := 20.0         ## rivals face you and roar inside this
@export_range(0, 15, 0.5) var STANDOFF_TIME := 3.5         ## then they attack
@export_range(10, 100, 1) var DISENGAGE_RANGE := 34.0      ## run this far to escape a nomad fight
@export_range(0.3, 4, 0.05) var NOMAD_RIVAL_STRENGTH := 1.1
@export_range(0, 1, 0.05) var NOMAD_RIVAL_STRENGTH_PER_DAY := 0.15
@export_range(0, 1, 0.05) var NOMAD_RIVAL_CHANCE := 0.6    ## per nomad day after day 1
@export_range(0.3, 4, 0.05) var PRIDE_MALE_STRENGTH := 1.6
@export_range(0.3, 4, 0.05) var CHALLENGER_STRENGTH := 1.5
@export_range(1, 4, 1) var CHALLENGER_COUNT := 2
@export var CHALLENGERS_TOGETHER := false                  ## true = they fight you at the same time

# --- Pride ---------------------------------------------------------------
@export_group("Pride")
@export_range(0, 6, 1) var LIONESS_COUNT := 3
@export_range(0, 6, 1) var CUB_COUNT := 3
@export_range(0, 500, 5) var PRIDE_FOOD_NEED := 150.0      ## food the lionesses must eat each day or one leaves
@export_range(0.5, 20, 0.5) var LIONESS_EAT_RATE := 4.0
@export_range(5, 40, 0.5) var LIONESS_CHARGE_SPEED := 19.0
@export_range(3, 30, 0.5) var LIONESS_RUN_SPEED := 15.0
@export_range(0.5, 6, 0.1) var LIONESS_CHARGE_TIME := 2.0
@export_range(2, 30, 0.5) var LIONESS_CHASE_MAX := 7.0     ## give up after this long
@export_range(5, 80, 1) var LIONESS_ENGAGE_RANGE := 40.0   ## chase fleeing prey this close
@export_range(2, 30, 0.5) var LIONESS_FOLLOW_SPREAD := 7.0
@export_range(2, 40, 0.5) var LIONESS_FLANK_SPREAD := 16.0 ## how wide they fan out while you stalk
@export_range(0, 2, 0.05) var LIONESS_NOTICE_MULT := 0.6   ## how visible lionesses are to prey
@export_range(0, 2, 0.05) var LIONESS_TOUGHNESS_LIMIT := 1.0 ## a lioness alone can only grab prey this tough

# --- Hyenas ----------------------------------------------------------------
@export_group("Hyenas")
@export_range(0, 1, 0.05) var HYENA_CHANCE := 0.85         ## chance hyenas come to a carcass
@export_range(0, 60, 1) var HYENA_ARRIVE_DELAY := 14.0     ## seconds after the kill
@export_range(0, 8, 1) var HYENA_BASE := 2
@export_range(0, 3, 0.5) var HYENA_PER_DAY := 0.5          ## extra hyenas per day number
@export_range(2, 25, 0.5) var HYENA_SPEED := 11.0
@export_range(5, 200, 5) var HYENA_HEALTH := 30.0
@export_range(0, 40, 0.5) var HYENA_BITE_DAMAGE := 6.0
@export_range(0.05, 2, 0.05) var HYENA_DART_TELL := 0.35
@export_range(0.5, 15, 0.5) var HYENA_DART_INTERVAL := 3.5 ## average seconds between darts per hyena
@export_range(2, 20, 0.5) var HYENA_GUARD_RADIUS := 8.0    ## they won't feed while a lion is this close to the carcass
@export_range(0.5, 20, 0.5) var HYENA_EAT_RATE := 4.0      ## food per second each
@export_range(0.5, 15, 0.5) var HYENA_SCATTER_TIME := 4.0
@export_range(2, 40, 1) var ROAR_RADIUS := 14.0
@export_range(0, 20, 0.5) var ROAR_COOLDOWN := 7.0
@export_range(0, 1, 0.05) var ROAR_SCARE_CHANCE := 0.8     ## per hyena in range
@export_range(0, 120, 1) var ROAR_PREY_ALERT := 45.0       ## roaring spooks prey this close

# --- Prey senses -----------------------------------------------------------
@export_group("Prey senses")
@export_range(10, 150, 1) var SIGHT_RANGE := 60.0
@export_range(0.1, 5, 0.05) var AWARENESS_RATE := 0.9      ## base gain per second at point-blank
@export_range(0, 2, 0.05) var AWARENESS_DECAY := 0.25
@export_range(0.05, 1, 0.05) var ALERT_THRESHOLD := 0.45
@export_range(0.1, 2, 0.05) var FLEE_THRESHOLD := 1.0
@export_range(0, 2, 0.01) var POSTURE_STALK := 0.28
@export_range(0, 5, 0.05) var POSTURE_WALK := 1.0
@export_range(0, 20, 0.5) var POSTURE_SPRINT := 6.0
@export_range(0, 1, 0.05) var COVER_MULT := 0.35           ## in tall grass
@export_range(0, 1, 0.05) var GRAZE_SIGHT_MULT := 0.45     ## heads-down grazing
@export_range(0, 2, 0.05) var SCENT_STRENGTH := 0.3        ## awareness/sec from scent at point-blank, directly downwind
@export_range(5, 150, 1) var SCENT_RANGE := 55.0
@export_range(1, 20, 0.5) var PERSONAL_SPACE := 7.0        ## inside this, prey notice you fast whatever your posture
@export_range(0, 3, 0.05) var PERSONAL_SPACE_RATE := 0.8
@export_range(2, 50, 1) var PANIC_RADIUS := 18.0           ## fleeing animals spook others in this radius
@export_range(0, 2, 0.05) var PANIC_DELAY_MIN := 0.15
@export_range(0, 2, 0.05) var PANIC_DELAY_MAX := 0.45

@export_group("Prey movement")
@export_range(0.2, 4, 0.1) var GRAZE_SPEED := 1.4
@export_range(1, 60, 1) var PREY_ACCEL := 22.0
@export_range(0.1, 3, 0.05) var JINK_INTERVAL_MIN := 0.7
@export_range(0.1, 4, 0.05) var JINK_INTERVAL_MAX := 1.4
@export_range(1, 30, 0.5) var FLEE_TIME := 9.0             ## keeps running at least this long
@export_range(2, 40, 0.5) var TIRE_TIME := 11.0            ## after this many seconds of fleeing, slows down
@export_range(0.3, 1, 0.01) var TIRED_SPEED_MULT := 0.8
@export_range(0, 1, 0.05) var PREY_WEAK_CHANCE := 0.2     ## young or old animals: smaller and slower
@export_range(0.3, 1, 0.01) var PREY_WEAK_SPEED_MULT := 0.82
@export_range(0.1, 1, 0.05) var PREY_WEAK_FOOD_MULT := 0.7

# --- Species: one block each. Herds are per day. ------------------------------
@export_group("Warthog")
@export_range(0, 8, 1) var WARTHOG_HERDS := 2
@export_range(1, 12, 1) var WARTHOG_HERD_MIN := 1
@export_range(1, 12, 1) var WARTHOG_HERD_MAX := 3
@export_range(3, 30, 0.5) var WARTHOG_SPEED := 14.0
@export_range(0, 300, 5) var WARTHOG_FOOD := 30.0
@export_range(0.1, 5, 0.05) var WARTHOG_TOUGHNESS := 0.4
@export_range(0, 40, 0.5) var WARTHOG_KICK := 3.0
@export_range(0.1, 3, 0.05) var WARTHOG_VIGILANCE := 0.8   ## sight multiplier
@export_range(0, 2, 0.05) var WARTHOG_JINK := 1.2          ## radians

@export_group("Zebra")
@export_range(0, 8, 1) var ZEBRA_HERDS := 2
@export_range(1, 15, 1) var ZEBRA_HERD_MIN := 3
@export_range(1, 15, 1) var ZEBRA_HERD_MAX := 6
@export_range(3, 30, 0.5) var ZEBRA_SPEED := 17.0
@export_range(0, 300, 5) var ZEBRA_FOOD := 70.0
@export_range(0.1, 5, 0.05) var ZEBRA_TOUGHNESS := 1.0
@export_range(0, 40, 0.5) var ZEBRA_KICK := 10.0
@export_range(0.1, 3, 0.05) var ZEBRA_VIGILANCE := 1.0
@export_range(0, 2, 0.05) var ZEBRA_JINK := 0.7

@export_group("Wildebeest")
@export_range(0, 8, 1) var WILDEBEEST_HERDS := 1
@export_range(1, 20, 1) var WILDEBEEST_HERD_MIN := 6
@export_range(1, 20, 1) var WILDEBEEST_HERD_MAX := 10
@export_range(3, 30, 0.5) var WILDEBEEST_SPEED := 16.0
@export_range(0, 300, 5) var WILDEBEEST_FOOD := 60.0
@export_range(0.1, 5, 0.05) var WILDEBEEST_TOUGHNESS := 0.9
@export_range(0, 40, 0.5) var WILDEBEEST_KICK := 6.0
@export_range(0.1, 3, 0.05) var WILDEBEEST_VIGILANCE := 0.9
@export_range(0, 2, 0.05) var WILDEBEEST_JINK := 0.5

@export_group("Buffalo")
@export_range(0, 8, 1) var BUFFALO_HERDS := 1
@export_range(1, 15, 1) var BUFFALO_HERD_MIN := 4
@export_range(1, 15, 1) var BUFFALO_HERD_MAX := 6
@export_range(3, 30, 0.5) var BUFFALO_SPEED := 14.0
@export_range(0, 400, 5) var BUFFALO_FOOD := 150.0
@export_range(0.1, 8, 0.05) var BUFFALO_TOUGHNESS := 3.0
@export_range(0, 60, 0.5) var BUFFALO_KICK := 14.0
@export_range(0.1, 3, 0.05) var BUFFALO_VIGILANCE := 0.7
@export_range(0, 2, 0.05) var BUFFALO_JINK := 0.3
@export_range(0, 1, 0.05) var BUFFALO_DEFEND_CHANCE := 0.5  ## alerted buffalo charge you instead of fleeing
@export_range(2, 40, 1) var BUFFALO_CHARGE_RANGE := 14.0
@export_range(0, 80, 1) var BUFFALO_CHARGE_DAMAGE := 25.0

# --- Camera / feel ---------------------------------------------------------
@export_group("Camera and feel")
@export_range(2, 20, 0.5) var CAM_DISTANCE := 7.5
@export_range(0.5, 6, 0.1) var CAM_HEIGHT := 2.6
@export_range(0.0005, 0.01, 0.0001) var MOUSE_SENS := 0.0028
@export_range(0.5, 8, 0.1) var PAD_LOOK_SPEED := 2.8       ## controller right stick, radians/sec at full tilt
@export var PAD_INVERT_Y := false
@export_range(0.05, 0.5, 0.01) var PAD_DEADZONE := 0.18
@export_range(40, 100, 1) var FOV_BASE := 68.0
@export_range(40, 120, 1) var FOV_SPRINT := 86.0
@export_range(0, 0.3, 0.01) var HITSTOP_TIME := 0.09

var _defaults := {}


func _ready() -> void:
	for n in param_names():
		_defaults[n] = get(n)
	load_overrides()


## Names of every tunable value, in file order.
func param_names() -> Array[String]:
	var out: Array[String] = []
	for prop in get_script().get_script_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_EDITOR:
			out.append(prop.name)
	return out


func default_of(param: String) -> Variant:
	return _defaults.get(param)


func set_param(param: String, value: Variant) -> void:
	set(param, value)


func load_overrides() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for n in cfg.get_section_keys("tuning") if cfg.has_section("tuning") else PackedStringArray():
		if _defaults.has(n):
			set(n, cfg.get_value("tuning", n))


func save_overrides() -> void:
	var cfg := ConfigFile.new()
	for n in changed_params():
		cfg.set_value("tuning", n, get(n))
	cfg.save(SAVE_PATH)


func reset_all() -> void:
	for n in _defaults:
		set(n, _defaults[n])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func changed_params() -> Array[String]:
	var out: Array[String] = []
	for n in param_names():
		if get(n) != _defaults.get(n):
			out.append(n)
	return out


## The values that differ from the defaults, as lines you can paste back into this file or a chat.
func changes_as_text() -> String:
	var lines: PackedStringArray = []
	for n in changed_params():
		lines.append("%s = %s   (default %s)" % [n, str(get(n)), str(_defaults[n])])
	return "\n".join(lines) if lines.size() > 0 else "(no changes from defaults)"
