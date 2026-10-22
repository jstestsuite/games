# Design panel, 2026-10-22: what is APEX missing?

After the v3 playtest, the developer asked Claude to "spawn agents and have a chat" about what the game is missing and whether the idea is wrong. Four Claude subagents took a seat each:
- **A**, game feel and the core verb;
- **B**, hard games and roguelikes;
- **C**, a skeptic challenging the premise;
- **D**, a player advocate and process critic.

They pitched independently, then each read the others' pitches and rebutted them. All four are the same model, so treat "consensus" as one model arguing with itself from four angles, not as four independent humans. Nothing here is decided until the developer says so.

## Consensus after round 2 (all four)
1. **The idea isn't wrong; the verb and the process are.**
   - The one thing that has landed in three drafts is learning a physical skill under pressure. v3 turned the developer's "follow the prey" into a reaction quiz: an arrow, a flick, pass or fail. A quiz has a low ceiling.
   - The process problem: v2's 8 feedback bullets became about 8 new systems in one commit, so nothing could be judged on its own.
2. **One verb: the ride.** You stay on the animal with continuous stick tracking.
   - **Catch meter:** it fills while you're with the animal and grip drains with your error. A soft magnet keeps it doable.
   - **Rider inertia:** overcorrect and you swing like a pendulum, so experts *lead* the animal and novices *lag* it. That's the skill ceiling.
   - **Read the body, not the HUD:** a head turn or planted legs 0.2–0.4 s before a cut. No arrows.
   - **Randomised behaviour:** tendencies vary in timing and direction, not fixed rhythms, because memorised patterns go dead.
   - **Species = motion signatures:** a zebra jinks fast and shallow; a buffalo makes heavy bucks with false head tells.
   - **Right trigger = analogue clamp.** It drains the animal faster but narrows your tolerance and costs stamina.
   - **A release button:** bail at any time and keep part of the progress as a wound. That's push-your-luck.
3. **The rival lion fight is the same ride, mirrored.** Add an authored move (his lunge) only if the mirror feels samey. This removes the swipe/dodge/block brawl and the yellow/red clinch.
4. **Cut:**
   - the arrow quiz;
   - the brawl and the clinch colours;
   - hyenas (all four: redesign later only if the ride needs a threat);
   - traits;
   - risk labels;
   - hunger, gorging and scarcity;
   - the pounce reserve;
   - the 4-day structure;
   - lionesses, for now;
   - the stalk and awareness meters, from the prototype. Picking an animal from a moving herd, plus contact angle and speed setting your starting grip, is enough "approach".
5. **Next build: a greybox test room, about half a day of work.**
   - One flat plain, capsule animals with 2–3 motion signatures, and instant retry.
   - F1 sliders, plus a toggle between feel variants: "match heading" or "stay over the spine", and magnet strength.
   - A perfect-follow bot first: if it wins 100% at every setting, there's no depth yet, so add commitment.
   - Log the signed stick lag per ride. Mastery shows as lag moving from behind the animal to ahead of it over 10 rides.
   - The developer's test: 10–15 rides per setting. Is ride 15 more fun than ride 1? Do you want ride 16?
6. **Process changes:**
   - **Restate before building.** Before any code, Claude restates the idea in one sentence about what the thumbs do, and the developer confirms it.
   - **One change per build.** Offer 2–3 feel variants on a toggle rather than one interpretation.
   - **Gate content.** Build nothing around the ride until ride 20 is still fun.
   - **Log feedback word for word.**
7. **Ask the brother first, today, by text:**
   - Which 3 games has he played most in the past year?
   - Is the fun of a hard game learning a boss's patterns, finding broken builds, or execution?
   - Controller or keyboard?
   - Does the theme (animals) matter to him?
   - Does he replay a game over many evenings?
   If possible, have him play v3 for 10 uncoached minutes as a baseline.
8. **The lion stays, cheaply.** It gives a ladder (bigger prey means a harder ride, with the pride male as the boss) and a run goal (take the pride). No systems get built for the fantasy until the ride passes.

## Still split
- **The shell, after the ride passes:**
  - A, C and D: chained hunts or a small arena, plus B's "challenge the male whenever you're ready" as the run's one big decision.
  - B: a small map with the male on it and a dry-season clock thinning the herds.
  Everyone agrees: no open savanna yet.
- **The stick model:** "match the heading" (A) or "stay over the spine / shift weight" (D). A now leans to D's, because it keeps your eyes on the animal's body. Build both on a toggle.
- **Whether the lion is a hook or a skin.** It depends on the brother's answer to "does the theme matter?"

# Round 1: the four pitches (condensed)

## A. Feel / core verb: "The Ride"
- **Diagnosis:** the verb is wrong, not the idea. An arrow quiz has a low ceiling. Pursuit tracking has no ceiling.
- **Loop:** sprint into a spooked herd, pick an animal and an angle, leap, then ride in real time across real terrain for 10–20 s.
- **The ride:** the left stick matches the animal's heading. Grip drains with the angle error, and a small magnet cone helps. The rider has inertia, so overcorrecting swings you like a pendulum.
- **Right trigger = analogue clamp.** More clamp drains the animal's stamina faster but narrows your error tolerance.
- **Tells come from the body** (a head turn, a dropped shoulder) 0.2–0.4 s before a cut. Experts lead the animal; novices lag it.
- **The world fights you:** prey drag you into thorns. You can lean to steer it, at a cost in grip.
- **Species are motion signatures.** The buffalo's head tells are false; it commits when it plants its feet.
- **Contact angle and speed** set your starting grip.
- **Rival:** the same verb. Both of you track and clamp.
- **Cut:** stalk and awareness meters ("choosing a target from a moving herd is the stalk"), long slow-mo, the brawl, hyenas, traits, the day structure. Chain hunts; dying ends the run.
- **Test:** a half-day greybox (capsule, one zebra, 3 motion scripts, F1 sliders). Log the signed stick lag over 10 rides; we want it to go from behind the animal to ahead of it.

## B. Hard games / roguelike: "One verb, everything is a ride"
- **Diagnosis:** the skill is split across three control schemes, and the boss is taught only at the highest-stakes moment. Days 1–2 are a grind. Hyenas are a tax with no decision.
- **Loop:** read the herd by body (no labels), stalk, charge, pounce, ride (the catch meter plus a soft magnet). The animal drags you toward hazards.
- **Release (B)** at any time keeps half the progress as a wound on the animal. Push your luck or bail.
- **Boss:** the same ride in reverse, plus 3 fixed, learnable moves (a swipe to dodge, a lunge that becomes a ride where he steers you, a roar that drives you back).
- **Structure:** the pride male is on the map from minute one, and you challenge whenever you choose. A dry-season clock thins the herds each day. Health doesn't regenerate; meat heals you or makes you stronger. The run's real decision is "am I strong enough yet?"
- **Variety:** random layout and herds, scars earned by deeds (riding a buffalo earns "thick hide"), and Hades-style heat modifiers after a win.
- **Cut:** hyenas, pride day, the trait menu, the brawl and the clinch colours, the quiz, hold-A, risk labels, the pounce reserve, gorging, lioness AI.
- **Test:** a greybox with 3 species plus the male's ride. Time-to-catch should improve over attempts, and the developer should retry the buffalo unprompted.

## C. Skeptic: "Hunt Rush"
- **Diagnosis:** an open savanna sim makes emergent, cheap difficulty, and every self-running system has flopped. The hook is "ride a panicking animal and stay on", not "be a lion". The open map is travel time that burns the developer's playtest minutes.
- **Pitch:** a boss rush in one small arena. Each level is one animal (warthog, zebra, wildebeest, buffalo, then the rival male as the final boss), about 8 hunts per run in under 15 minutes. One death ends the run. After each kill you pick one of 3 rule-changing boons.
- **The ride:** authored, learnable patterns (the zebra zigzags in rhythm, the wildebeest doubles back, the buffalo spins you into trees). The catch meter fills while you're in line and drains while you're out.
- **Right trigger = "dig claws":** it pauses the drain and spends a small grip pool.
- **Steelman lion:** keep the lion as a skin and a ladder. The minimum version is arena hunts plus one rival fight.
- **Ask the brother first:**
  - his top 3 games from the last year;
  - is the fun of a hard game learning patterns, broken builds, or execution;
  - controller or keyboard;
  - does the theme matter;
  - does he replay over many evenings?
  Also have him play v3 for 10 uncoached minutes.
- **Test:** a void prototype. Alignment % should rise over 10 attempts, and each fall should be explainable.

## D. Player advocate / process: "Hang on"
- **Diagnosis:** the idea isn't wrong; the translation is.
  - The developer describes feel ("follow the prey", "danger"), and Claude has turned each into a system with a HUD prompt. 8 feedback bullets became 8 new systems in one commit, so nothing could be judged on its own.
  - What the developer wants underneath is **weight**: a physical struggle read from the animal's body. The arrow pulls your eyes off the zebra.
  - The lion fight wasn't understood because of too many systems, an inverted colour mapping, and no way to practise (each attempt costs a whole run).
- **Ride:** the left stick shifts your weight to stay over the spine, a soft magnet pulls you to centre, and you read the body (planted legs before a jink, a dropped head before a buck). The right trigger digs in your claws: analogue, it costs stamina, and over-squeezing runs you dry.
- **Rival:** the same verb mirrored.
- **Keep:** the stalk (creep in the grass, then a 2 s charge, then the pounce), the charge-then-run sprint, the F1 panel and the bots.
- **Process change:**
  1. Build one verb in one test room with instant retry and the magnet strength on the d-pad.
  2. Claude restates the idea in one sentence about the thumbs, and the developer confirms it before any code.
  3. Ship 2–3 feel variants on a toggle.
  4. Gate content until ride 20 is still fun.
  5. The brother plays the test room early.
  6. Log feedback word for word.
- **Cut:** everything else (the quiz, the colours, the brawl, hyenas, traits, days, labels, hunger, lionesses, the pounce reserve, and the one-shot challenge until it can be practised).
- **Test:** a test room at 3 magnet settings × 15 rides. Also a perfect-follow bot: if it wins 100%, there's no depth, so add commitment (momentum you can't instantly undo).

## Where you already agree
All four of you want to:
- make the ride, with continuous stick tracking and a catch meter, the one verb;
- build it as a greybox test room first;
- make the rival fight use the same verb;
- cut hyenas, the arrow quiz, the brawl, traits and the risk labels.

## Open disagreements
1. **The world:** an open savanna with the boss on the map and a dry-season clock (B), chained hunts with no days (A), a boss-rush arena (C), or a test room first and decide later (D)?
2. **The stalk:** keep it (D, B), or cut it ("picking from a moving herd is the stalk", A)?
3. **What the stick does:** match the animal's heading (A), stay over its spine / shift weight (D), or follow its pattern (C)? And what does the right trigger do: clamp (narrows tolerance), dig claws (spends a grip pool), or a stamina cost? Is there a release button (B)?
4. **The rival fight:** a pure mirrored ride (A, D), or a ride plus authored swipe, lunge and roar moves (B)?
5. **The lion:** a real fantasy worth keeping, or a skin (C)?
