extends Node
## Dev helper. F12 saves a screenshot into res://screenshots/.
##
## Command-line self-tests, so changes can be verified without a human watching:
##   -- --shot     boot, screenshot one frame, quit
##   -- --walk     run the player on foot for 5s, log speed/position, quit
##   -- --drive    get in the car, hold throttle 5s, log, quit
##   -- --boost    same as --drive but holding SHIFT

const TEST_FRAMES := 300

var _auto_frames := -1
var _shot_count := 0

var _test := ""
var _frames_left := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if "--shot" in args:
		# Give the city a moment to build and the car to settle on its suspension.
		_auto_frames = 120
	if "--jobtest" in args:
		_job_test()
	for mode in ["walk", "drive", "boost", "fly"]:
		if "--" + mode in args:
			_test = mode
			_frames_left = TEST_FRAMES


## Plays a whole courier job and one Golden Clawn through the real game code.
func _job_test() -> void:
	Econ.now_override = 1.0  # never touches a real save
	await get_tree().create_timer(2.0).timeout
	var game := get_tree().get_first_node_in_group("game")
	game.get_node("EmpireUI")._begin()
	var brand: Node = game.get_node("Brand")
	game.enter_nearest_vehicle()
	var car: RigidBody3D = game.driving
	car.freeze = true
	var start_cash: float = Econ.s.cash
	car.global_position = brand.JOB_SPOTS[0] + Vector3.UP
	await get_tree().create_timer(0.5).timeout
	print("job started: ", brand.job_active)
	for i in 3:
		car.global_position = brand.job_target + Vector3.UP
		await get_tree().create_timer(0.3).timeout
	print("job finished: ", not brand.job_active, " jobs_done ", Econ.s.jobs_done, " paid ", Econ.s.cash - start_cash)
	car.global_position = brand.job_target + Vector3(300, 1, 300)
	car.global_position = brand.CLAWNS[0] + Vector3.UP
	await get_tree().create_timer(0.5).timeout
	print("clawn found: ", Econ.s.found.size(), " panel open: ", get_tree().paused)
	print("JOBTEST ", "OK" if Econ.s.jobs_done == 1 and Econ.s.found.size() == 1 and get_tree().paused else "FAILED")
	get_tree().quit()


func _process(_delta: float) -> void:
	if _auto_frames > 0:
		_auto_frames -= 1
		if _auto_frames == 0:
			await capture("boot")
			get_tree().quit()


func _physics_process(_delta: float) -> void:
	if _frames_left <= 0:
		return

	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return

	# The vehicle tests need to actually get in first, through the real code path.
	if _test != "walk" and game.driving == null:
		if _test == "fly":
			# The heli lives on the north-edge pad; teleport the player next to it.
			var heli: Node3D = null
			for v in get_tree().get_nodes_in_group("vehicle"):
				if not v is VehicleBody3D:
					heli = v
					break
			if heli == null:
				push_error("fly test: no helicopter found")
				get_tree().quit()
				return
			game.player.global_position = heli.global_position + Vector3(3.0, 0.5, 0.0)
		game.enter_nearest_vehicle()
		return

	_send_key(KEY_W, true)
	if _test == "boost" or _test == "walk":
		_send_key(KEY_SHIFT, true)
	if _test == "fly":
		_send_key(KEY_SPACE, true)

	_frames_left -= 1

	var subject: Node = game.get_active()
	if subject and _frames_left % 60 == 0:
		var upright := 1.0
		if subject is Node3D:
			upright = subject.global_transform.basis.y.y
		print("%s test: frame %d  speed %.1f km/h  upright %.2f  pos %v"
			% [_test, TEST_FRAMES - _frames_left, subject.get_speed_kmh(),
				upright, subject.global_position])

	if _frames_left == 0:
		_send_key(KEY_W, false)
		_send_key(KEY_SHIFT, false)
		_send_key(KEY_SPACE, false)
		# Freeze so the screenshot shows the state that was just measured, rather
		# than wherever it coasted to while the capture was awaiting a frame.
		if subject is RigidBody3D:
			subject.freeze = true
		# Watchdog: if the capture await never resolves, still quit rather than
		# leaving a zombie window behind.
		get_tree().create_timer(5.0).timeout.connect(func() -> void: get_tree().quit())
		await capture(_test)
		get_tree().quit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			_shot_count += 1
			capture("shot_%02d" % _shot_count)


func capture(tag: String) -> void:
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)

	# Don't await frame_post_draw: when macOS occludes the window it stops the
	# draw loop entirely and that signal never fires again. Force a frame instead.
	RenderingServer.force_draw()
	await get_tree().create_timer(0.3).timeout

	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [dir, tag]
	var err := image.save_png(path)
	if err == OK:
		print("screenshot saved: ", path)
	else:
		push_warning("screenshot failed (%d): %s" % [err, path])


func _send_key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
