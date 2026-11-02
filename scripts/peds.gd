extends Node3D
## Spawns pedestrians walking loops around the sidewalk of a random block.
##
## Grid constants mirror city.gd - if the city layout changes, change these too.

const Ped := preload("res://scripts/ped.gd")

const BLOCK_SIZE := 46.0
const ROAD_WIDTH := 14.0
const GRID := 7
const SIDEWALK_HEIGHT := 0.16
const PED_COUNT := 36

const SHIRTS: Array[Color] = [
	Color(0.24, 0.33, 0.50),
	Color(0.55, 0.20, 0.18),
	Color(0.20, 0.42, 0.28),
	Color(0.65, 0.60, 0.50),
	Color(0.30, 0.28, 0.34),
	Color(0.72, 0.48, 0.16),
	Color(0.14, 0.14, 0.16),
]

const SKINS: Array[Color] = [
	Color(0.85, 0.68, 0.55),
	Color(0.72, 0.56, 0.44),
	Color(0.55, 0.40, 0.30),
	Color(0.38, 0.27, 0.20),
]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 4242
	var extent := GRID * BLOCK_SIZE
	var inner := BLOCK_SIZE - ROAD_WIDTH
	var walk := inner * 0.5 - 0.9

	for n in PED_COUNT:
		var gx := _rng.randi_range(0, GRID - 1)
		var gz := _rng.randi_range(0, GRID - 1)
		var centre := Vector3(
			-extent * 0.5 + gx * BLOCK_SIZE + BLOCK_SIZE * 0.5,
			0.0,
			-extent * 0.5 + gz * BLOCK_SIZE + BLOCK_SIZE * 0.5)

		var corners := PackedVector3Array([
			centre + Vector3(-walk, SIDEWALK_HEIGHT, -walk),
			centre + Vector3(walk, SIDEWALK_HEIGHT, -walk),
			centre + Vector3(walk, SIDEWALK_HEIGHT, walk),
			centre + Vector3(-walk, SIDEWALK_HEIGHT, walk),
		])

		var ped: CharacterBody3D = Ped.new()
		var seg := _rng.randi_range(0, 3)
		ped.corners = corners
		ped.corner_idx = (seg + 1) % 4
		ped.walk_speed = _rng.randf_range(1.1, 2.2)
		ped.shirt = SHIRTS[_rng.randi() % SHIRTS.size()]
		ped.skin = SKINS[_rng.randi() % SKINS.size()]
		add_child(ped)
		# Somewhere along the chosen segment, already heading for its end.
		ped.global_position = corners[seg].lerp(corners[(seg + 1) % 4], _rng.randf()) \
			+ Vector3(0.0, 0.1, 0.0)
