extends Node3D
## Generates the city: road grid, sidewalk slabs and buildings.
##
## Facades and road markings are drawn by shaders rather than textures, so the
## whole city is a few hundred boxes and zero asset files. Swap _build_block()
## for real models when there are real models to swap in.

const BUILDING_SHADER := preload("res://shaders/building.gdshader")
const GROUND_SHADER := preload("res://shaders/ground.gdshader")

const BLOCK_SIZE := 46.0  ## one block, road included
const ROAD_WIDTH := 14.0  ## gap left between sidewalk slabs
const GRID := 7           ## GRID x GRID blocks
const SIDEWALK_HEIGHT := 0.16

## Concrete / brick / glass-tower facade tones.
const FACADE_TONES: Array[Color] = [
	Color(0.52, 0.50, 0.47),
	Color(0.44, 0.41, 0.39),
	Color(0.58, 0.46, 0.38),
	Color(0.36, 0.38, 0.42),
	Color(0.62, 0.60, 0.55),
	Color(0.30, 0.33, 0.36),
]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Fixed seed so the city is the same every run while we're tuning.
	_rng.seed = 20260809
	_build_ground()
	_build_boundary()
	for gx in GRID:
		for gz in GRID:
			_build_block(gx, gz)


## Walls around the map edge. Without these you can simply drive off the world
## and fall forever, which is exactly what happened the first time it was tested.
func _build_boundary() -> void:
	var extent := float(GRID) * BLOCK_SIZE
	var half := extent * 0.5
	var wall_height := 4.0
	var thickness := 2.0
	var mat := _plain_material(Color(0.30, 0.30, 0.32), 0.9)

	for i in 4:
		var along_x := i < 2
		var sign := 1.0 if i % 2 == 0 else -1.0
		var pos := Vector3(0.0, wall_height * 0.5, sign * half)
		var size := Vector3(extent + thickness * 2.0, wall_height, thickness)
		if not along_x:
			pos = Vector3(sign * half, wall_height * 0.5, 0.0)
			size = Vector3(thickness, wall_height, extent + thickness * 2.0)
		_add_box(pos, size, mat)


func _build_ground() -> void:
	var extent := float(GRID) * BLOCK_SIZE
	var body := StaticBody3D.new()
	body.name = "Ground"

	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("block_size", BLOCK_SIZE)
	mat.set_shader_parameter("world_extent", extent)

	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(extent, extent)
	# More subdivisions keeps the shader's world-space maths well behaved.
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	mesh.mesh = plane
	mesh.material_override = mat
	body.add_child(mesh)

	# Collision sits just under the visible plane so the top face is exactly y=0.
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(extent, 1.0, extent)
	col.shape = shape
	col.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(col)

	add_child(body)


func _build_block(gx: int, gz: int) -> void:
	var extent := float(GRID) * BLOCK_SIZE
	var centre := Vector3(
		-extent * 0.5 + gx * BLOCK_SIZE + BLOCK_SIZE * 0.5,
		0.0,
		-extent * 0.5 + gz * BLOCK_SIZE + BLOCK_SIZE * 0.5)

	var inner := BLOCK_SIZE - ROAD_WIDTH

	_add_box(
		centre + Vector3(0.0, SIDEWALK_HEIGHT * 0.5, 0.0),
		Vector3(inner, SIDEWALK_HEIGHT, inner),
		_plain_material(Color(0.38, 0.38, 0.40), 0.9))

	# Downtown sits in the middle of the map, so towers get taller toward it.
	var from_centre := Vector2(gx - (GRID - 1) * 0.5, gz - (GRID - 1) * 0.5).length()
	var downtown := clampf(1.0 - from_centre / (GRID * 0.6), 0.0, 1.0)

	# The middle block belongs to the MyClawn tower (brand.gd).
	if gx == GRID / 2 and gz == GRID / 2:
		return

	var pad := 2.0
	var cell := (inner - pad * 3.0) * 0.5
	for bx in 2:
		for bz in 2:
			if _rng.randf() < 0.12:
				continue  # leave the occasional empty lot

			var base_height := _rng.randf_range(10.0, 30.0)
			var height := base_height + downtown * _rng.randf_range(20.0, 70.0)
			var w := cell * _rng.randf_range(0.74, 0.95)
			var d := cell * _rng.randf_range(0.74, 0.95)
			var px := centre.x - inner * 0.5 + pad + cell * 0.5 + bx * (cell + pad)
			var pz := centre.z - inner * 0.5 + pad + cell * 0.5 + bz * (cell + pad)

			_add_box(
				Vector3(px, SIDEWALK_HEIGHT + height * 0.5, pz),
				Vector3(w, height, d),
				_facade_material(height))


func _facade_material(height: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = BUILDING_SHADER
	mat.set_shader_parameter("wall_colour", FACADE_TONES[_rng.randi() % FACADE_TONES.size()])
	mat.set_shader_parameter("building_height", height)
	mat.set_shader_parameter("floor_height", _rng.randf_range(3.1, 3.9))
	mat.set_shader_parameter("window_span", _rng.randf_range(2.2, 3.2))
	mat.set_shader_parameter("lit_ratio", _rng.randf_range(0.06, 0.30))
	mat.set_shader_parameter("seed", _rng.randf() * 200.0)
	return mat


func _add_box(pos: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	add_child(body)


func _plain_material(colour: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = roughness
	return mat
