# CLAUDE.md: Working on APEX

Read `DESIGN.md` first for what the game is and where it's headed (its Status section lists known gaps), and `PLAYTEST.md` for what the developer has reported. The repo-level `../NOTES.md` has the overall goal and decision log. No Godot in the container? Run `../tools/get_godot.sh`.

## Project facts

- **Engine:** Godot 4.5, GDScript, Forward+ renderer. No C#, no plugins yet.
- **Everything is built in code.** `scenes/main.tscn` is a single node, and `scripts/main.gd` builds the world, player, herds and HUD at runtime. Keep it this way unless a scene file clearly helps; text-only makes every change reviewable.
- **Tuning:** every gameplay number lives in `scripts/autoload/tuning.gd` (autoload `Tuning`) as an `@export_range` var under an `@export_group`. Never hard-code a gameplay number elsewhere; add a var there and it shows up in the in-game F1 panel automatically. Species values are looked up by prefix (`ZEBRA_SPEED`) through `Prey.p("SPEED")`. The player may have saved overrides in `user://tuning.cfg`; if numbers in game don't match the file, ask whether they pressed Save in the panel.
- **Traits:** `GameState.TRAITS` in `scripts/autoload/game_state.gd`. A trait is a set of multipliers read through `GameState.mod("key")`.
- **Input** is registered in code (`GameState._setup_input`), not in project.godot. Every action has a keyboard/mouse and a controller binding; keep it that way when adding one.

## Layout

```
scripts/
  main.gd               game flow: days, acts (NOMAD/CHALLENGE/PRIDE), spawning, den, hyenas, win/lose, sun and sky
  autoload/tuning.gd    every gameplay number (exported vars), save/load of F1 overrides
  autoload/game_state.gd  run state (act, day, hunger, strength, pride food), traits, input map, signals
  world/terrain.gd      procedural ground, grass, trees, rocks, bounds; height_at(), is_in_tall_grass()
  actors/animal_rig.gd  primitive-mesh animal with procedural gait; animate(), plus paw/lunge poses and a mane
  actors/big_cat.gd     shared lion body: health, strength scaling, take_hit(), movement on terrain
  actors/lion.gd        the player (MOVE/POUNCE/SPRAWL/TAKEDOWN/CLINCH/EATING/SWIPE/DODGE/STAGGER/DOWN) and camera
  actors/grapple.gd     the struggle minigame (lurch tells, grip/progress for prey, balance for clinches)
  actors/rival.gd       rival males: IDLE/STANDOFF/FIGHT/YIELD with telegraphed attacks; clinched = held by the player
  actors/lioness.gd     pride AI: DEN/FOLLOW/HUNT/HOLD/EAT/LEAVE
  actors/prey.gd        prey AI for every species (GRAZE/ALERT/FLEE/DEFEND/GRABBED/DEAD), carcass food
  actors/hyena.gd       the clan: ROAM (shadow you) and carcass thieves: approach, circle, telegraphed darts, scatter
  actors/herd.gd        herd grouping
  ui/hud.gd             all UI, built in code
  ui/tuning_panel.gd    F1 panel generated from Tuning's exported vars
shaders/                grass wind shader, procedural animal coat
tests/                  headless checks (see below)
```

Terrain keeps `obstacles` (trees, rocks, den); use `terrain.avoid()` / `steer_towards()` when an AI moves somewhere.

Physics layers: 1 = world and the player, 2 = prey and hyenas, 4 (layer 3) = other lions. The camera spring arm only hits layer 1. Lions don't collide with prey or each other.

Groups: `player`, `hunter` (things prey fear: player + lionesses), `enemy` (things the player can hit: rivals + hyenas), `rival`, `lioness`, `hyena`, `prey` (alive), `carcass`, `day_actor` (cleared each morning).

## How to verify changes

Always run these after a change. Godot must be on PATH as `godot` (or use the full path).

```bash
godot --headless --path . --import                                # after adding scripts or class_names
godot --headless --path . --fixed-fps 60 -s tests/smoke_test.gd  # a whole life with shortcuts; must print SMOKE TEST: PASS
godot --headless --path . --fixed-fps 60 -s tests/hunt_sim.gd     # tuning probe: chases per species and distance
godot --headless --path . --fixed-fps 60 -s tests/grapple_sim.gd  # tuning probe: grapples by species, strength, helpers
godot --headless --path . --fixed-fps 60 -s tests/fight_sim.gd    # tuning probe: fight win rates by strength match-up
godot --path . --fixed-fps 30 -s tests/screenshot.gd              # renders screenshots/ (needs a display)
```

- Look at the screenshots after any visual change.
- Watch for `SCRIPT ERROR` and `Parse Error` in output; a clean run prints none.
- In `-s` test scripts, autoloads are not compile-time globals: use `root.get_node("GameState")` and avoid static types from `class_name` scripts.
- Probes must hold `GameState.day_time` below `DAY_LENGTH` and reset the phase between runs, or night falls / game over disables controls mid-probe.
- Bots miss exploits humans find (v1's pounce spam). When a probe looks too easy or too hard, also ask "what would a player spam?"
- Grapple/clinch bots: react after a reaction time, right REACT_CHANCE of the time, re-read after a fake-out, and release the stick between lurches.
- No display? `xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --fixed-fps 30 -s tests/screenshot.gd` works but is slow (several minutes).

## Conventions

- Static typing everywhere (`var x := 1.0`, typed function signatures). Use tabs.
- Smoothing: `lerp(a, b, 1.0 - exp(-k * delta))`, not raw `lerp(a, b, k)`.
- Facing is -Z. Headings are yaw angles: `fwd = Vector3(-sin(h), 0, -cos(h))`, `h = atan2(-dir.x, -dir.z)`.
- Keep gameplay readable: anything prey can sense should have a visible cue, and every enemy attack needs a tell (`!` swipe/bite, `!!` lunge/charge).
- Don't override Object's virtuals by accident: `_set`, `_get` and `_notification` are taken (state setters here are `_go`, `_set_state`, `_set_r`).
- Small commits, one idea each. Message format: `area: what changed` (e.g. `gazelle: jink harder when cat is close`).

## Working style with the human

The human playtests; Claude implements. After each change, say in one or two lines what to try in-game to feel the difference. When asked to "tune" something, change values in `tuning.gd`, run `hunt_sim.gd` or `fight_sim.gd` before and after, and report the difference. If the human pastes "Copy changes" output from the F1 panel, apply those values as the new defaults in `tuning.gd`.

Difficulty target: the human's brother likes hard games. Keep it hard but fair: a loss should always be traceable to a visible cue the player missed.

## Don't

- Don't add binary assets without a license note in `assets/CREDITS.md`.
- Don't let the frame budget slip: grass is chunked multimeshes with visibility ranges, so keep new foliage on the same pattern.
- Don't rewrite systems wholesale when a tuning change would do.
