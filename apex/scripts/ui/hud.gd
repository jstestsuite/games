class_name Hud
extends CanvasLayer
## All on-screen UI, built in code: bars, charge ring, wind compass, rival health,
## messages and overlays (title, night trait draft, pause, game over).

signal trait_chosen(trait_id: String)
signal start_pressed

const INK := Color(1.0, 0.97, 0.9)
const SHADOW := Color(0, 0, 0, 0.55)
const HEALTH_COL := Color(0.9, 0.3, 0.25)
const HUNGER_COL := Color(0.95, 0.55, 0.22)
const STRENGTH_COL := Color(0.85, 0.7, 0.4)
const GOLD := Color(1.0, 0.82, 0.35)

var main: Node   # main.gd, for the focus rival and den position
var day_label: Label
var objective_label: Label
var time_bar: Bar
var health_bar: Bar
var hunger_bar: Bar
var strength_bar: Bar
var strength_label: Label
var charge_ring: ChargeRing
var status_label: Label
var hint_label: Label
var message_label: Label
var compass: WindCompass
var rival_box: Control
var rival_name: Label
var rival_bar: Bar
var grip_box: Control
var grip_bar: Bar
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
	time_bar.size = Vector2(240, 6)
	time_bar.position = Vector2(34, 66)
	_hud_root.add_child(time_bar)
	objective_label = _label(18)
	objective_label.position = Vector2(34, 80)
	objective_label.modulate = Color(1, 1, 1, 0.9)
	_hud_root.add_child(objective_label)

	var bottom := Control.new()
	_place(bottom, Vector2(0, 1), Vector2(32, -160), Vector2(300, 150))
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(bottom)
	health_bar = _bar_with_label(bottom, "HEALTH", HEALTH_COL, 0)
	hunger_bar = _bar_with_label(bottom, "HUNGER", HUNGER_COL, 44)
	strength_bar = _bar_with_label(bottom, "STRENGTH", STRENGTH_COL, 88)
	strength_label = bottom.get_child(bottom.get_child_count() - 2) as Label

	charge_ring = ChargeRing.new()
	_place(charge_ring, Vector2(0.5, 1), Vector2(-28, -140), Vector2(56, 56))
	_hud_root.add_child(charge_ring)

	status_label = _label(20)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(status_label, Vector2(0.5, 1), Vector2(-300, -64), Vector2(600, 30))
	_hud_root.add_child(status_label)
	hint_label = _label(18)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.modulate = Color(1, 1, 1, 0.8)
	_place(hint_label, Vector2(0.5, 1), Vector2(-300, -36), Vector2(600, 26))
	_hud_root.add_child(hint_label)

	message_label = _label(34)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(message_label, Vector2(0.5, 0), Vector2(-450, 150), Vector2(900, 50))
	_hud_root.add_child(message_label)

	rival_box = Control.new()
	rival_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(rival_box, Vector2(0.5, 0), Vector2(-220, 26), Vector2(440, 80))
	_hud_root.add_child(rival_box)
	rival_name = _label(20)
	rival_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rival_name.size = Vector2(440, 28)
	rival_box.add_child(rival_name)
	rival_bar = Bar.new()
	rival_bar.color = Color(0.85, 0.25, 0.2)
	rival_bar.position = Vector2(0, 32)
	rival_bar.size = Vector2(440, 14)
	rival_box.add_child(rival_bar)

	grip_box = Control.new()
	grip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(grip_box, Vector2(0.5, 0.5), Vector2(-160, 70), Vector2(320, 50))
	_hud_root.add_child(grip_box)
	var gl := _label(18)
	gl.text = "HOLD SPACE / A"
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.size = Vector2(320, 24)
	grip_box.add_child(gl)
	grip_bar = Bar.new()
	grip_bar.color = Color(1.0, 0.9, 0.6)
	grip_bar.position = Vector2(0, 28)
	grip_bar.size = Vector2(320, 12)
	grip_box.add_child(grip_bar)

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


func update_from(player: Lion, wind: Vector2) -> void:
	_hud_root.visible = GameState.phase == GameState.Phase.HUNTING
	var acts := ["NOMAD", "CHALLENGE", "PRIDE"]
	day_label.text = "DAY %d / %d  ·  %s" % [GameState.day, GameState.last_day(), acts[GameState.act]]
	time_bar.value = GameState.day_time / Tuning.DAY_LENGTH
	objective_label.text = _objective()

	health_bar.value = player.health / player.health_max()
	health_bar.warn = player.health < player.health_max() * 0.3
	hunger_bar.value = GameState.hunger / Tuning.HUNGER_MAX
	hunger_bar.warn = GameState.hunger < Tuning.HUNGER_MAX * 0.25
	strength_bar.value = GameState.mane_darkness()
	strength_label.text = "STRENGTH  %.2f" % GameState.strength

	charge_ring.value = player.charge / maxf(0.01, player.max_charge())
	charge_ring.winded = player.winded_t > 0.0
	charge_ring.bursting = player.bursting

	compass.wind = wind
	compass.cam_yaw = player._cam_yaw
	compass.show_den = GameState.act == GameState.Act.CHALLENGE or GameState.act == GameState.Act.PRIDE
	if main:
		var to: Vector3 = main.den - player.global_position
		compass.den_dir = Vector2(to.x, to.z)

	var bits: Array[String] = []
	match player.state:
		Lion.State.EATING:
			if is_instance_valid(player.eat_target):
				bits.append("EATING  (%d food left)" % int(player.eat_target.food_left))
		Lion.State.TAKEDOWN:
			bits.append("TAKEDOWN")
		Lion.State.STAGGER:
			bits.append("STAGGERED")
		Lion.State.DODGE:
			bits.append("DODGE")
		_:
			if player.bursting:
				bits.append("CHARGING")
			elif player.sprinting:
				bits.append("RUNNING")
			elif player.winded_t > 0.0:
				bits.append("WINDED")
			elif player.stalking:
				bits.append("STALKING")
	if player.in_cover:
		bits.append("IN TALL GRASS")
	status_label.text = "  ·  ".join(bits)

	var hints: Array[String] = []
	if player.state == Lion.State.MOVE and player._nearest_carcass(3.5) != null:
		hints.append("E / RB  eat")
	if get_tree().get_nodes_in_group("hyena").size() > 0:
		hints.append("Q / Y  roar%s" % ("" if player.roar_cd <= 0.0 else " (%.0f)" % player.roar_cd))
	hint_label.text = "     ".join(hints)

	grip_box.visible = player.state == Lion.State.TAKEDOWN and is_instance_valid(player.grab_target)
	if grip_box.visible:
		grip_bar.value = player.grab_target.takedown

	var r: Rival = main.focus_rival() if main else null
	rival_box.visible = r != null
	if r:
		var cmp := ""
		var ratio := r.strength / maxf(0.01, GameState.strength)
		if ratio > 1.15:
			cmp = "stronger than you"
		elif ratio < 0.87:
			cmp = "weaker than you"
		else:
			cmp = "evenly matched"
		rival_name.text = "%s  ·  %s" % [r.title.to_upper(), cmp]
		rival_bar.value = r.health / r.health_max()


func _objective() -> String:
	match GameState.act:
		GameState.Act.NOMAD:
			return "Eat and grow strong before the challenge on day %d." % GameState.challenge_day()
		GameState.Act.CHALLENGE:
			return "Defeat the pride male at the rocks (gold arrow on the compass)."
		_:
			var s := "Pride fed: %d / %d  ·  %d lioness%s" % [int(GameState.pride_food), int(Tuning.PRIDE_FOOD_NEED),
				GameState.lionesses, "" if GameState.lionesses == 1 else "es"]
			if GameState.day >= GameState.last_day():
				s += "\nChallengers come at dusk."
			return s


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


func _centered(text: String, font_size: int, alpha := 1.0) -> Label:
	var l := _label(font_size)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.modulate = Color(1, 1, 1, alpha)
	overlay_box.add_child(l)
	return l


func show_title() -> void:
	_clear_overlay()
	overlay.color = Color(0.04, 0.03, 0.06, 0.35)
	_centered("APEX", 96)
	_centered("You are a young lion, driven out of your pride.\nGrow strong. Take a pride on day %d. Hold it until your cubs are safe." % GameState.challenge_day(), 24)
	_centered("WASD move  ·  Mouse look  ·  Ctrl stalk  ·  Shift charge, then run  ·  Space pounce (hold to grip)\n" \
		+ "Left click / F swipe  ·  Right click / Alt dodge  ·  Q roar  ·  E eat  ·  F1 tuning\n" \
		+ "Controller: sticks move and look  ·  RT charge  ·  LT stalk  ·  A pounce  ·  X swipe  ·  B dodge  ·  Y roar  ·  RB eat\n" \
		+ "Prey see movement and smell you downwind. Use tall grass. Your burst is short: get close first.\n" \
		+ "In a fight, \"!\" means a swipe is coming and \"!!\" a lunge. Dodge, or hit him first to stagger him.", 18, 0.85)
	_centered("\nPress Enter, click, or A to begin", 26)


func set_paused(p: bool) -> void:
	if p:
		_clear_overlay()
		overlay.color = Color(0.04, 0.03, 0.06, 0.6)
		_centered("PAUSED", 56)
		_centered("Esc / Start or click to resume  ·  F1 tuning", 22)
	else:
		hide_overlays()


func show_night(day: int, kills_today: int, report: Array[String], choices: Array[String]) -> void:
	_clear_overlay()
	overlay.color = Color(0.03, 0.03, 0.08, 0.82)
	_choices = choices
	_centered("NIGHT %d" % day, 54)
	var lines: Array[String] = []
	lines.append("%d kill%s today  ·  strength %.2f  ·  hunger %d  ·  the night costs %d hunger" % [
		kills_today, "" if kills_today == 1 else "s", GameState.strength, int(GameState.hunger),
		int(Tuning.HUNGER_NIGHT_COST * GameState.mod("hunger_drain"))])
	lines.append_array(report)
	var next := day + 1
	if next == GameState.challenge_day():
		lines.append("Tomorrow you challenge the pride male (strength %.2f)." % Tuning.PRIDE_MALE_STRENGTH)
	elif next == GameState.last_day() and GameState.act == GameState.Act.PRIDE:
		lines.append("Tomorrow at dusk, challengers will come (strength %.2f)." % Tuning.CHALLENGER_STRENGTH)
	_centered("\n".join(lines), 21)
	_centered("Choose an instinct (1 / 2 / 3, or D-pad left / up / right):", 22)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	overlay_box.add_child(row)
	for i in choices.size():
		var tr: Dictionary = GameState.TRAITS[choices[i]]
		var b := Button.new()
		b.text = "[%d]  %s\n%s" % [i + 1, tr["name"], tr["desc"]]
		b.custom_minimum_size = Vector2(320, 120)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 19)
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
	_centered("KING OF THE PRIDE" if won else "THE SAVANNA WINS", 64)
	_centered(text, 26)
	_centered("\nPress R or Start to begin a new life", 22)


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


class ChargeRing extends Control:
	## How much burst is in the tank. Pulses red while you're winded.
	var value := 1.0
	var winded := false
	var bursting := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5 - 4.0
		draw_arc(c, r, 0, TAU, 40, Color(0, 0, 0, 0.45), 6.0, true)
		var col := Color(1.0, 0.95, 0.75) if not bursting else Color(1.0, 0.75, 0.3)
		if winded:
			col = Color(1, 0.25, 0.2).lerp(Color(1, 1, 1, 0.4), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
		if value > 0.001:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * value, 40, col, 5.0, true)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(0, size.y + 16), "WINDED" if winded else "CHARGE", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(1, 0.97, 0.9))


class WindCompass extends Control:
	## Arrow shows where the wind blows TO, relative to the camera.
	## Stay so the arrow points from the prey toward you (you're downwind).
	## A gold dot on the rim points to the pride's den.
	var wind := Vector2(1, 0)
	var cam_yaw := 0.0
	var den_dir := Vector2.ZERO
	var show_den := false

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
		if show_den and den_dir.length() > 1.0:
			var d3 := Vector3(den_dir.x, 0, den_dir.y).rotated(Vector3.UP, -cam_yaw)
			var dd := Vector2(d3.x, d3.z).normalized()
			draw_circle(c + dd * r, 7.0, Color(1.0, 0.82, 0.35))
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(0, size.y + 18), "WIND", HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(1, 0.97, 0.9))
