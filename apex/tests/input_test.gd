extends SceneTree
## Input check: every gameplay action has a keyboard/mouse binding AND a controller
## binding, and simulated controller input reaches the right actions.
##
## Run:  godot --headless --path . -s tests/input_test.gd
## Exit code 0 = pass.

# Actions that must work on both keyboard and controller.
const BOTH := ["move_forward", "move_back", "move_left", "move_right", "sprint", "stalk",
	"pounce", "swipe", "dodge", "roar", "eat", "pause", "restart", "start", "clamp",
	"choice_1", "choice_2", "choice_3"]
# Controller-only (the mouse covers these on keyboard).
const PAD_ONLY := ["look_left", "look_right", "look_up", "look_down"]

var _f := 0
var _failed := false


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		for a in BOTH:
			_check(InputMap.has_action(a), "action %s exists" % a)
			if InputMap.has_action(a):
				_check(_has(a, true), "%s has a keyboard/mouse binding" % a)
				_check(_has(a, false), "%s has a controller binding" % a)
		for a in PAD_ONLY:
			_check(InputMap.has_action(a) and _has(a, false), "%s has a controller binding" % a)
		# Press things the way a controller would.
		_axis(JOY_AXIS_LEFT_Y, -0.8)
		_axis(JOY_AXIS_RIGHT_X, 0.9)
		_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
		_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
		for b in [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_B, JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER,
				JOY_BUTTON_START, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT]:
			_button(b, true)
	if _f == 4:
		var mv := Input.get_vector("move_left", "move_right", "move_forward", "move_back", 0.18)
		_check(mv.y < -0.5 and absf(mv.x) < 0.1, "left stick up moves forward (%s)" % mv)
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down", 0.18)
		_check(look.x > 0.5, "right stick turns the camera (%s)" % look)
		for pair in [["sprint", "RT"], ["stalk", "LT"], ["pounce", "A"], ["swipe", "X"], ["dodge", "B"],
				["roar", "Y"], ["eat", "RB"], ["pause", "Start"], ["choice_1", "D-pad left"],
				["choice_2", "D-pad up"], ["choice_3", "D-pad right"]]:
			_check(Input.is_action_pressed(pair[0]), "%s triggers %s" % [pair[1], pair[0]])
		print("INPUT TEST: ", "FAIL" if _failed else "PASS")
		quit(1 if _failed else 0)
	return false


func _has(action: String, keyboard: bool) -> bool:
	for ev in InputMap.action_get_events(action):
		var is_kb := ev is InputEventKey or ev is InputEventMouseButton
		var is_pad := ev is InputEventJoypadButton or ev is InputEventJoypadMotion
		if (keyboard and is_kb) or (not keyboard and is_pad):
			return true
	return false


func _axis(axis: JoyAxis, value: float) -> void:
	var m := InputEventJoypadMotion.new()
	m.axis = axis
	m.axis_value = value
	Input.parse_input_event(m)


func _button(b: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = pressed
	Input.parse_input_event(e)


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("  FAIL " + what)
		_failed = true
