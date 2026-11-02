extends CanvasLayer
## Everything on screen that isn't the speedometer: stats, quest line, toasts,
## the Empire panel and the start screen. Works with mouse, keyboard and controller.

const SITE := "https://www.myclawn.com/?utm_source=myclawn-city&utm_medium=game"

var brand: Node
var _stats: Label
var _quest: Label
var _job: Label
var _toast: Label
var _toast_t := 0.0
var _panel: PanelContainer
var _list: VBoxContainer
var _start: ColorRect
var _fact: PanelContainer
var _fact_text: Label
var _fact_btn: Button
var _rows := {}
var _status: Label
var started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	_stats = _label(30, Color(0.95, 0.93, 1.0))
	_stats.size = Vector2(450, 120)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quest = _label(21, Color(1.0, 0.85, 0.45))
	_job = _label(34, Color(0.77, 0.71, 0.99))
	_job.size = Vector2(520, 90)
	_job.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast = _label(25, Color.WHITE)
	_toast.size = Vector2(1000, 50)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_panel()
	_build_fact()
	_build_start()
	Econ.changed.connect(_refresh_panel)
	for flag in ["--shot", "--walk", "--drive", "--boost", "--fly"]:
		if flag in OS.get_cmdline_user_args():
			_begin()


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	add_child(l)
	return l


func _style(color: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(10)
	b.set_content_margin_all(18)
	return b


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.04, 0.14, 0.96)))
	_panel.custom_minimum_size = Vector2(760, 0)
	_panel.visible = false
	add_child(_panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 7)
	_panel.add_child(_list)
	var title := Label.new()
	title.text = "YOUR EMPIRE"
	title.add_theme_font_size_override("font_size", 28)
	_list.add_child(title)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 17)
	_status.add_theme_color_override("font_color", Color(0.77, 0.71, 0.99))
	_list.add_child(_status)
	_row("daily", _do_daily)
	_row("scout", func(): _buy(Econ.buy_clone("scout"), "city_clone"))
	_row("closer", func(): _buy(Econ.buy_clone("closer"), "city_clone"))
	_row("training", func(): _buy(Econ.buy_training(), "city_training"))
	_row("invest", func(): _buy(Econ.invest(), "city_invest"))
	_row("fund", func(): _buy(Econ.buy_fund_slot(), "city_fund"))
	_row("site", _open_site)
	_row("close", toggle_panel)


func _row(key: String, action: Callable) -> void:
	var b := Button.new()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 19)
	b.custom_minimum_size = Vector2(0, 42)
	b.pressed.connect(action)
	b.focus_mode = Control.FOCUS_ALL
	_list.add_child(b)
	_rows[key] = b


func _buy(ok: bool, event: String) -> void:
	if ok:
		track(event, {"rank": Econ.rank()})
	else:
		toast("Not enough cash yet. Run courier jobs or wait for your clones.")
	_refresh_panel()


func _do_daily() -> void:
	var r := Econ.claim_daily()
	if r > 0.0:
		toast("Day %d streak! +%s" % [Econ.s.streak, Econ.money(r)])
		track("city_daily", {"streak": Econ.s.streak})
	_refresh_panel()


func _open_site() -> void:
	track("city_site_click", {"rank": Econ.rank()})
	OS.shell_open(SITE)


func _refresh_panel() -> void:
	var s: Dictionary = Econ.s
	_status.text = "%s  |  %s/s  |  leads %d/%d  |  Clawns %d/12  |  streak %d" % [
		Econ.rank(), Econ.money(Econ.income_per_s()), int(s.leads), int(Econ.lead_cap()), s.found.size(), s.streak]
	_rows.daily.text = ("Claim daily bonus: %s" % Econ.money(Econ.daily_reward())) if Econ.daily_available() else "Daily bonus claimed. Back tomorrow keeps your streak."
	_rows.daily.disabled = not Econ.daily_available()
	_rows.scout.text = "Scout clone (%d owned): finds 1 lead/s   %s" % [s.scouts, Econ.money(Econ.clone_cost("scout"))]
	_rows.closer.text = "Closer clone (%d owned): 5 leads into a deal   %s" % [s.closers, Econ.money(Econ.clone_cost("closer"))]
	_rows.training.text = "Train all clones (level %d): +50%% income   %s" % [s.training, Econ.money(Econ.training_cost())]
	var hours := ""
	if not s.stakes.is_empty():
		var soonest := INF
		for st in s.stakes:
			soonest = minf(soonest, float(st.matures))
		hours = "  next exit in %.1fh" % maxf(0.0, (soonest - Econ.now()) / 3600.0)
	_rows.invest.text = "Back a startup (%d/%d deals): stake %s, exits in 8h%s" % [s.stakes.size(), s.funds, Econ.money(Econ.stake_size()), hours]
	_rows.fund.text = "Open another fund slot   %s" % Econ.money(Econ.fund_cost())
	_rows.site.text = "See the real MyClawn: an AI agent with its own computer"
	_rows.close.text = "Back to the city"


func _process(delta: float) -> void:
	var v := get_viewport().get_visible_rect().size
	_stats.position = Vector2(v.x - 470.0, 18.0)
	_quest.position = Vector2(30.0, v.y - 56.0)
	_job.position = Vector2(v.x * 0.5 - 260.0, 20.0)
	_toast.position = Vector2(v.x * 0.5 - 500.0, v.y - 130.0)
	var s: Dictionary = Econ.s
	_stats.text = "%s\n%s/s\n%s" % [Econ.money(s.cash), Econ.money(Econ.income_per_s()), Econ.rank()]
	_quest.text = _current_quest()
	if brand != null and brand.job_active:
		_job.text = "%d drops left   %ds\n%s %dm" % [brand.job_left, int(ceil(brand.job_time)), _arrow(), int(_dist())]
	else:
		_job.text = ""
	_toast_t -= delta
	_toast.visible = _toast_t > 0.0
	if _panel.visible:
		_refresh_panel()
	var results := Econ.collect_matured()
	for r in results:
		if r.multiple >= 12.0:
			fact("MASSIVE EXIT!", "%s returned %dx: %s" % [r.name, int(r.multiple), Econ.money(r.pay)])
		else:
			toast("%s returned %.1fx: %s" % [r.name, r.multiple, Econ.money(r.pay)])
		track("city_exit", {"x": r.multiple})


func _dist() -> float:
	var at: Vector3 = brand.game.get_active().global_position
	return Vector2(at.x - brand.job_target.x, at.z - brand.job_target.z).length()


func _arrow() -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return ""
	var to: Vector3 = brand.job_target - cam.global_position
	var f: Vector3 = -cam.global_transform.basis.z
	var angle := atan2(f.x * to.z - f.z * to.x, f.x * to.x + f.z * to.z)
	var dirs := ["^", "^>", ">", "v>", "v", "<v", "<", "<^"]
	return dirs[int(round(angle / (PI / 4.0))) % 8]


func _current_quest() -> String:
	var s: Dictionary = Econ.s
	if s.scouts == 0: return "GOAL: Press Q (Y on controller) and make your first scout clone"
	if s.closers == 0: return "GOAL: Your scout finds leads. Make a closer clone to turn them into money"
	if s.jobs_done == 0: return "GOAL: Get in a car (E / B), drive into a gold beam and finish a courier job"
	if s.scouts + s.closers < 6: return "GOAL: Grow to 6 clones. Keep scouts and closers balanced"
	if s.stakes.is_empty() and s.best_exit == 0.0: return "GOAL: Back your first startup. It pays out in 8 real hours, so come back"
	if s.found.size() < 12: return "GOAL: Find the hidden Golden Clawns (%d/12). Each reveals something real" % s.found.size()
	return "GOAL: Reach the next rank. Your HQ tower grows with every one"


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 4.0


func track(event: String, props: Dictionary) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.track&&window.track(%s,%s)" % [JSON.stringify(event), JSON.stringify(props)])


func toggle_panel() -> void:
	if _fact.visible:
		return
	_panel.visible = not _panel.visible
	get_tree().paused = _panel.visible
	if _panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_panel()
		_panel.position = get_viewport().get_visible_rect().size * 0.5 - _panel.size * 0.5
		(_rows.scout if _rows.daily.disabled else _rows.daily).grab_focus()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if not started:
		var go: bool = (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed)
		if go:
			_begin()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		toggle_panel()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y and get_tree().paused:
		if _panel.visible:
			toggle_panel()
		get_viewport().set_input_as_handled()


func _build_fact() -> void:
	_fact = PanelContainer.new()
	_fact.add_theme_stylebox_override("panel", _style(Color(0.2, 0.09, 0.42, 0.97)))
	_fact.custom_minimum_size = Vector2(640, 0)
	_fact.visible = false
	add_child(_fact)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_fact.add_child(v)
	_fact_text = Label.new()
	_fact_text.add_theme_font_size_override("font_size", 23)
	_fact_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_fact_text.custom_minimum_size = Vector2(600, 0)
	v.add_child(_fact_text)
	_fact_btn = Button.new()
	_fact_btn.text = "Keep playing"
	_fact_btn.add_theme_font_size_override("font_size", 20)
	_fact_btn.pressed.connect(_close_fact)
	v.add_child(_fact_btn)


func fact(title: String, text: String) -> void:
	_fact_text.text = "%s\n\n%s" % [title, text]
	_fact.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().process_frame
	_fact.position = get_viewport().get_visible_rect().size * 0.5 - _fact.size * 0.5
	_fact_btn.grab_focus()


func _close_fact() -> void:
	_fact.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_start() -> void:
	_start = ColorRect.new()
	_start.color = Color(0.05, 0.02, 0.11, 0.9)
	_start.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_start)
	var l := Label.new()
	var away := Econ.take_away_report()
	var welcome := "Your clones earned %s while you were away.\n\n" % Econ.money(away) if away >= 1.0 else ""
	l.text = "MYCLAWN CITY\n\n%sMake clones. They run the business. You run the city.\nThey keep earning while you're gone, so come back every day.\n\nWASD / left stick: move     E / B: car     Q / Y: empire\nSHIFT / RB: boost     SPACE / A: jump, brake     Mouse / right stick: camera\n\nClick or press any button to start\n\nMoney in this city is pretend. MyClawn itself is real: myclawn.com" % welcome
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 23)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	_start.add_child(l)
	get_tree().paused = true


func _begin() -> void:
	started = true
	_start.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	track("city_start", {"returning": Econ.s.earned > 0.0, "streak": Econ.s.streak})
