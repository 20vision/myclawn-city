extends Node3D
## MyClawn's presence in the city: the growing tower, billboards, roaming clones,
## courier rings, cash drops and hidden Golden Clawns. Grid numbers mirror city.gd.

const Ped := preload("res://scripts/ped.gd")
const BLOCK := 46.0
const PURPLE := Color(0.486, 0.227, 0.929)
const BRIGHT := Color(0.77, 0.71, 0.99)
const GOLD := Color(1.0, 0.78, 0.2)
const MAX_WALKERS := 28
const LINES := [
	"MyClawn\nAn AI agent with its own computer",
	"MyClawn\nIt browses. It writes. It sends email.",
	"MyClawn\nWatch it work. Take over anytime.",
	"MyClawn\nReal. Free to start. myclawn.com",
]
const JOB_SPOTS := [Vector3(23, 0, -46), Vector3(-23, 0, 46), Vector3(69, 0, 23), Vector3(-69, 0, -23)]
const CHECKPOINTS := [
	Vector3(23, 0, 92), Vector3(-69, 0, 69), Vector3(-115, 0, -23), Vector3(-23, 0, -115), Vector3(69, 0, -92),
	Vector3(115, 0, 23), Vector3(69, 0, 115), Vector3(-23, 0, 23), Vector3(23, 0, -23), Vector3(-115, 0, 92),
]
## Hidden off the main spawn road. Rooftop-free, reachable on foot or by car.
const CLAWNS := [
	Vector3(-46, 1, -46), Vector3(92, 1, -92), Vector3(-92, 1, 92), Vector3(138, 1, 138), Vector3(-138, 1, -138),
	Vector3(138, 1, -46), Vector3(-138, 1, 46), Vector3(46, 1, 138), Vector3(-46, 1, -138), Vector3(92, 1, 46),
	Vector3(23, 1, -150), Vector3(-92, 1, -23),
]

var game: Node
var ui: Node
var _tower: MeshInstance3D
var _tower_label: Label3D
var _walkers: Array[Node] = []
var _rings: Array[Node3D] = []
var _clawn_nodes := {}
var _drop: Node3D
var _drop_timer := 40.0
var _rng := RandomNumberGenerator.new()

## Active courier job state, read by the UI.
var job_active := false
var job_left := 0
var job_time := 0.0
var job_target := Vector3.ZERO
var _beam: Node3D


func _ready() -> void:
	_rng.randomize()
	game = get_parent()
	_build_tower()
	_build_billboards()
	for spot in JOB_SPOTS:
		_rings.append(_ring(spot, GOLD, "COURIER JOB\ndrive in"))
	_beam = _ring(Vector3.ZERO, BRIGHT, "")
	_beam.visible = false
	for i in CLAWNS.size():
		if not (i in Econ.s.found):
			_clawn_nodes[i] = _clawn(CLAWNS[i])
	Econ.changed.connect(_sync_empire)
	_sync_empire()


func _emissive(color: Color, energy := 1.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _text(text: String, pos: Vector3, size: float, color := Color.WHITE, billboard := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = 96
	l.pixel_size = size
	l.modulate = color
	l.outline_size = 12
	l.outline_modulate = Color(0.04, 0.02, 0.1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(l)
	return l


## The middle block is kept empty by city.gd for this: your HQ, taller with every rank.
func _build_tower() -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 400, 20)
	col.shape = shape
	col.position = Vector3(0, 200, 0)
	body.add_child(col)
	add_child(body)
	_tower = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(20, 1, 20)
	_tower.mesh = box
	_tower.material_override = _emissive(PURPLE, 0.55)
	add_child(_tower)
	_tower_label = _text("MYCLAWN HQ", Vector3.ZERO, 0.09, Color.WHITE, true)


func _sync_empire() -> void:
	var h := 30.0 + Econ.rank_index() * 28.0
	_tower.scale.y = h
	_tower.position.y = h * 0.5
	_tower_label.position.y = h + 7.0
	var want := mini(Econ.s.scouts + Econ.s.closers, MAX_WALKERS)
	while _walkers.size() < want:
		_add_walker()


func _add_walker() -> void:
	var ped: CharacterBody3D = Ped.new()
	var c := Vector3(_rng.randi_range(-1, 1) * BLOCK, 0, _rng.randi_range(-1, 1) * BLOCK)
	var w := 15.0
	ped.corners = PackedVector3Array([c + Vector3(-w, .16, -w), c + Vector3(w, .16, -w), c + Vector3(w, .16, w), c + Vector3(-w, .16, w)])
	ped.corner_idx = 1
	ped.walk_speed = _rng.randf_range(2.0, 3.2)
	ped.shirt = BRIGHT
	ped.skin = PURPLE
	add_child(ped)
	ped.global_position = ped.corners[0] + Vector3(0, 0.2, 0)
	_walkers.append(ped)


func _build_billboards() -> void:
	var yaw := [0.0, PI * 0.5, PI, -PI * 0.5]
	var i := 0
	for gx in [-3, -1, 1, 3]:
		for gz in [-3, -1, 1, 3]:
			var root := Node3D.new()
			root.position = Vector3(gx * BLOCK + 15.5, 0, gz * BLOCK + 15.5)
			root.rotation.y = yaw[i % 4]
			add_child(root)
			var board := MeshInstance3D.new()
			var q := BoxMesh.new()
			q.size = Vector3(11, 4.6, 0.3)
			board.mesh = q
			board.position.y = 7.6
			board.material_override = _emissive(PURPLE, 0.7)
			root.add_child(board)
			var pole := MeshInstance3D.new()
			var p := BoxMesh.new()
			p.size = Vector3(0.4, 5.4, 0.4)
			pole.mesh = p
			pole.position.y = 2.7
			pole.material_override = _emissive(Color(0.15, 0.13, 0.2), 0.1)
			root.add_child(pole)
			for side in [1.0, -1.0]:
				var l := Label3D.new()
				l.text = LINES[i % LINES.size()]
				l.font_size = 64
				l.pixel_size = 0.016
				l.outline_size = 8
				l.outline_modulate = Color(0.1, 0.03, 0.25)
				l.position = Vector3(0, 7.6, 0.2 * side)
				if side < 0.0:
					l.rotation.y = PI
				root.add_child(l)
			i += 1


func _ring(pos: Vector3, color: Color, label: String) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var beam := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 4.5
	c.bottom_radius = 4.5
	c.height = 60.0
	beam.mesh = c
	beam.position.y = 30.0
	var m := _emissive(color, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.18
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = m
	root.add_child(beam)
	add_child(root)
	if label != "":
		var l := _text(label, pos + Vector3(0, 6, 0), 0.03, color, true)
		root.set_meta("label", l)
	return root


func _clawn(pos: Vector3) -> Node3D:
	var n := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.8
	s.height = 1.6
	n.mesh = s
	n.material_override = _emissive(GOLD, 2.0)
	n.position = pos + Vector3(0, 0.5, 0)
	add_child(n)
	return n


func _spawn_drop() -> void:
	if _drop != null:
		_drop.queue_free()
	_drop = _clawn(CHECKPOINTS[_rng.randi() % CHECKPOINTS.size()])
	_drop.scale = Vector3.ONE * 1.5
	_drop.material_override = _emissive(Color(0.3, 1.0, 0.5), 2.0)


func start_job() -> void:
	job_active = true
	job_left = 3
	_next_checkpoint()


func _next_checkpoint() -> void:
	var from: Vector3 = game.get_active().global_position
	var best := CHECKPOINTS[0]
	# Far enough to be a real drive, near enough to be doable in the time.
	var options := []
	for c in CHECKPOINTS:
		var d: float = from.distance_to(c)
		if d > 70.0 and d < 190.0:
			options.append(c)
	if not options.is_empty():
		best = options[_rng.randi() % options.size()]
	job_target = best
	job_time = 12.0 + from.distance_to(best) / 8.0
	_beam.position = best
	_beam.visible = true


func _end_job(success: bool) -> void:
	job_active = false
	_beam.visible = false
	var pay := Econ.finish_job(success)
	if success:
		ui.toast("Job done! +%s   chain x%d" % [Econ.money(pay), Econ.s.job_chain])
		ui.track("city_job_done", {"chain": Econ.s.job_chain})
	else:
		ui.toast("Too slow. The client walked. Chain lost.")


func _process(delta: float) -> void:
	if game == null or game.get_active() == null:
		return
	var at: Vector3 = game.get_active().global_position
	for n in _clawn_nodes.values():
		n.rotate_y(delta * 2.0)
	for id in _clawn_nodes.keys():
		if at.distance_to(_clawn_nodes[id].global_position) < 4.5:
			var fact := Econ.find_clawn(id)
			_clawn_nodes[id].queue_free()
			_clawn_nodes.erase(id)
			ui.fact("GOLDEN CLAWN %d/%d" % [Econ.s.found.size(), CLAWNS.size()], fact)
			ui.track("city_clawn", {"n": Econ.s.found.size()})
			break

	_drop_timer -= delta
	if _drop_timer <= 0.0:
		_drop_timer = 45.0
		if Econ.income_per_s() > 0.0:
			_spawn_drop()
			ui.toast("A clone dropped a cash bag somewhere in the city. Look for the green glow!")
	if _drop != null and at.distance_to(_drop.global_position) < 5.0:
		var pay: float = maxf(100.0, Econ.income_per_s() * 60.0)
		Econ._earn(pay)
		ui.toast("Cash bag +%s" % Econ.money(pay))
		_drop.queue_free()
		_drop = null

	if job_active:
		job_time -= delta
		var flat := Vector2(at.x - job_target.x, at.z - job_target.z).length()
		if flat < 7.0:
			job_left -= 1
			if job_left <= 0:
				_end_job(true)
			else:
				_next_checkpoint()
		elif job_time <= 0.0:
			_end_job(false)
	else:
		for ring in _rings:
			if Vector2(at.x - ring.position.x, at.z - ring.position.z).length() < 6.0 and game.driving != null:
				start_job()
				ui.toast("Courier job! Reach 3 drops before the clock runs out.")
				break
