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

## What to watch for in the first lion playtest

These are the open risks. Each one is a guess until someone plays.

- **Charge, then run:** does the burst feel explosive, and does the run phase ever feel useful (young animals, herding prey into lionesses)?
- **Takedowns:** is holding the pounce button tense or just a chore?
- **Hyenas:** pressure or nuisance? Is roaring too strong or too weak?
- **Challenge fight:** can you read `!` and `!!` in time? Is the pride male a fair wall or a cheap one? Bots say a lion slightly weaker than him wins ~40%.
- **Pride day:** do the lionesses feel like *your* pride, or like they play for you?
- **Length:** is a full run about 15 minutes? Does any day drag?
- **Controller:** it's only been tested with simulated input. Check that it feels right on a real pad: stick deadzone, look speed (`PAD_LOOK_SPEED` in F1).

## Entries

### 2026-10-22 · developer · cheetah v1 (`504b85c`)
- Sprint never fully used the stamina bar, and it didn't seem necessary given the cooldown. Suggested either a constantly draining sprint or relying on the cooldown alone.
- Unsure this style fits a roguelike. Suggested a lion whose goal is to become head of the pride.
- Outcome: tried a day-long stamina budget (`aac0794`), then pivoted to the lion game (`daaa9fb`).
