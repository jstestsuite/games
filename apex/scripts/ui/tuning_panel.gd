extends CanvasLayer
## In-game tuning panel (F1). Lists every value in Tuning, grouped as in tuning.gd,
## with a search box. Changes apply immediately; "Save" writes them to user://tuning.cfg
## so they load next time. Changed values are shown in gold.

signal restart_requested

const GOLD := Color(1.0, 0.82, 0.35)

var _root: PanelContainer
var _list: VBoxContainer
var _search: LineEdit
var _status: Label
var _rows: Array[Dictionary] = []   # {name, row: Control, label: Label, input: Control, group: String}
var _was_paused := false
var _was_mouse := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = PanelContainer.new()
	_root.anchor_left = 1.0
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.offset_left = -560
	_root.offset_top = 12
	_root.offset_right = -12
	_root.offset_bottom = -12
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.07, 0.94)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	_root.add_theme_stylebox_override("panel", sb)
	add_child(_root)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_root.add_child(v)
	var title := Label.new()
	title.text = "TUNING  (F1 to close)"
	title.add_theme_font_size_override("font_size", 22)
	v.add_child(title)

	_search = LineEdit.new()
	_search.placeholder_text = "Search (e.g. hyena, charge, zebra)"
	_search.text_changed.connect(_filter)
	v.add_child(_search)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	v.add_child(buttons)
	_button(buttons, "Save", _save)
	_button(buttons, "Copy changes", _copy)
	_button(buttons, "Reset all", _reset)
	_button(buttons, "Restart run", func(): restart_requested.emit())

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 14)
	_status.modulate = Color(1, 1, 1, 0.75)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_build_rows()
	_root.visible = false
	_update_status("Changes apply live. Save to keep them next time. Groups marked (restart) need Restart run.")


func _button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("tuning"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	var open := not _root.visible
	if open:
		_was_paused = get_tree().paused
		_was_mouse = Input.mouse_mode
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_values()
	else:
		get_tree().paused = _was_paused
		Input.mouse_mode = _was_mouse
		_search.release_focus()
	_root.visible = open


func _build_rows() -> void:
	var group := ""
	for prop in Tuning.get_script().get_script_property_list():
		if prop.usage & PROPERTY_USAGE_GROUP:
			group = prop.name
			var h := Label.new()
			h.text = group.to_upper()
			h.add_theme_font_size_override("font_size", 16)
			h.add_theme_color_override("font_color", GOLD)
			_list.add_child(h)
			_rows.append({"name": "", "row": h, "group": group, "header": true})
			continue
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_EDITOR):
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = prop.name
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 14)
		label.clip_text = true
		row.add_child(label)
		var input: Control
		if prop.type == TYPE_BOOL:
			var cb := CheckBox.new()
			cb.toggled.connect(_on_changed.bind(prop.name))
			input = cb
		else:
			var sp := SpinBox.new()
			sp.custom_minimum_size = Vector2(150, 0)
			sp.allow_greater = true
			sp.allow_lesser = true
			if prop.hint == PROPERTY_HINT_RANGE:
				var parts: PackedStringArray = prop.hint_string.split(",")
				if parts.size() >= 2:
					sp.min_value = float(parts[0])
					sp.max_value = float(parts[1])
				if parts.size() >= 3:
					sp.step = float(parts[2])
			if prop.type == TYPE_INT:
				sp.step = maxf(1.0, sp.step)
				sp.rounded = true
			sp.value_changed.connect(_on_changed.bind(prop.name))
			input = sp
		row.add_child(input)
		var reset := Button.new()
		reset.text = "def"
		reset.tooltip_text = "Back to default"
		reset.pressed.connect(_reset_one.bind(prop.name))
		row.add_child(reset)
		_list.add_child(row)
		_rows.append({"name": prop.name, "row": row, "label": label, "input": input, "group": group, "type": prop.type})


var _syncing := false


func _refresh_values() -> void:
	_syncing = true
	for r in _rows:
		if r.name == "":
			continue
		var val: Variant = Tuning.get(r.name)
		if r.input is CheckBox:
			(r.input as CheckBox).button_pressed = val
		else:
			(r.input as SpinBox).value = float(val)
		_mark(r)
	_syncing = false


func _mark(r: Dictionary) -> void:
	var changed: bool = Tuning.get(r.name) != Tuning.default_of(r.name)
	(r.label as Label).add_theme_color_override("font_color", GOLD if changed else Color(1, 1, 1, 0.9))


func _on_changed(value: Variant, param: String) -> void:
	if _syncing:
		return
	for r in _rows:
		if r.name == param:
			var v: Variant = value
			if r.type == TYPE_INT:
				v = int(round(float(value)))
			elif r.type == TYPE_FLOAT:
				v = float(value)
			Tuning.set_param(param, v)
			_mark(r)
			break
	_update_status("%d value(s) differ from defaults (not saved yet)." % Tuning.changed_params().size())


func _reset_one(param: String) -> void:
	Tuning.set_param(param, Tuning.default_of(param))
	_refresh_values()


func _filter(text: String) -> void:
	var q := text.strip_edges().to_lower()
	for r in _rows:
		if q == "":
			r.row.visible = true
		elif r.name == "":
			r.row.visible = (r.group as String).to_lower().contains(q)
		else:
			r.row.visible = (r.name as String).to_lower().contains(q) or (r.group as String).to_lower().contains(q)


func _save() -> void:
	Tuning.save_overrides()
	_update_status("Saved %d change(s) to %s." % [Tuning.changed_params().size(), ProjectSettings.globalize_path(Tuning.SAVE_PATH)])


func _copy() -> void:
	DisplayServer.clipboard_set(Tuning.changes_as_text())
	_update_status("Copied %d change(s) to the clipboard." % Tuning.changed_params().size())


func _reset() -> void:
	Tuning.reset_all()
	_refresh_values()
	_update_status("Everything is back to the defaults in tuning.gd (saved file removed).")


func _update_status(t: String) -> void:
	_status.text = t
