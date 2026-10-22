extends RefCounted
## Saves a probe's results to tests/results/<name>.txt, headed with the date, the git
## commit and any tuning values that differ from tuning.gd (from the F1 panel's saved
## file), so runs can be compared across sessions with `git log -p tests/results/`.

static func save(tree: SceneTree, name: String, lines: Array[String]) -> void:
	var tuning := tree.root.get_node("Tuning")
	var out := PackedStringArray()
	out.append("# %s" % name)
	out.append("date:   %s" % Time.get_datetime_string_from_system(true, true))
	out.append("commit: %s" % _commit())
	var changes: String = tuning.changes_as_text()
	out.append("tuning: %s" % ("defaults from tuning.gd" if changes.begins_with("(no changes") else "OVERRIDES ACTIVE:"))
	if not changes.begins_with("(no changes"):
		for l in changes.split("\n"):
			out.append("  " + l)
	out.append("")
	out.append_array(lines)
	DirAccess.make_dir_recursive_absolute("res://tests/results")
	var f := FileAccess.open("res://tests/results/%s.txt" % name, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(out) + "\n")
		print("saved tests/results/%s.txt" % name)


static func _commit() -> String:
	var output := []
	var code := OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "--short", "HEAD"], output)
	if code != 0 or output.is_empty():
		return "unknown"
	var dirty := []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "status", "--porcelain", "--", "."], dirty)
	var hash := (output[0] as String).strip_edges()
	return hash + (" (with uncommitted changes)" if not dirty.is_empty() and (dirty[0] as String).strip_edges() != "" else "")
