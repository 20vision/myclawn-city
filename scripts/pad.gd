extends Node
## Maps a controller onto the keys the game already reads, so every vehicle works
## with a pad without its own input code. UI uses Godot's built-in ui_* pad actions.

var enabled := true
var _held := {}

const BUTTONS := {
	JOY_BUTTON_A: KEY_SPACE, JOY_BUTTON_B: KEY_E, JOY_BUTTON_X: KEY_F,
	JOY_BUTTON_Y: KEY_Q, JOY_BUTTON_LEFT_SHOULDER: KEY_R, JOY_BUTTON_RIGHT_SHOULDER: KEY_SHIFT,
	JOY_BUTTON_LEFT_STICK: KEY_SHIFT,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var want := {}
	var pads := Input.get_connected_joypads()
	if enabled and not pads.is_empty() and not get_tree().paused:
		var d: int = pads[0]
		var x := Input.get_joy_axis(d, JOY_AXIS_LEFT_X)
		var y := Input.get_joy_axis(d, JOY_AXIS_LEFT_Y)
		if x < -0.3: want[KEY_A] = true
		if x > 0.3: want[KEY_D] = true
		if y < -0.3: want[KEY_W] = true
		if y > 0.3: want[KEY_S] = true
		if Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) > 0.2: want[KEY_W] = true
		if Input.get_joy_axis(d, JOY_AXIS_TRIGGER_LEFT) > 0.2: want[KEY_S] = true
		for b in BUTTONS:
			if Input.is_joy_button_pressed(d, b):
				want[BUTTONS[b]] = true
	for k in want:
		if not _held.has(k):
			_send(k, true)
	for k in _held:
		if not want.has(k):
			_send(k, false)
	_held = want


func _send(key: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.physical_keycode = key
	ev.pressed = pressed
	Input.parse_input_event(ev)
