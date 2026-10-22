extends SceneTree
## Tuning probe for the ride: is there a skill to learn? Three bots ride every species
## in both feels (RIDE_MODEL), many times each, with no scene (Ride simulates on its own):
##   reactive: only reacts to being off balance, after a human reaction time.
##   reader:   also reads the tells (the head, which can lie, then the planted foot) and
##             leans into the cut before it comes.
##   perfect:  no reaction time, knows which way every cut goes.
## A ride with depth shows a clear gap between reactive and reader; if reactive already
## wins nearly everything, the ride is too easy to need reading.
## Results print and save to tests/results/ride_sim.txt. Not pass/fail.
##
## Run:  godot --headless --path . -s tests/ride_sim.gd

const ProbeLog := preload("res://tests/probe_log.gd")
const RUNS := 200
const DT := 1.0 / 60.0
const REACTION := 0.28      # real seconds; the ride runs slower, so less game time
# Correction gains. BALANCE: push back toward the middle. STEER: point the stick where
# it's going, which is already a correction in proportion to how far off you are.
const KP := [3.0, 1.0]
const KD := [0.6, 0.15]
const ANTICIPATE := [0.8, 0.3]   # how hard a reader leans into a cut it has read, per model
const MAX_TIME := 40.0

# [label, species, slow multiplier, strength, lionesses helping]
const SCENARIOS := [
	["slow zebra, day 1", "ZEBRA", -1.0, 1.0, 0],
	["warthog, day 1", "WARTHOG", 1.0, 1.0, 0],
	["zebra, day 1", "ZEBRA", 1.0, 1.0, 0],
	["zebra, day 2", "ZEBRA", 1.0, 1.4, 0],
	["wildebeest, day 1", "WILDEBEEST", 1.0, 1.0, 0],
	["wildebeest, day 2", "WILDEBEEST", 1.0, 1.4, 0],
	["buffalo, solo", "BUFFALO", 1.0, 1.4, 0],
	["buffalo, 3 lionesses", "BUFFALO", 1.0, 1.6, 3],
]
const BOTS := ["reactive", "reader", "perfect"]

var TU: Node
var RideScript: GDScript   # loaded once the autoloads exist (ride.gd uses Tuning)
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 7


func _process(_d: float) -> bool:
	TU = root.get_node("Tuning")
	RideScript = load("res://scripts/actors/ride.gd")
	var lines: Array[String] = []
	var model_names := ["BALANCE (stay over its back)", "STEER (steer with it)"]
	var keep_model: int = TU.RIDE_MODEL
	for model in [0, 1]:
		TU.RIDE_MODEL = model
		lines.append("== %s" % model_names[model])
		lines.append("%-22s %-28s %-28s %-28s" % ["", "reactive", "reader", "perfect"])
		for sc in SCENARIOS:
			var row := "%-22s" % sc[0]
			for bot in BOTS:
				var wins := 0
				var time_sum := 0.0
				var steady_sum := 0.0
				for i in RUNS:
					var r := _ride(sc, bot)
					if r[0] > 0:
						wins += 1
						time_sum += r[1]
					steady_sum += r[2]
				var avg := time_sum / maxf(1.0, wins)
				row += " %-28s" % ("%3d%%  %4.1fs  steady %2d%%" % [
					roundi(100.0 * wins / RUNS), avg, roundi(100.0 * steady_sum / RUNS)])
			lines.append(row)
		lines.append("")
	TU.RIDE_MODEL = keep_model
	lines.append("win % · average seconds to bring it down (game time) · % of the ride spent in the safe zone")
	lines.append("%d rides per cell. Reaction %.2f s real (x RIDE_TIME_SCALE %.2f in game time)." % [
		RUNS, REACTION, TU.RIDE_TIME_SCALE])
	for l in lines:
		print(l)
	ProbeLog.save(self, "ride_sim", lines)
	quit(0)
	return true


## One ride. Returns [result (+1 down, -1 thrown, 0 timeout), seconds, steady fraction].
func _ride(sc: Array, bot: String) -> Array:
	var species: String = sc[1]
	var params := func(key: String) -> float: return float(TU.get(species + "_" + key))
	var slow: float = TU.PRACTICE_SLOW if sc[2] < 0.0 else sc[2]
	var power: float = sc[3] + sc[4] * TU.LIONESS_GRAB_POWER
	var r = RideScript.new()
	r.setup(params, power / float(TU.get(species + "_POWER")), 0.0, 1.0, slow, null)
	r.helpers = sc[4]
	var delay: float = 0.0 if bot == "perfect" else REACTION * TU.RIDE_TIME_SCALE
	var lag := maxi(0, roundi(delay / DT))
	var seen: Array = []          # what the bot has perceived, [x, xv, head, plant, side, phase]
	var guess := 0.0              # which way the bot thinks the next cut goes
	var res := 0
	while r.age < MAX_TIME:
		seen.append([r.x, r.xv, r.head, r.plant, r.side, r.phase])
		var view: Array = seen[maxi(0, seen.size() - 1 - lag)]
		var u: float = clampf(-(KP[r.model] * view[0] + KD[r.model] * view[1]), -1.0, 1.0)
		if bot != "reactive":
			if bot == "perfect":
				guess = r.side if r.phase == 1 else 0.0
			elif view[5] == 1:   # a tell, as the bot saw it: lean in early, then just track the cut
				# The planted foot is the truth; a head only counts once it's clearly swung.
				guess = view[4] if view[3] > 0.0 else (signf(view[2]) if absf(view[2]) > 0.7 else 0.0)
			else:
				guess = 0.0
			if not r.is_shake and guess != 0.0:
				var counter: float = guess if r.model == 0 else -guess
				u = clampf(u + ANTICIPATE[r.model] * counter, -1.0, 1.0)
		u += _rng.randf_range(-0.08, 0.08)   # hands aren't perfectly steady
		res = r.update(DT, u, 0.0)
		if res != 0:
			break
	return [res, r.age, r.steady_fraction()]
