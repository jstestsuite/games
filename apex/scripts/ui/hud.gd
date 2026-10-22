class_name Hud
extends CanvasLayer
## All on-screen UI, built in code: bars, wind compass, messages and overlays
## (title, night trait draft, pause, game over).

signal trait_chosen(trait_id: String)
signal start_pressed

const INK := Color(1.0, 0.97, 0.9)
const SHADOW := Color(0, 0, 0, 0.55)
const HUNGER_COL := Color(0.95, 0.55, 0.22)
const STAMINA_COL := Color(0.98, 0.92, 0.7)

var day_label: Label
var time_bar: Bar
var hunger_bar: Bar
var stamina_bar: Bar
var status_label: Label
var message_label: Label
var compass: WindCompass
var overlay: ColorRect
var overlay_box: VBoxContainer
var _msg_t := 0.0
var _choices: Array[String] = []
var _hud_root: Control


func _ready() -> void:
	layer = 10
	_hud_root = Control.new()
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	day_label = _label(28)
	day_label.position = Vector2(32, 24)
	_hud_root.add_child(day_label)
	time_bar = Bar.new()
	time_bar.color = Color(1, 0.85, 0.55)
	time_bar.size = Vector2(200, 6)
	time_bar.position = Vector2(34, 66)
	_hud_root.add_child(time_bar)

	var bottom := Control.new()
	_place(bottom, Vector2(0, 1), Vector2(32, -110), Vector2(300, 100))
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(bottom)
	hunger_bar = _bar_with_label(bottom, "HUNGER", HUNGER_COL, 0)
	stamina_bar = _bar_with_label(bottom, "STAMINA", STAMINA_COL, 44)

	status_label = _label(20)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(status_label, Vector2(0.5, 1), Vector2(-300, -64), Vector2(600, 30))
	_hud_root.add_child(status_label)

	message_label = _label(34)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(message_label, Vector2(0.5, 0), Vector2(-450, 110), Vector2(900, 50))
	_hud_root.add_child(message_label)

	compass = WindCompass.new()
	_place(compass, Vector2(1, 0), Vector2(-130, 28), Vector2(96, 96))
	_hud_root.add_child(compass)

	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.04, 0.03, 0.06, 0.72)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	overlay_box = VBoxContainer.new()
	overlay_box.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay_box.add_theme_constant_override("separation", 18)
	center.add_child(overlay_box)

	GameState.message.connect(show_message)


func _process(delta: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= delta
		message_label.modulate.a = clampf(_msg_t / 0.6, 0.0, 1.0)


func update_from(player: Cheetah, wind: Vector2) -> void:
	_hud_root.visible = GameState.phase == GameState.Phase.HUNTING
	day_label.text = "DAY %d / %d" % [GameState.day, Tuning.DAYS_PER_SEASON]
	time_bar.value = GameState.day_time / Tuning.DAY_LENGTH
	hunger_bar.value = GameState.hunger / Tuning.HUNGER_MAX
	hunger_bar.warn = GameState.hunger < 25.0
	stamina_bar.value = player.stamina / (Tuning.STAMINA_MAX * GameState.mod("stamina"))
	stamina_bar.warn = player.exhausted
	compass.wind = wind
	compass.cam_yaw = player._cam_yaw

	var bits: Array[String] = []
	if player.state == Cheetah.State.EATING:
		bits.append("EATING")
	elif player.sprinting:
		bits.append("SPRINTING")
	elif player.stalking:
		bits.append("STALKING")
	if player.in_cover:
		bits.append("IN TALL GRASS")
	status_label.text = "  ·  ".join(bits)


func show_message(text: String) -> void:
	message_label.text = text
	_msg_t = 3.0
	message_label.modulate.a = 1.0


# --- overlays ---------------------------------------------------------------------

func hide_overlays() -> void:
	overlay.visible = false


func _clear_overlay() -> void:
	for c in overlay_box.get_children():
		c.queue_free()
	overlay.visible = true


func show_title() -> void:
	_clear_overlay()
	overlay.color = Color(0.04, 0.03, 0.06, 0.35)
	var t := _label(96)
	t.text = "APEX"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(t)
	var sub := _label(24)
	sub.text = "You are a cheetah. Survive %d days on the savanna." % Tuning.DAYS_PER_SEASON
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(sub)
	var help := _label(19)
	help.text = "WASD move   ·   Mouse look   ·   Ctrl stalk   ·   Shift sprint   ·   Space / Click pounce\n" \
		+ "Gazelles see movement and smell you downwind. Use tall grass. Strike when their heads are down.\n" \
		+ "Sprint is short. Get close first."
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.modulate = Color(1, 1, 1, 0.85)
	overlay_box.add_child(help)
	var go := _label(26)
	go.text = "\nPress Enter or click to hunt"
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(go)


func set_paused(p: bool) -> void:
	if p:
		_clear_overlay()
		overlay.color = Color(0.04, 0.03, 0.06, 0.6)
		var t := _label(56)
		t.text = "PAUSED"
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay_box.add_child(t)
		var s := _label(22)
		s.text = "Esc or click to resume"
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay_box.add_child(s)
	else:
		hide_overlays()


func show_night(day: int, kills_today: int, choices: Array[String]) -> void:
	_clear_overlay()
	overlay.color = Color(0.03, 0.03, 0.08, 0.82)
	_choices = choices
	var t := _label(54)
	t.text = "NIGHT %d" % day
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(t)
	var s := _label(22)
	s.text = "%d kill%s today. The night costs %d hunger. Choose an instinct:" % [
		kills_today, "" if kills_today == 1 else "s", int(Tuning.HUNGER_NIGHT_COST * GameState.mod("hunger_drain"))]
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(s)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	overlay_box.add_child(row)
	for i in choices.size():
		var tr: Dictionary = GameState.TRAITS[choices[i]]
		var b := Button.new()
		b.text = "[%d]  %s\n%s" % [i + 1, tr["name"], tr["desc"]]
		b.custom_minimum_size = Vector2(300, 120)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(pick_trait.bind(i))
		row.add_child(b)


func pick_trait(i: int) -> void:
	if i < 0 or i >= _choices.size():
		return
	var id := _choices[i]
	_choices = []
	trait_chosen.emit(id)


func show_end(won: bool, text: String) -> void:
	_clear_overlay()
	overlay.color = Color(0.05, 0.02, 0.02, 0.78) if not won else Color(0.06, 0.05, 0.02, 0.7)
	var t := _label(64)
	t.text = "APEX PREDATOR" if won else "THE SAVANNA WINS"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(t)
	var s := _label(26)
	s.text = text
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(s)
	var r := _label(22)
	r.text = "\nPress R to start a new season"
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(r)


# --- helpers ---------------------------------------------------------------------

## Pin a control to an anchor point of the screen with a pixel offset and size.
func _place(c: Control, anchor: Vector2, offset: Vector2, sz: Vector2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + sz.x
	c.offset_bottom = offset.y + sz.y


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", INK)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar_with_label(parent: Control, text: String, col: Color, y: float) -> Bar:
	var l := _label(15)
	l.text = text
	l.position = Vector2(0, y)
	parent.add_child(l)
	var b := Bar.new()
	b.color = col
	b.position = Vector2(0, y + 22)
	b.size = Vector2(280, 12)
	parent.add_child(b)
	return b


class Bar extends Control:
	var value := 1.0:
		set(v):
			value = clampf(v, 0.0, 1.0)
			queue_redraw()
	var color := Color.WHITE
	var warn := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.45))
		var c := color
		if warn:
			c = Color(1, 0.25, 0.2).lerp(color, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
		draw_rect(Rect2(Vector2(2, 2), Vector2((size.x - 4) * value, size.y - 4)), c)

	func _process(_d: float) -> void:
		if warn:
			queue_redraw()


class WindCompass extends Control:
	## Arrow shows where the wind blows TO, relative to the camera.
	## Stay so the arrow points from the prey toward you (you're downwind).
	var wind := Vector2(1, 0)
	var cam_yaw := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5 - 4.0
		draw_circle(c, r, Color(0, 0, 0, 0.35))
		draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.5), 2.0, true)
		# World wind (x, z) -> screen, rotated by camera yaw so "up" is camera-forward.
		var w3 := Vector3(wind.x, 0, wind.y).rotated(Vector3.UP, -cam_yaw)
		var dir := Vector2(w3.x, w3.z).normalized()
		var tip := c + dir * r * 0.75
		var tail := c - dir * r * 0.75
		draw_line(tail, tip, Color(0.85, 0.95, 1.0), 3.0, true)
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([tip + dir * 6, tip - dir * 10 + side * 8, tip - dir * 10 - side * 8]), Color(0.85, 0.95, 1.0))
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(0, size.y + 18), "WIND", HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(1, 0.97, 0.9))
