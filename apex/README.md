# APEX

A predator roguelite prototype. You're a young lion driven out of your pride. Grow strong, take a pride on day 3, and hold it through the last dusk. A run takes about 10–12 minutes.

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
| Shift | RT | Sprint: a ~2 s charge that fades into a slower run. **While riding: clamp** (analogue on RT) |
| Space | A | Pounce (2 in reserve, they recharge). **Hold** it to stay on in a clinch |
| Left click / F | X | Swipe |
| Right click / Alt | B | Dodge. **While riding: let go** |
| Q | Y | Roar (scatters hyenas, spooks prey). In a practice room: a fresh animal |
| E | RB | Eat a carcass |
| Esc | Start | Pause |
| 1 / 2 / 3 | D-pad left / up / right | Pick a trait at night |
| R | Start / Back | New life (after the run ends). R / Back in a practice room, or while paused: back to the menu |
| W / S, arrows | Left stick, D-pad | Choose on the title menu |
| F1 | | Tuning panel |

## How to play

- **Wind:** watch the compass (top right). The arrow shows where the wind blows; approach so it blows from the prey toward you.
- **Cover:** tall grass hides you. Move while their heads are down.
- **Warnings:** `?` means suspicious, `!` means running.
- **The charge is short.** Get within about 15 m before you sprint. Young (small) animals are slower, and your run can catch them.
- **Riding:** when a pounce lands you're on the animal, and it runs and cuts to throw you.
  - **Staying on:** push the stick to keep your weight over its back. In practice, push toward each cut, and ease off before you swing past.
  - **The warning:** before a cut its head swings and its shoulder drops that way, then a foot plants with a puff of dust. Buffalo often swing the head the wrong way first; the foot never lies.
  - **Wearing it down:** while you're steady its fight (the orange bar) drains. At empty, it goes down.
  - **Grip:** off balance, your grip drains; lose it all and you're thrown and hurt.
  - **Clamp and let go:** clamp (RT / Shift) to finish it faster, but you're easier to throw. Let go (B / right-click) to bail: it stays tired.
- **Practice rooms** (title menu): one animal at a time, a fresh one after each ride, and a log of how each ride went. A debug and learning tool.
- **Pick your fight:** the animal you're facing shows **EASY / FAIR / RISKY / DEADLY**. Zebras are fair on day 1 if you read them; wildebeest are a gamble; buffalo need your pride.
- **Hyenas** shadow you all day and come to your kills. Eat fast, fight them, or roar. When you're full you can keep **gorging**, which turns food into strength.
- **Rival lions:** `!` (yellow) means a swipe is coming, `!!` (red) a lunge. Dodge it. Pounce on him to start a **clinch**: push *with* yellow arrows, *away* from red ones, and pin him.
- **Strength:** eating makes you stronger and darkens your mane. The pride male is strong; you'll need to be too.

## Tuning

Press **F1** in game to change any gameplay number live:
- **Save** keeps your values for next time.
- **Copy changes** copies just the values you changed, ready to share.
- **Reset all** goes back to the defaults in `scripts/autoload/tuning.gd`.

## For development

See `CLAUDE.md` (how to work on it with Claude Code) and `DESIGN.md` (what we're building).
