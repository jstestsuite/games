# APEX

A predator roguelite prototype. You're a cheetah. Survive five days on the savanna.

## Run it

1. Install **Godot 4.5** (standard version, not .NET) from godotengine.org.
2. Open Godot, click **Import**, and choose this folder's `project.godot`.
3. Press **F5** to play.

## Controls

| Key | Action |
|---|---|
| WASD | Move (you steer a heading; you don't strafe) |
| Mouse | Camera |
| Ctrl (or C) | Stalk: slow, low, quiet |
| Shift | Sprint: very fast, spends a day-long stamina budget (about 14 s) |
| Space / Left click | Pounce |
| Esc | Pause |
| 1 / 2 / 3 | Pick a trait at night |
| R | New season (after game over) |

## How to hunt

- Watch the **wind compass** (top right). The arrow shows where the wind blows. Approach so the wind blows from the gazelles toward you.
- **Tall grass** hides you. The HUD says when you're in it.
- Gazelles alternate heads-down grazing and heads-up watching. Move while their heads are down.
- `?` means a gazelle is suspicious. `!` means it's running, and it will spook the rest.
- Get within roughly 15 m before you sprint. Pounce when you're right behind it.

## For development

See `CLAUDE.md` (how to work on it with Claude Code) and `DESIGN.md` (what we're building).
