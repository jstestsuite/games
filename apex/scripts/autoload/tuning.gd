extends Node
## Every gameplay number lives here so it can be tweaked in one place.
## Traits (see game_state.gd) multiply some of these at runtime via GameState.mod().
## Tip: change a value, press F5 in Godot, feel the difference.

# --- World -------------------------------------------------------------
const WORLD_SIZE := 256.0            # metres, square
const TERRAIN_RES := 128             # quads per side (mesh + collision)
const HILL_HEIGHT := 9.0             # max rolling-hill height
const TALL_GRASS_PATCHES := 26
const TREE_COUNT := 38
const ROCK_COUNT := 30

# --- Day / season -----------------------------------------------------
const DAY_LENGTH := 180.0            # seconds of real time per hunting day
const DAYS_PER_SEASON := 5
const HERDS_PER_DAY := 4
const GAZELLES_PER_HERD := Vector2i(4, 7)

# --- Hunger -------------------------------------------------------------
const HUNGER_MAX := 100.0
const HUNGER_START := 70.0
const HUNGER_DRAIN := 0.32           # per second, always
const HUNGER_DRAIN_SPRINT := 0.9     # extra per second while sprinting
const HUNGER_NIGHT_COST := 25.0      # paid when sleeping between days
const GAZELLE_FOOD := 55.0

# --- Cheetah movement ----------------------------------------------------
const WALK_SPEED := 7.0
const STALK_SPEED := 2.6
const SPRINT_SPEED := 31.0
const ACCEL_WALK := 18.0
const ACCEL_SPRINT := 14.0           # build-up to top speed
const TURN_RATE_WALK := 10.0         # radians/sec
const TURN_RATE_SPRINT := 2.6        # lower = wider turns at speed (prey jinks matter)
const STAMINA_MAX := 4.5             # seconds of sprint
const STAMINA_REGEN := 0.55          # per second while not sprinting
const STAMINA_MIN_TO_SPRINT := 1.0   # once exhausted, need this much to sprint again

# --- Pounce -------------------------------------------------------------
const POUNCE_SPEED := 36.0
const POUNCE_DURATION := 0.32
const POUNCE_CATCH_RADIUS := 2.1
const POUNCE_COOLDOWN := 0.9
const POUNCE_STAMINA_COST := 0.6
const POUNCE_HOMING := 6.0          # how hard a pounce curves toward nearby prey

# --- Gazelle senses -----------------------------------------------------
const SIGHT_RANGE := 60.0
const AWARENESS_RATE := 0.9          # base gain per second at point-blank
const AWARENESS_DECAY := 0.25
const ALERT_THRESHOLD := 0.45
const FLEE_THRESHOLD := 1.0
const POSTURE_STALK := 0.28
const POSTURE_WALK := 1.0
const POSTURE_SPRINT := 6.0
const COVER_MULT := 0.35             # in tall grass
const SCENT_STRENGTH := 0.3          # awareness/sec from scent at point-blank, directly downwind
const SCENT_RANGE := 55.0            # scent works further than sight
const PERSONAL_SPACE := 7.0          # inside this, prey notice you fast whatever your posture
const PERSONAL_SPACE_RATE := 0.8
const PANIC_RADIUS := 18.0           # fleeing herd-mates spook others in this radius
const PANIC_DELAY := Vector2(0.15, 0.45)

# --- Gazelle movement ---------------------------------------------------
const GAZELLE_GRAZE_SPEED := 1.4
const GAZELLE_FLEE_SPEED := 24.0
const GAZELLE_ACCEL := 26.0
const GAZELLE_JINK_INTERVAL := Vector2(0.7, 1.4)
const GAZELLE_JINK_ANGLE := 0.9      # radians
const GAZELLE_FLEE_TIME := 9.0       # keeps running at least this long
const GAZELLE_TIRE_TIME := 14.0      # after this many seconds of fleeing, slows down
const GAZELLE_TIRED_SPEED_MULT := 0.72

# --- Camera / feel ------------------------------------------------------
const CAM_DISTANCE := 6.5
const CAM_HEIGHT := 2.2
const MOUSE_SENS := 0.0028
const FOV_BASE := 68.0
const FOV_SPRINT := 88.0
const HITSTOP_TIME := 0.09
