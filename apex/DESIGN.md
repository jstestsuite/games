# APEX: Design Doc

*Working title. A living document: update it whenever a decision changes.*

## Pitch

You are a young male lion, driven out of the pride you were born in. One run is one life, about **10–12 minutes**:

1. **Nomad** (days 1–2): hunt alone, eat, grow strong. Your mane darkens as you do.
2. **Challenge** (day 3): fight the pride's male for his pride. **Lose and the run is over.**
3. **Pride** (day 4): hunt with your lionesses and feed them. At dusk, challengers come for you. Beat them and you win.

Every hunt is a small tactical puzzle (wind, cover, herd vigilance, a short burst of speed), then a **ride**: you land on the animal and stay on as it runs and cuts, reading its body for the next turn. Between days you pick an instinct (trait), so each run plays differently.

**Goal for this project:** a game the developer's brother finds fun and worth playing. He likes hard games, so the default tuning is hard and fair: losing should always feel like your mistake.

Target feeling: **tense patience, an explosive release, then a struggle.** Thirty seconds of creeping through grass, a two-second charge, and then a fight to hold on.

## Pillars

1. **The ride is the heart of the game.** Staying on a panicking animal is the skill to learn; the stalk and chase set it up. (A physical skill under pressure is the one thing every playtest has liked.)
2. **Readable systems, read from the world.** Wind, cover, prey awareness and every attack have a visible cue (compass, `?` / `!` markers, `!` / `!!` attack warnings). During a ride the cues are on the animal's body, not on the screen: nothing between you and the animal.
3. **Pick your fight.** Species are difficulty tiers. A zebra on day 1 is a fair test; a wildebeest is a gamble; a buffalo needs the pride. The risk label tells you before you commit.
4. **Hunting feeds fighting.** What you eat becomes strength; strength makes every ride and clinch easier and decides the challenge.

## Core loop (implemented)

### Moving and hunting
- **Stalk** (Ctrl / LT): slow and quiet. Tall grass hides you. Prey alternate heads-down grazing (half vision) and heads-up scanning. **Herds get warier** each time you attack them.
- **Scent:** if the wind carries from you to them, they notice you however still you are. Approach from downwind.
- **Sprint** (Shift / RT) is a **charge, then a run**. The charge is a ~2 s burst at 22 m/s (faster than anything). It fades into a 15 m/s run, slower than healthy prey. After ~12 s of continuous sprinting you're **winded** for a few seconds. Sprinting burns hunger.
- **Pounce** (Space / A): a lunge with slight homing. You have **2 pounces in reserve** (pips in the charge ring); each takes 3 s to come back. **A miss leaves you sprawled** for a moment.
- **Risk label:** the animal you're facing shows **EASY / FAIR / RISKY / DEADLY**. It's your power (strength plus nearby lionesses) against the species' power.

### The ride (takedown)
Built in session 3, from Justin's description: "follow the prey... a catch meter... move in the same direction they move, with a soft magnet type pull." Code: `scripts/actors/ride.gd`.
- **Landing:** when a pounce lands, time hitches for a moment. The camera swings up and round to look down on the animal from a rear quarter, so its head and front feet show past you (`RIDE_CAM_PITCH`, `RIDE_CAM_SIDE`, `RIDE_CAM_DISTANCE`). The game then runs a little slower (`RIDE_TIME_SCALE`) while you ride.
- **The animal runs and cuts.** Every second or two it cuts hard to one side. Big animals sometimes **shake** instead.
- **Its body warns you, in order:**
  1. the **head swings** and the **shoulder drops** toward the cut;
  2. a **foot plants**, with a puff of dust, just before it goes.
  Some species swing the head the wrong way first; **the planted foot never lies**. A shake is announced by the head tossing.
- **Two feels to compare** (`RIDE_MODEL` in F1):
  - **BALANCE** (default): a cut flings you to the outside of the turn. Push the stick to keep your weight over its back. In practice: push toward the cut.
  - **STEER:** point the stick where it's going.
- **Momentum and the magnet:** either way a soft pull (`RIDE_MAGNET`) draws you back to centre, and your weight has momentum. Overcorrect and you swing past. Experts lean into a cut before it comes.
- **Catch meter = its fight.** It drains while you're in the **safe zone**. At empty, it goes down.
- **Grip.** Outside the safe zone your grip drains. At zero (or at the very edge) you're **thrown**: hurt, staggered, maybe injured.
- **Clamp** (RT, analogue; Shift or left-click): it tires faster, but the safe zone shrinks. The idea: clamp on the straights, ease off before a cut.
- **Let go** (B / right-click) at any time. It runs off still as tired as you left it (and slower for it), so you can bail before a bad moment and pounce again.
- **Help and strength:** each lioness holding on tires it faster and makes it slower. Your power against its power softens the throws.
- **The HUD** (kept small, at the bottom):
  - its fight, your balance (with the safe zone) and your grip;
  - `RIDE_SHOW_BALANCE` off hides the balance bar, to test riding by feel alone.

### Practice rooms (debug tool)
The title menu has the full game, plus a practice room per animal (including a **slow zebra**).
- **The room:** one animal near you; no day, hunger or hyenas.
- **Retry:** a fresh animal after each ride, or at once with roar (Y / Q). R or Back returns to the menu.
- **The log:** each ride's result, time, % of the time you were steady, and your **reaction**: average seconds from each cut to your counter. Negative means you read it before it came; that number should fall as you get better.

### Prey tiers

| Prey | Food | Power | The ride | Who should try it |
|---|---|---|---|---|
| Warthog | 30 | 0.6 | Short, gentle cuts, long warnings, light | Always safe. A snack. |
| Zebra | 70 | 1.2 | Quick, sharp cuts; **doubles straight back** often | Day 1, if you read the tells |
| Wildebeest | 90 | 1.6 | Huge cuts (nearly reverses), heavy; the head sometimes lies; the odd shake | A gamble on day 1, fair by day 2 |
| Buffalo | 200 | 2.8 | Heavy throws, a long ride; **the head lies half the time**; shakes; alerted buffalo also **charge you** | Near-suicide alone, easy with the pride |

About 20% of animals are **young or old**: smaller, slower, less food.

Tuning reference (`tests/ride_sim.gd`, BALANCE feel, 200 rides each).
- **The bots:**
  - **reactive:** only corrects once it's off balance, with a 0.28 s reaction time;
  - **reader:** also reads the head and the planted foot, and leans in early;
  - **perfect:** no delay, and knows every cut.
- **What to look for:** the gap between reactive and reader is the skill to learn.

| Matchup | Reactive | Reader | Perfect |
|---|---|---|---|
| Slow zebra (practice) | 100% | 100% | 100% |
| Warthog, day 1 | 100% | 100% | 100% |
| Zebra, day 1 (strength 1.0) | ~35% | ~100% | 100% |
| Zebra, day 2 (1.4) | ~95% | 100% | 100% |
| Wildebeest, day 1 | ~1% | ~20% | 100% |
| Wildebeest, day 2 | ~25% | ~75% | 100% |
| Buffalo, solo (1.4) | ~2% | ~30% | 100% |
| Buffalo, with 3 lionesses | 100% | 100% | 100% |

In STEER, the reading bot doesn't beat the reactive one. That means my bot hasn't found the technique there, not that there isn't one (the perfect bot still wins everything). Only a human playtest can say whether STEER has a skill to learn. See `tests/results/ride_sim.txt`.

Chases (`tests/hunt_sim.gd`, a heads-up adult zebra) land a pounce from 12 m almost always, rarely from 20 m or more. Young animals can be run down from further.

### Eating, hyenas and scarcity
- **Eating** takes time (E / RB to resume). When you're full you can keep **gorging**: slower, and all of it becomes **strength**. A big carcass is a choice between more strength and more time exposed.
- **Hunger** drains faster than before (about 80 food a day with the night). Food is meant to be scarce.
- **The hyena clan** (2 roamers, plus 1 per day) **shadows you all day** at about 35 m. They **converge on any kill** within 90 m, and sometimes more arrive. They feed if you leave and circle if you stay, darting in to bite (`!` warns you). They get bolder in numbers and when you're hurt. Swipe them, dodge, or **roar** (Q / Y) to scatter them (60% each).

### Fighting rival lions
- **Swipe** (Left click / F / X): fast, short range. **Dodge** (Right click / Alt / B): a quick hop with no damage taken.
- Rivals telegraph every attack: **`!` yellow = swipe**, **`!!` red, crouching = lunge**. Dodge it. If his lunge lands, he's on you in a clinch, and you start behind.
- **Pounce into him** to start a **clinch** with the initiative.
- **The clinch** is a tug-of-war on a balance bar:
  - **Yellow arrow (shove):** push *with* it to brace.
  - **Red arrow (bite):** push *away* from it.
  - **Win an exchange:** you gain balance and deal a little damage.
  - **Lose one:** you lose more balance than a win gains, and you take damage.
  - **At either end, someone is pinned.** Being pinned means big damage, a knockdown, and maybe an injury.
  - Letting go early gives him a parting bite.
- Swipes never interrupt a rival. Rivals block some swipes, counter swipe-spam and chain quick swipes after a miss.
- Damage scales with **strength^1.5**; rivals have extra health (a boss fight). At 15% health they **yield** and run.
- **Nomad rivals** (day 2, sometimes): optional. Run 34 m away to escape. Beating one gives bonus strength.

Tuning reference (`tests/fight_sim.gd`, 20 fights each; the bot dodges 70% of warnings and reads 70% of clinch arrows):

| Matchup | Bot wins |
|---|---|
| Even (1.0 v 1.0) | ~80% |
| Slightly stronger (1.3 v 1.25) | ~70% |
| 1.5 vs the 1.6 pride male | ~60%, with ~45% health left |
| 1.8 vs 1.6 | ~90% |
| 1.2 vs 1.6 | ~20% |

### The pride
- Beat the pride male and his **lionesses** follow you. They trail you while you walk and **fan out wide on your flanks while you stalk**, so a herd that bolts from you often runs into them.
- They chase anything fleeing nearby and **join your grapples**. Alone they can only hold animals they're strong enough for (two lionesses for a zebra).
- They eat their own kills and share yours. **Feed them 120 food by the last dusk and they drive off one of the challengers.**
- At dusk on the last day, **challengers** arrive (two by default, one after the other). Beat them all to win.

### Day, night, run
- **Day** (150 s): the clock stops during lion fights.
- **Health:** heals slowly after a few seconds unhurt, and partly at night. Health carries over between days.
- **Injuries** heal overnight.
- **Hunger:** at 0 you lose health.
- **Night:** costs hunger. Pick 1 of 3 traits.
- **Lose:** health hits 0 (a lost fight, hyenas, a buffalo, starving).
- **Win:** hold the pride through the last dusk.

## Tuning

- Every number is in `scripts/autoload/tuning.gd`, and the **F1 panel** edits them live in game.
  - Save keeps your changes for next time.
  - "Copy changes" puts only the values you changed on the clipboard, ready to paste to Claude.
- The ride's feel is the **Ride (prey)** group (model, magnet, damping, push, fling, safe zone, clamp, camera, mouse).
- Each species has a ride block: `POWER`, `RIDE_FIGHT`, `CUT_MIN` / `CUT_MAX`, `CUT_ANGLE`, `CUT_RATE`, `TELL`, `FAKE`, `DOUBLE`, `SHAKE`, `HEAVY`, `THROW_DAMAGE`, `INJURY_CHANCE`. The clinch has its own group.
- The probes report how things play out after a change:
  - `tests/hunt_sim.gd`: chases;
  - `tests/ride_sim.gd`: rides by species, strength, helpers and feel, for three bots;
  - `tests/fight_sim.gd`: lion fights.

## Status (session 3, 2026-10-22)

**Build 1 of the ride:**
- **Built:** the ride replaces the arrow grapple for every prey takedown, in the full game too. There's also a debug title menu with practice rooms.
- **Not changed, on purpose** (one change per build): the rest of v3 (days, hyenas, traits, the rival brawl and clinch). The design panel proposes cutting most of that; see `../design-panel-2026-10-22.md`.

**Verified by tests:**
- the whole loop, with a ride (smoke test);
- the practice rooms (practice test);
- a bot riding through a pride day (soak);
- the ride probe (skill gap, above);
- screenshots of the ride and the menu.

**Not yet verified, because no human has played it:**
- whether staying on is fun at ride 20;
- whether the body cues read at speed;
- BALANCE vs STEER;
- whether the mouse works for riding;
- whether the slower game speed while riding helps or drags.

**Known gaps and rough edges:**
- No audio. Primitive placeholder art. The cues are a head swing, a body tilt and a dust puff on primitive meshes.
- The lion hangs off the animal's rump; there's no real mounting animation.
- Contact angle doesn't matter yet (every ride starts centred, at full grip).
- Rival lions still use the v3 brawl and the arrow clinch.
- Hyenas, traits and the day structure are still v3's.
- Obstacle avoidance is simple steering. A ridden animal bends round trees and away from the rim between cuts, and picks its cut side toward open ground.
- The F1 panel needs a mouse.

See `PLAYTEST.md` for the feedback so far and what to watch for next.

## Next milestones (suggested order)

1. **Playtest the ride** in the practice rooms, then the full game. Is ride 20 still fun? Do the cues read? BALANCE or STEER? Then tune.
2. **The rival as a ride** (mirrored, plus at most one authored move), with a practice room.
3. **Audio:** wind, grass rustle, footfalls by speed, a heartbeat when close, roars, a fight sting. A huge part of feel.
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
- BALANCE or STEER? Or a mix: steer with the stick, balance with the clamp?
- Should the contact angle (landing from behind at speed vs head-on) set your starting grip?
- Is gorging a good use for surplus food, or should you be able to drag and stash a carcass?
- Is two challengers in a row at the end the right finale, or should they come together?
- How much should the lionesses carry you? Today a good stalk with them is very strong.
- Do we want lionesses to die (from buffalo or challengers) or only leave?
