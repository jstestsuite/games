# CLAUDE.md: Working on APEX

Read `DESIGN.md` first for what the game is and where it's headed.

## Project facts

- **Engine:** Godot 4.5, GDScript, Forward+ renderer. No C#, no plugins yet.
- **Everything is built in code.** `scenes/main.tscn` is a single node, and `scripts/main.gd` builds the world, player, herds and HUD at runtime. Keep it this way unless a scene file clearly helps; text-only makes every change reviewable.
- **Tuning:** every gameplay number lives in `scripts/autoload/tuning.gd` (autoload `Tuning`). Never hard-code a gameplay number elsewhere; add a constant.
- **Traits:** `GameState.TRAITS` in `scripts/autoload/game_state.gd`. A trait is a set of multipliers read through `GameState.mod("key")`.
- **Input** is registered in code (`GameState._setup_input`), not in project.godot.

## Layout

```
scripts/
  main.gd               game flow, day/season loop, spawning, sun and sky
  autoload/tuning.gd    all gameplay constants
  autoload/game_state.gd  run state, traits, input map, signals
  world/terrain.gd      procedural ground, grass, trees, rocks, bounds; height_at(), is_in_tall_grass()
  actors/animal_rig.gd  primitive-mesh animal with procedural gait; animate(delta, speed, speed_norm, crouch, head_down)
  actors/cheetah.gd     player controller and camera (states MOVE/POUNCE/EATING)
  actors/gazelle.gd     prey AI (GRAZE/ALERT/FLEE/DEAD), senses: sight + scent
  actors/herd.gd        herd grouping
  ui/hud.gd             all UI, built in code
shaders/                grass wind shader, procedural animal coat
tests/                  headless checks (see below)
```

Physics layers: 1 = world and cheetah, 2 = prey. The camera spring arm only hits layer 1.

## How to verify changes

Always run these after a change. Godot must be on PATH as `godot` (or use the full path).

```bash
godot --headless --path . --import                                # after adding scripts or class_names
godot --headless --path . -s tests/smoke_test.gd                  # must print SMOKE TEST: PASS
godot --headless --path . --fixed-fps 60 -s tests/hunt_sim.gd     # tuning probe: how hunts play out
godot --path . --fixed-fps 30 -s tests/screenshot.gd              # renders screenshots/ (needs a display)
```

- Look at the screenshots after any visual change.
- Watch for `SCRIPT ERROR` and `Parse Error` in output; a clean run prints none.
- In `-s` test scripts, autoloads are not compile-time globals: use `root.get_node("GameState")` and avoid static types from `class_name` scripts.

## Conventions

- Static typing everywhere (`var x := 1.0`, typed function signatures). Use tabs.
- Smoothing: `lerp(a, b, 1.0 - exp(-k * delta))`, not raw `lerp(a, b, k)`.
- Facing is -Z. Headings are yaw angles: `fwd = Vector3(-sin(h), 0, -cos(h))`, `h = atan2(-dir.x, -dir.z)`.
- Keep gameplay readable: anything prey can sense should have a visible cue.
- Small commits, one idea each. Message format: `area: what changed` (e.g. `gazelle: jink harder when cat is close`).

## Working style with the human

The human playtests; Claude implements. After each change, say in one or two lines what to try in-game to feel the difference. When asked to "tune" something, change values in `tuning.gd`, run `hunt_sim.gd` before and after, and report the difference.

## Don't

- Don't add binary assets without a license note in `assets/CREDITS.md`.
- Don't let the frame budget slip: grass is chunked multimeshes with visibility ranges, so keep new foliage on the same pattern.
- Don't rewrite systems wholesale when a tuning change would do.
