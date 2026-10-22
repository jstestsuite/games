# Project notes

Shared memory between sessions: what we're trying to make, what we've decided and why, and how we'll pick between drafts. Update it at the end of every session. Each draft's own `DESIGN.md` covers that game in detail.

## The goal

**Make a game the developer's brother considers fun and worth playing.**

- **He likes hard games.** That's the main thing we know about his taste so far. Still worth finding out: which games he plays and loves, whether he plays on keyboard or controller, and solo or co-op.
- **Approach:** build a few rough, playable drafts, playtest them, then narrow down to one and polish it. Drafts should be cheap. Prove the core 30-second loop is fun before building anything on top of it.
- **Roles:** the developer playtests and sets direction. Claude implements, tunes with automated probes, and says after each change what to try in game.

## What "fun for him" probably means

This is our working guess. Confirm or correct it after he plays.

- **Hard but fair.** Every loss should trace back to a cue he could have read. Cheap deaths kill hard games.
- **Short runs, one more go.** About 15 minutes per run (the developer's target).
- **Skill expression.** Run 5 should look visibly better than run 1.
- **Runs that differ.** Choices in a run (traits, targets, risks) should change how it plays.
- **Stories.** Moments he'd want to tell someone about ("my lionesses and I took down a buffalo").

## Draft index

| Draft | Where | Status | Pitch |
|---|---|---|---|
| APEX v1: cheetah | `apex/` at commit `aac0794` (`git checkout aac0794 -- apex` to restore) | Superseded | Cheetah survives a 5-day season: stalk, sprint, pounce. Traits each night. |
| APEX v2: lion | `apex/` at commit `4149fac` | Played once: "needs a lot of work". Only the hold-to-grip takedown was fun | Young lion: hunt to grow strong, win a pride, hold it through the last dusk. |
| APEX v3: lion + grapple | `apex/` (current, `039dc8a`) | Played once: "we went backwards". The arrow quiz isn't the "follow the prey" the developer asked for, the lion fight wasn't understood, and the hyenas added nothing | v2 rebuilt around a grapple minigame for every kill and lion fight, prey as difficulty tiers, real danger, scarcity, a hyena clan. |

Feedback on v1: the stamina bar never fully emptied and didn't seem necessary given the cooldown, and the game didn't clearly fit a roguelike. That led to the lion pivot.

Feedback on v2: repetitive and simple. You could chase down and pounce-spam anything, food was plentiful, there was no danger from animals, hyenas did nothing, and prey snagged on rocks. The one fun part was learning the hold-A takedown. That led to v3. Details are in `apex/PLAYTEST.md`.

Feedback on v3: the developer wanted continuous tracking ("follow the prey" with a catch meter and a soft magnet), not an arrow quiz. They didn't get the lion fight, and the hyenas added nothing. They paused all changes to ask what the game is missing. A four-agent design panel answered: the idea is fine, but the verb and the process are wrong. Its proposal is a greybox "ride" test room next. See `design-panel-2026-10-22.md`. **This is awaiting the developer's call.**

**Lesson so far:** the fun shows up where there's a skill to learn under pressure (the grapple), not in systems that run themselves. Build depth into the moment-to-moment verbs before adding more systems. Also: build what the developer described, in their terms (feel, not a system with a HUD prompt), and change one thing per build so each can be judged.

## Decision log

Newest first. Say who decided, so later sessions know what's settled and what's open.

| Date | Decision | Who / why |
|---|---|---|
| 2026-10-22 | The level select is a **debug tool** (e.g. a slow zebra in an empty room, a waiting boss), not a player mode. The node map is **rejected**: don't copy another game's structure; make something unique. The run shape is open again, to be decided after the ride is felt | Justin |
| 2026-10-22 | **Proposed by the panel (session 2), awaiting Justin:**<br>- a node map of small hunt arenas<br>- the pride male reachable at any time<br>- growth by body, not a menu, held behind a toggle until Justin says yes<br>- the build order: Ride Room + level select, then Species Trials, then a thin run spine | Brother's library (Diceomancer, Drop Duchy, Dead Cells, Mewgenics, Satisfactory, Caves of Qud) says build-craft and decisions matter. See `design-panel-2026-10-22.md` |
| 2026-10-22 | Each run is self-contained, with no roguelike traits. Level select with test rooms for each feature. Don't ask the brother anything: the plan is to wow him | Justin |
| 2026-10-22 | Justin isn't committed to the lion idea. Scrapping it and starting over is fine if a better idea comes up | Justin, after the v3 playtest |
| 2026-10-22 | **On hold:** no game changes until we agree on what's missing. A design panel proposed a greybox "ride" test room, cutting most of v3's systems, and asking the brother 5 questions first | Developer paused after the v3 playtest. The proposal is in `design-panel-2026-10-22.md`, not yet accepted |
| 2026-10-22 | At most 2 hyenas wind up or dart at once; the clan grows by 0.5 per day, not 1 | The soak test showed 7 hyenas biting together killed a strong lion in ~25 s: unreadable, not hard-but-fair |
| 2026-10-22 | Test kit: soak test, input test, saved probe results, `tools/run_tests.sh`, GitHub check on push | Developer: "anything useful for future development" |
| 2026-10-22 | **v3: every kill and lion fight is a grapple minigame**: hold pounce and push the stick with each telegraphed lurch, with a slow-mo zoom on the grab | Developer liked the idea ("a possible winner"), building on the one fun part of v2 |
| 2026-10-22 | Rival clinches use the grapple, but differently: a balance tug-of-war; yellow = push with it, red = push away | Developer: "should be a little different than prey" |
| 2026-10-22 | Species are difficulty tiers (warthog < zebra < wildebeest < buffalo), with a risk label | Developer: a day-1 wildebeest should be risky, a zebra a doable challenge, and by the end doable with the pride |
| 2026-10-22 | Cut a day: 2 nomad days, then challenge, then pride (4 days, 150 s each) | Developer |
| 2026-10-22 | Pounces come from a reserve of 2 (recharging), and a miss sprawls you | Fixes pounce spam. Making pounce cost charge was rejected, because a full burst would leave nothing to pounce with |
| 2026-10-22 | Scarcity (faster hunger, wary herds), gorging into strength, a roaming hyena clan, obstacle avoidance | v2 feedback |
| 2026-10-22 | Notes, playtest log and `tools/get_godot.sh` added | So each session starts where the last one stopped |
| 2026-10-22 | Controller support for every action | Developer asked |
| 2026-10-22 | Default tuning is **hard** (a weaker lion loses the challenge ~80% of the time) | Brother likes hard games |
| 2026-10-22 | Every gameplay number is tunable in game (F1 panel) | Developer wants to try many difficulty changes themselves |
| 2026-10-22 | Run length about 15 minutes or less | Developer |
| 2026-10-22 | Losing the challenge fight ends the run "for now". The alternative was going back to nomad life | Developer. Revisit after playtests |
| 2026-10-22 | Sprint = short burst, then a slower sustained run. The stamina bar is removed | Developer's call. Claude suggested "top speed fades" |
| 2026-10-22 | Pivot from cheetah to lion: become head of the pride. Three acts: nomad, challenge, pride | Developer's idea. It gives the run a goal and a boss fight |
| 2026-10-22 | (v1) Stamina became a day-long budget | Tried after the v1 feedback; dropped in the pivot |

## How we'll compare drafts

After each playtest, score the draft from 1 to 5 on each question:

| Question | What to look for |
|---|---|
| **Hook** | Did he understand what to do in the first 2 minutes without help? |
| **One more run** | Did he restart without being asked? |
| **Fair deaths** | When he lost, could he say why? |
| **Mastery** | Did he get visibly better across runs? |
| **Moments** | Did he react out loud (laugh, swear, cheer)? |
| **Variety** | Did run 3 feel different from run 1? |
| **Build cost** | How much work would it take to make this good? (Our side, not his.) |

The draft that wins on hook, one more run and fair deaths is the one to polish. Art and audio can come later.

## Playtest protocol

1. **Don't coach the first run.** Note where he gets stuck or confused; that's a readability bug.
2. **Write down:**
   - time to his first kill or success;
   - each death and its cause;
   - when he reacted out loud;
   - what he asked.
3. **Afterwards, ask:**
   - What was the best moment?
   - What was the most annoying moment?
   - Would you play again? What would make you?
4. **If you changed numbers in the F1 panel,** press "Copy changes" and paste the result into the next session. Claude will make them the new defaults.
5. **Log it** in the draft's `PLAYTEST.md` and paste or summarise it at the start of the next session.

## Ideas for other drafts

These came from the first brainstorm and haven't been built.

- **Cheetah with a territory map.** Restore v1 and add a branching map (plains, riverbank, hyena country, drought valley), plus traits that change rules rather than stats. Cheap, because v1 exists.
- **Life cycle.** Cub, then adult, then old. You win by raising a litter, and a surviving cub passes a trait to the next run.
- **Coalition brothers co-op.** Two male lions, one per player. Real male lion coalitions are often brothers, which fits the audience. Online play is a big build; local split screen (two SubViewports) is cheaper.
- **Other predators** as separate drafts or as unlocks:
  - leopard: stealth, trees, stashing kills;
  - wolf: weak alone, recruits a pack;
  - crocodile: ambush at the water.

## Starting a new draft

- **Folder:** a new folder at the repo root (`<name>/`) with its own `project.godot`, `CLAUDE.md`, `DESIGN.md`, `README.md` and `PLAYTEST.md`.
- **Reuse from `apex/`, since these patterns already work:**
  - `scripts/autoload/tuning.gd`: exported vars, plus save/load of overrides;
  - `scripts/ui/tuning_panel.gd`: the F1 panel, built automatically from those vars;
  - input set up in code with keyboard **and** controller bindings (`game_state.gd`);
  - `tests/smoke_test.gd`, plus probe bots like `hunt_sim.gd` and `fight_sim.gd` for tuning without a human;
  - `world/terrain.gd` and `actors/animal_rig.gd` for savanna and animal drafts.
- **Make the core loop fun first.** Only then add meta layers.
- **Add the draft** to the index above and to the root `README.md`.

## Notes for Claude sessions

- **Install Godot first:** run `tools/get_godot.sh`. A fresh cloud container doesn't have it.
- **Run every check:** `tools/run_tests.sh <draft>` (add `--probes` for the balance probes, `--shots` for screenshots). GitHub runs the checks on every push.
- **Probe results are committed** in `<draft>/tests/results/`. Each file is stamped with the date, commit and any tuning overrides. `git log -p` on that folder is the balance history.
- **Screenshots without a display:** use `xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --fixed-fps 30 -s tests/screenshot.gd`.
  - It's slow: about 1 minute per shot with software rendering, so give it a 10-minute timeout.
  - Errors about `VK_KHR_surface` and "Screen space AA ... Compatibility renderer" are expected there and harmless.
- **Probe bots lie** if state leaks between runs (night falling, game over disabling controls, sprint state carrying over). Reset everything per run, and sanity-check surprising results by running one scenario alone.
- **Probe bots aren't humans.** The fight bot uses a 0.28 s reaction time and dodges 70% of warnings, roughly a decent player. Treat its win rates as relative, not absolute.
- **Work happens on `claude/*` branches.** No pull request has been opened yet; ask before opening one.
