extends Node3D
## Owns the on-foot / in-car state. Everything that needs to know "what is the
## player controlling right now" asks here rather than guessing from groups.

signal active_changed(node: Node3D)

## How close you have to be to a car to get in.
@export var enter_distance := 4.5

@onready var player: CharacterBody3D = $Player

## Any rigid body in the "vehicle" group with `active` + `get_speed_kmh()`:
## cars and trucks are VehicleBody3D, the helicopter is a plain RigidBody3D.
var driving: RigidBody3D = null


func _ready() -> void:
	add_to_group("game")
	# Cars sit in the world unattended until someone gets in.
	for vehicle in get_tree().get_nodes_in_group("vehicle"):
		vehicle.active = false
	$Brand.ui = $EmpireUI
	$EmpireUI.brand = $Brand


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if driving != null:
			exit_vehicle()
		else:
			enter_nearest_vehicle()


## What the camera should follow and the HUD should report on.
func get_active() -> Node3D:
	return driving if driving != null else player


## Nearest vehicle in range, or null. Also used to decide whether to show the prompt.
func nearest_vehicle() -> RigidBody3D:
	var best: RigidBody3D = null
	var best_distance := enter_distance
	for vehicle in get_tree().get_nodes_in_group("vehicle"):
		var distance := player.global_position.distance_to(vehicle.global_position)
		if distance < best_distance:
			best_distance = distance
			best = vehicle
	return best


func enter_nearest_vehicle() -> void:
	var vehicle := nearest_vehicle()
	if vehicle == null:
		return

	driving = vehicle
	vehicle.active = true
	_set_player_present(false)
	active_changed.emit(vehicle)


func exit_vehicle() -> void:
	if driving == null:
		return

	# Step out to the left of the car, and up a little so we don't spawn in the road.
	var side := driving.global_transform.basis.x.normalized()
	player.global_position = driving.global_position - side * 2.2 + Vector3.UP * 0.4
	player.velocity = Vector3.ZERO

	driving.active = false
	if driving is VehicleBody3D:
		driving.engine_force = 0.0
	driving = null
	_set_player_present(true)
	active_changed.emit(player)


func _set_player_present(present: bool) -> void:
	player.visible = present
	player.set_physics_process(present)
	# Deferred because collision state can't change during a physics callback.
	player.get_node("Collision").set_deferred("disabled", not present)
