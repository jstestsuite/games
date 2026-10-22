# APEX: Design Doc

*Working title. A living document: update it whenever a decision changes.*

## Pitch

You are a young male lion, driven out of the pride you were born in. One run is one life, about **15 minutes**:

1. **Nomad** (days 1–3): hunt alone, eat, grow strong. Your mane darkens as you do.
2. **Challenge** (day 4): fight the pride's male for his pride. **Lose and the run is over.**
3. **Pride** (day 5): hunt with your lionesses and keep them fed. At dusk, challengers come for you. Beat them and you win.

Every hunt is a small tactical puzzle (wind, cover, herd vigilance, a short burst of speed) solved in real time, third person. Between days you pick an instinct (trait), so each run plays differently.

**Goal for this project:** a game the developer's brother finds fun and worth playing. He likes hard games, so the default tuning is hard and fair: losing should always feel like your mistake.

Target feeling: **tense patience, then an explosive release.** Thirty seconds of creeping through grass, then a two-second charge.

## Pillars

1. **The stalk is a puzzle, the chase is a skill test, the fight is a duel.** All three have to be good.
2. **Readable systems.** Wind, cover, prey awareness and every enemy attack have a visible cue (compass, `?` / `!` markers, `!` / `!!` attack warnings, HUD bars). Losing should feel fair.
3. **Every hunt is a bet.** Food, health and time are scarce. Charging too early, picking the wrong target, or eating in the open costs you.
4. **Hunting feeds fighting.** What you eat becomes strength; strength decides the challenge. A good nomad phase makes the fight winnable.

## Core loop (implemented)

### Moving and hunting
- **Stalk** (Ctrl): slow and quiet. Tall grass hides you. Prey alternate heads-down grazing (half vision) and heads-up scanning.
- **Scent:** if the wind carries from you to them, they notice you however still you are. Approach from downwind.
- **Sprint** (Shift) is a **charge, then a run**. The charge is a ~2 s burst at 22 m/s (faster than anything). It fades into a 15 m/s run, slower than healthy prey. The charge refills while you're not sprinting (faster when still). After ~12 s of continuous sprinting you're **winded** for a few seconds. Sprinting burns hunger.
- **Pounce** (Space): a lunge with slight homing. Landing on prey starts a **takedown**: **hold Space** to keep your grip while it drags you and kicks. Let go and it escapes. Bigger prey take longer and hurt more.
- **Eat:** a kill isn't instant food. You eat it over several seconds (E to resume). Food fills hunger and builds **strength**.
- **Hyenas** arrive at most carcasses after ~14 s. They feed if you leave and circle if you stay, darting in to bite (`!` warns you). Swipe them, dodge, or **roar** (Q) to scatter them.

### Prey

| Prey | Food | Danger | Notes |
|---|---|---|---|
| Warthog | 30 | Low | Small herds, sharp jinks. A safe meal. |
| Zebra | 70 | Kicks | The main target. |
| Wildebeest | 60 | Light kicks | Big herds; panic spreads fast. |
| Buffalo | 150 | High | Half the time an alerted buffalo **charges you**. A long, painful takedown alone; easy with the pride. |

About 20% of animals are **young or old**: smaller and slower. Your sustained run can catch them when it can't catch a healthy adult, so picking the target matters.

Tuning reference (bot test, a heads-up adult zebra, `tests/hunt_sim.gd`):
- a charge from 12–20 m nearly always catches;
- 28 m or more escapes;
- a young zebra can be run down from 40 m.

### Fighting
- **Swipe** (Left click / F): fast, short range. **Pounce** into a lion or hyena is a heavy lunge. **Dodge** (Right click / Alt): a quick hop with no damage taken.
- Rivals telegraph every attack: **`!` yellow = swipe**, **`!!` red, crouching = lunge**. Dodge the attack.
- Swipes never interrupt a rival. A pounce that lands always staggers him, so a pounce into his windup is the big counter.
- Rivals block some swipes and answer swipe-spam with quick counters. When they miss, they sometimes chain a quick swipe instead of leaving an opening.
- Damage scales with **strength^1.5**; rivals have extra health (a boss fight). At 15% health they **yield** and run.
- **Nomad rivals** (days 2–3, sometimes): optional. Run 34 m away to escape. Beating one gives bonus strength.

Tuning reference (`tests/fight_sim.gd`, a bot with human reaction time that dodges 70% of tells):

| Matchup | Bot wins |
|---|---|
| Even | ~40% |
| Slightly stronger | ~80% |
| 1.5 vs the 1.6 pride male | ~40%, with little health left |
| 1.8 vs 1.6 | ~80% |
| 1.2 vs 1.6 | ~20% |

### The pride
- Beat the pride male and his **lionesses** follow you. They trail you while you walk and **fan out wide on your flanks while you stalk**, so a herd that bolts from you often runs into them.
- They chase anything fleeing nearby and help hold what you've grabbed (takedowns go much faster).
- They eat their own kills, and they share yours. The pride must eat **150 food a day** or a lioness leaves.
- At dusk on the last day, **challengers** arrive (two by default, one after the other). Beat them all to win.

### Day, night, run
- **Day** (150 s): the clock stops during lion fights.
- **Health:** heals slowly after a few seconds unhurt, and partly at night. Health and scars carry over between days.
- **Hunger:** at 0 you lose health.
- **Night:** costs hunger. Pick 1 of 3 traits.
- **Lose:** health hits 0 (a lost fight, hyenas, a buffalo, starving).
- **Win:** hold the pride through the last dusk.

## Tuning

- Every number is in `scripts/autoload/tuning.gd`, and the **F1 panel** edits them live in game.
- Save keeps your changes for next time.
- "Copy changes" puts only the values you changed on the clipboard, ready to paste to Claude.
- `tests/hunt_sim.gd` and `tests/fight_sim.gd` report how hunts and fights play out after a change.

## Next milestones (suggested order)

1. **Playtest and tune the full loop.** Is the challenge a wall or a speed bump? Do hyenas feel like pressure or a nuisance? Does the pride help enough?
2. **Audio:** wind, grass rustle, footfalls by speed, a heartbeat when close, roars, a fight sting. A huge part of feel.
3. **Real art pass:** swap the primitive rigs for CC0 animated models behind the same `animate()` API. Lions first.
4. **Territory map:** choose where to hunt each morning (plains, riverbank, hyena country, drought valley).
5. **Rule-changing traits** (e.g. ambush from cover always staggers, scavenger steals from hyenas).
6. **Cubs that matter:** protect them from hyenas or infanticidal challengers; a surviving cub carries a trait into the next run.
7. **Meta-progression:** unlock starting traits, other predators and biomes across runs.
8. **Co-op:** two coalition brothers (local or online). Worth keeping in mind; don't design against it.

## Predator roster (later)

| Predator | Identity | Key verbs |
|---|---|---|
| Lion | Power, pride | Short charge, takedowns, fights for a pride |
| Cheetah | Speed, fragile | Huge burst sprint, loses kills to rivals |
| Leopard | Stealth | Climbs trees to drop or stash kills, best camouflage |
| Wolf | Pack | Weak alone, recruits packmates through the run |
| Crocodile | Trap | Waits at water, near-invisible, explosive lunge |

## Open questions

- Should losing a nomad fight end the run too, or only the challenge? (Today any death ends it; nomad fights can be escaped.)
- Is two challengers in a row at the end the right finale, or should they come together?
- How much should the lionesses carry you? Today a good stalk with them is very strong.
- Do we want lionesses to die (from buffalo or challengers) or only leave?
