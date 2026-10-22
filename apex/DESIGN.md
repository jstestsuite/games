# APEX: Design Doc

*Working title. A living document: update it whenever a decision changes.*

## Pitch

You are a young male lion, driven out of the pride you were born in. One run is one life, about **10–12 minutes**:

1. **Nomad** (days 1–2): hunt alone, eat, grow strong. Your mane darkens as you do.
2. **Challenge** (day 3): fight the pride's male for his pride. **Lose and the run is over.**
3. **Pride** (day 4): hunt with your lionesses and feed them. At dusk, challengers come for you. Beat them and you win.

Every hunt is a small tactical puzzle (wind, cover, herd vigilance, a short burst of speed), then a **grapple**: a wrestling minigame where you hold on and match the animal's lurches. Between days you pick an instinct (trait), so each run plays differently.

**Goal for this project:** a game the developer's brother finds fun and worth playing. He likes hard games, so the default tuning is hard and fair: losing should always feel like your mistake.

Target feeling: **tense patience, an explosive release, then a struggle.** Thirty seconds of creeping through grass, a two-second charge, and then a fight to hold on.

## Pillars

1. **The stalk is a puzzle, the chase is a skill test, the grapple is the payoff.** The grapple is the part the first playtest liked; it's the heart of the game.
2. **Readable systems.** Wind, cover, prey awareness, every lurch and every attack have a visible cue (compass, `?` / `!` markers, the grapple arrow, `!` / `!!` attack warnings, the risk label). Losing should feel fair.
3. **Pick your fight.** Species are difficulty tiers. A zebra on day 1 is a fair test; a wildebeest is a gamble; a buffalo needs the pride. The risk label tells you before you commit.
4. **Hunting feeds fighting.** What you eat becomes strength; strength makes every grapple and clinch easier and decides the challenge.

## Core loop (implemented)

### Moving and hunting
- **Stalk** (Ctrl / LT): slow and quiet. Tall grass hides you. Prey alternate heads-down grazing (half vision) and heads-up scanning. **Herds get warier** each time you attack them.
- **Scent:** if the wind carries from you to them, they notice you however still you are. Approach from downwind.
- **Sprint** (Shift / RT) is a **charge, then a run**. The charge is a ~2 s burst at 22 m/s (faster than anything). It fades into a 15 m/s run, slower than healthy prey. After ~12 s of continuous sprinting you're **winded** for a few seconds. Sprinting burns hunger.
- **Pounce** (Space / A): a lunge with slight homing. You have **2 pounces in reserve** (pips in the charge ring); each takes 3 s to come back. **A miss leaves you sprawled** for a moment.
- **Risk label:** the animal you're facing shows **EASY / FAIR / RISKY / DEADLY**. It's your power (strength plus nearby lionesses) against the species' power.

### The grapple (takedown)
- When a pounce lands, time slows for a moment and the camera swings in close. **Hold pounce** to stay on.
- The animal **lurches**. Before each one, an arrow flashes on screen and the animal leans that way. **Push the stick (or WASD) with the arrow** before the short window closes.
  - **Match it:** the takedown bar fills.
  - **Miss it:** you lose **grip** and take a kick or horn.
  - **Grip hits zero:** you're **thrown off**, staggered, and maybe **injured** (a weaker, slower charge until you sleep).
- Some species **fake** (the arrow switches mid-warning) or **double** (a second lurch right after one).
- **Strength** gives longer warnings, smaller grip losses and faster progress. **Each lioness holding on** adds power and steady progress.

### Prey tiers

| Prey | Food | Power | The grapple | Who should try it |
|---|---|---|---|---|
| Warthog | 30 | 0.6 | 2 directions, slow warnings, weak hits | Always safe. A snack. |
| Zebra | 70 | 1.2 | 4 directions, kicks, the odd fake | Day 1 with good timing |
| Wildebeest | 90 | 1.6 | Faster, more fakes and doubles, horns | A gamble on day 1, fair by day 2 |
| Buffalo | 200 | 2.8 | Fast, brutal hits; alerted buffalo also **charge you** | Near-suicide alone, easy with the pride |

About 20% of animals are **young or old**: smaller, slower, less food.

Tuning reference (bot with 0.28 s reaction time that reads 80% of arrows right, `tests/grapple_sim.gd`):

| Matchup | Bot wins | Health lost |
|---|---|---|
| Warthog, day 1 | ~100% | ~1% |
| Zebra, day 1 (strength 1.0) | ~90% | ~20% |
| Wildebeest, day 1 | ~50% | ~45%, often injured |
| Wildebeest, day 2 (strength 1.4) | ~85% | ~25% |
| Buffalo, solo (1.6) | ~25% | ~80%, usually injured |
| Buffalo, with 3 lionesses | ~100% | ~12% |

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
- Each species has its own grapple block: `POWER`, `GRAB_HITS`, `GRAB_TELL`, `GRAB_DIRS`, `GRAB_FAKE`, `GRAB_DOUBLE`, `GRAB_DAMAGE`, `GRAB_GRIP_LOSS`, `INJURY_CHANCE`. The clinch has its own group.
- The probes report how things play out after a change:
  - `tests/hunt_sim.gd`: chases;
  - `tests/grapple_sim.gd`: grapples by species, strength and helpers;
  - `tests/fight_sim.gd`: lion fights.

## Status (end of session 2, 2026-10-22)

**Second version, built from the first playtest:**
- the grapple minigame and species tiers;
- clinches;
- the pounce reserve;
- a 4-day run;
- the hyena clan;
- scarcity and gorging;
- obstacle avoidance;
- a meat marker on carcasses.

**Verified by tests:**
- the whole loop (smoke test);
- the hunt, grapple and fight probes;
- screenshots of the grapple and clinch HUD.

**Not yet verified, because no human has played it:**
- whether the grapple stays fun past the first few;
- whether the arrow is readable while the camera shakes;
- whether 0.3 s windows feel fair on a controller.

**Known gaps and rough edges:**
- No audio. Primitive placeholder art.
- The lurch "lean" is a simple body tilt.
- Grapple directions are screen-relative, which is right while the camera is locked, but untested with real players.
- No lock-on outside clinches.
- Obstacle avoidance is simple steering, not pathfinding. Tight clusters of rocks can still snag animals; a stuck animal turns 90° to escape.
- All lionesses chase the same animal.
- Cubs are decoration.
- The F1 panel needs a mouse.
- A single valley.
- The pride food check only matters if `PRIDE_DAYS` > 1. With the default 4-day run it pays off as one fewer challenger.
- The balance numbers come from bots. The first playtest of v1 showed bots miss exploits (pounce spam), so expect surprises.

See `PLAYTEST.md` for the feedback so far and what to watch for next.

## Next milestones (suggested order)

1. **Playtest the grapple.** Is it still fun on the tenth animal? Are the tiers right? Does the clinch feel different enough from prey? Then tune.
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
- Should the grapple directions be fixed to the animal (left = its left) instead of the screen?
- Is gorging a good use for surplus food, or should you be able to drag and stash a carcass?
- Is two challengers in a row at the end the right finale, or should they come together?
- How much should the lionesses carry you? Today a good stalk with them is very strong.
- Do we want lionesses to die (from buffalo or challengers) or only leave?
