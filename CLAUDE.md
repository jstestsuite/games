# CLAUDE.md: games repo

Game drafts made by the developer (who playtests and decides) and Claude (who implements). The aim is a game the developer's brother finds fun; he likes hard games.

**Start every session by reading `NOTES.md`.** It has the goal, the decision log, the draft index, and how we compare drafts. Then read the `CLAUDE.md` and `DESIGN.md` in the draft you're working on (e.g. `apex/`).

- **Godot isn't preinstalled in cloud sessions.** Run `tools/get_godot.sh` first. It puts `godot` on PATH.
- **Check your work** with `tools/run_tests.sh <draft>` (add `--probes` after balance changes, and commit the updated `tests/results/`).
- **Each draft is a self-contained Godot project in its own folder.** Point commands at it with `--path <draft>`.
- **End of session:** add any decisions to the log in `NOTES.md`, and any playtest feedback to the draft's `PLAYTEST.md`. The next session starts from those files.
- **The developer is Justin.** Their pronouns haven't been stated: use the name, or they/them.
