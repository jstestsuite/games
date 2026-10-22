# APEX

A predator roguelite prototype. You're a young lion driven out of your pride. Grow strong, take a pride on day 4, and hold it through the last dusk. A run takes about 15 minutes.

## Run it

1. Install **Godot 4.5** (standard version, not .NET) from godotengine.org.
2. Open Godot, click **Import**, and choose this folder's `project.godot`.
3. Press **F5** to play.

## Controls

| Keyboard / mouse | Controller (Xbox layout) | Action |
|---|---|---|
| WASD | Left stick | Move (you steer a heading; you don't strafe) |
| Mouse | Right stick | Camera |
| Ctrl (or C) | LT | Stalk: slow, low, quiet |
| Shift | RT | Sprint: a ~2 s charge that fades into a slower run |
| Space | A | Pounce. **Hold** it to keep your grip in a takedown |
| Left click / F | X | Swipe |
| Right click / Alt | B | Dodge |
| Q | Y | Roar (scatters hyenas, spooks prey) |
| E | RB | Eat a carcass |
| Esc | Start | Pause |
| 1 / 2 / 3 | D-pad left / up / right | Pick a trait at night |
| R | Start | New life (after the run ends) |
| F1 | | Tuning panel |

## How to play

- **Wind:** watch the compass (top right). The arrow shows where the wind blows; approach so it blows from the prey toward you.
- **Cover:** tall grass hides you. Move while their heads are down.
- **Warnings:** `?` means suspicious, `!` means running.
- **The charge is short.** Get within about 20 m before you sprint. Young (small) animals are slower, and your run can catch them.
- **Takedowns:** after the pounce lands, hold the button until the animal goes down. Buffalo fight back.
- **Hyenas** come to your kills. Eat fast, fight them, or roar.
- **Rival lions:** `!` (yellow) means a swipe is coming, `!!` (red) a lunge. Dodge, and punish him while he recovers.
- **Strength:** eating makes you stronger and darkens your mane. The pride male is strong; you'll need to be too.

## Tuning

Press **F1** in game to change any gameplay number live:
- **Save** keeps your values for next time.
- **Copy changes** copies just the values you changed, ready to share.
- **Reset all** goes back to the defaults in `scripts/autoload/tuning.gd`.

## For development

See `CLAUDE.md` (how to work on it with Claude Code) and `DESIGN.md` (what we're building).
