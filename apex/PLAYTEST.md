# APEX playtest log

Newest first. After a session, add an entry, even a rough one. If you tuned values in the F1 panel, paste the "Copy changes" output too. See `../NOTES.md` for the protocol and the scorecard.

## Template

```
### <date> · <who played> · build <commit>
Runs: <n>   Result of each: <e.g. died day 2 to hyenas, lost challenge, won>
Time per run: <minutes>
Best moment:
Most annoying moment:
Confusing / couldn't read:
Would play again? Why / why not:
Scorecard (1-5): hook _ · one more run _ · fair deaths _ · mastery _ · moments _ · variety _
F1 changes:
<paste>
Ideas:
```

## What to watch for in the grapple playtest (v3, session 2)

- **The grapple:** still fun on the tenth animal? Can you read the arrow in time on a controller? Do fake-outs feel fair or cheap?
- **Tiers:** is a day-1 zebra a fair test, a day-1 wildebeest a real gamble, and a solo buffalo clearly a bad idea? Did the risk label help you choose?
- **Clinch:** does it feel different from prey? Is "push away from red" readable?
- **Pounce reserve:** is 2 pounces right? Does the sprawl on a miss feel punishing or annoying?
- **Danger:** did kicks, throws, injuries and buffalo charges make hunting feel risky?
- **Hyenas:** pressure now, or still nothing?
- **Food:** did you ever feel hungry? Did gorging matter?
- **Run length** at 4 days: too short now?

## What to watch for in the first lion playtest (v2, done)

These are the open risks. Each one is a guess until someone plays.

- **Charge, then run:** does the burst feel explosive, and does the run phase ever feel useful (young animals, herding prey into lionesses)?
- **Takedowns:** is holding the pounce button tense or just a chore?
- **Hyenas:** pressure or nuisance? Is roaring too strong or too weak?
- **Challenge fight:** can you read `!` and `!!` in time? Is the pride male a fair wall or a cheap one? Bots say a lion slightly weaker than him wins ~40%.
- **Pride day:** do the lionesses feel like *your* pride, or like they play for you?
- **Length:** is a full run about 15 minutes? Does any day drag?
- **Controller:** it's only been tested with simulated input. Check that it feels right on a real pad: stick deadzone, look speed (`PAD_LOOK_SPEED` in F1).

## Entries

### 2026-10-22 · developer · lion v2 (`daaa9fb`), controller
Verdict: "needs a lot of work, wouldn't call it super fun." Learning the hold-A takedown was fun the first couple of times. After that it was repetitive and simple.
- Prey sometimes get stuck running in circles.
- You can chase down anything.
- More food than you can eat.
- You can just pounce on the opposing lion; spamming pounce kills lions.
- A `?` hangs over dead prey. It looks intentional, but should probably be a different marker.
- Expected danger from the animals (getting kicked, etc.); didn't feel any.
- Hyenas did nothing: easy to kill, and the meal was finished before they arrived.
- Prey and lionesses collide badly with rocks.

Causes found in the code afterwards:
- The `?` bug: the takedown calls `die()` mid-frame, then the same frame's visual update re-shows the awareness marker.
- Pounce stun-locks rivals: the cooldown (0.9 s) barely outlasts the stagger (0.6 s), so he never finishes a windup. The fight bot only swiped, so it never found this.
- Pounce is as fast as running, with no hunger cost and no winding.
- Kicks happen but are tiny: zebra 10 damage, about one per takedown, and health regenerates.
- Eating a zebra takes about 8 s; hyenas arrive after 14 s.
- No obstacle avoidance: animals steer straight into rocks and trees (which do have colliders) and scrape along them, which is likely the circling.
- Follow-up (v3, found by the new soak test): the circling was mostly in **map corners**. "Flee from the lion" and "stay off the rim" cancelled out, and the animal re-picked which way to slide along the rim every frame, so it dithered in place for up to 50 s. Fixed by committing to a side until clear and starting the edge zone earlier. The soak test now fails if any fleeing animal goes nowhere for 3 s.

### 2026-10-22 · developer · cheetah v1 (`504b85c`)
- Sprint never fully used the stamina bar, and it didn't seem necessary given the cooldown. Suggested either a constantly draining sprint or relying on the cooldown alone.
- Unsure this style fits a roguelike. Suggested a lion whose goal is to become head of the pride.
- Outcome: tried a day-long stamina budget (`aac0794`), then pivoted to the lion game (`daaa9fb`).
