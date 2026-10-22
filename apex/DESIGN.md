# APEX: Design Doc

*Working title. A living document: update it whenever a decision changes.*

## Pitch

You are a predator on the savanna. Each run is one **season**: survive a set number of days by hunting. Every hunt is a small tactical puzzle (wind, cover, herd vigilance, stamina) solved in real time, third person. Between days you choose an instinct (trait), building toward a run that plays differently each time.

Target feeling: **tense patience, then an explosive release.** Thirty seconds of creeping through grass, then three seconds of the fastest thing you've ever controlled.

## Pillars

1. **The stalk is a puzzle, the chase is a skill test.** Both have to be good.
2. **Readable systems.** Wind, cover, and prey awareness are always visible (compass, "?" and "!" markers, HUD status). Losing should feel fair.
3. **Every hunt is a bet.** Food, stamina, and time are scarce. Sprinting too early or picking the wrong target costs you.
4. **Runs diverge.** Traits and (later) different predators change how you hunt, not just your stats.

## Core loop (implemented)

- **Day** (180 s): hunger drains. Herds of gazelles graze in the valley.
- **Stalk:** crouch (Ctrl) to move slowly and quietly. Tall grass hides you. Gazelles alternate heads-down grazing (half vision) and heads-up scanning.
- **Scent:** if the wind carries from you to them, they notice you no matter how still you are. Approach from downwind.
- **Awareness:** each gazelle has a meter. `?` = suspicious or alert, `!` = fleeing. Fleeing spreads panic to nearby animals.
- **Chase:** sprint (Shift) spends a day-long stamina budget (about 14 s; refills at night, +6 s per kill, a trickle while standing still). You're faster in a straight line (31 vs 24 m/s), but you turn wide at speed and gazelles jink.
- **Pounce** (Space/LMB): a short lunge with slight homing. Hit = kill, feed, brief hit-stop. Miss = lost momentum.
- **Night:** the night costs hunger. Pick 1 of 3 traits. Next day, new wind, new herds.
- **Lose:** hunger hits 0. **Win:** survive 5 days.

Tuning reference (bot test, head-up lone gazelle): a sprint started from about 14 m nearly always catches, 20 to 28 m is a coin flip, and 36 m or more usually escapes. Real players will do worse than the bot.

## Next milestones (suggested order)

1. **Playtest and tune the core.** Does stalking feel tense? Does the chase feel fast? Adjust `scripts/autoload/tuning.gd`.
2. **Real art pass for the two animals.** Swap the primitive rigs for CC0 animated models (e.g. Quaternius animal packs) behind the same `animate()` API.
3. **Audio.** Wind, grass rustle, footfalls by speed, heartbeat when close, chase music sting, kill sound. This is a huge part of feel.
4. **Rivals:** hyenas that track kills and try to steal your carcass, so you can't eat in the open safely.
5. **More prey:** hares (safe, low food), wildebeest (big food, can injure you).
6. **Injury system:** failed hunts on big prey can hurt you, limiting sprint for a day.
7. **Second predator:** lion (ambush, power, can take big prey, slower sprint).
8. **Meta-progression:** unlock predators and biomes across runs.

## Predator roster (planned)

| Predator | Identity | Key verbs |
|---|---|---|
| Cheetah | Speed, fragile | Huge burst sprint, tiny stamina, loses kills to rivals |
| Lion | Ambush, power | Short charge, takes big prey, intimidates rivals |
| Leopard | Stealth | Climbs trees to drop or stash kills, best camouflage |
| Wolf | Pack | Weak alone, recruits packmates through the run |
| Bear | Tank | Slow, forages, bullies others off kills |
| Crocodile | Trap | Waits at water, near-invisible, explosive lunge |

## Open questions

- Should a day end on a timer, or when you choose to sleep (with hunger as the only clock)?
- How punishing should a lost carcass be?
- Do we want a world map between days (pick a territory), or a single valley that changes?
