extends SceneTree
## Headless test for the walkable town: walking, collisions, doors, and the
## scene it shows. Works with or without the local art pack.
## Run: godot --headless --path . -s tests/test_town_map.gd

var _failures := 0
var _passes := 0
var _map: TownMap
var _near_events: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: " + message)

## Walk in `direction` for `seconds` of physics time.
func _walk(direction: Vector2, seconds: float) -> void:
	_map.set_move(direction)
	var frames := int(seconds * Engine.physics_ticks_per_second)
	for i in range(frames):
		await physics_frame
	_map.set_move(Vector2.ZERO)
	await physics_frame

func _run() -> void:
	_map = TownMap.new()
	root.add_child(_map)
	_map.near_changed.connect(func(place): _near_events.append(place))
	await process_frame
	print("art installed: %s" % _map.has_art())
	_check(_map.player.position == TownMap.START, "the player starts on the main street")
	_check(_map.near == "", "nowhere to enter at the start")

	var start_x := _map.player.position.x
	await _walk(Vector2.RIGHT, 0.5)
	_check(_map.player.position.x > start_x + 60.0, "walking right moves the player (%.0f)" % _map.player.position.x)

	# Walk north into the Rusty Spur: the building blocks you at its front.
	_check(_map.go_to("rusty_spur"), "go_to a known place")
	_check(_map.near == "rusty_spur", "at the saloon door, it's the place to enter")
	await _walk(Vector2.UP, 1.5)
	_check(_map.player.position.y > 400.0, "the saloon's walls stop you (y %.0f)" % _map.player.position.y)
	await _walk(Vector2.DOWN, 1.0)
	_check(_map.near == "", "walking away leaves the door")
	_check(_near_events.has("rusty_spur") and _near_events.back() == "", "near changes are signalled")

	# The river blocks you except along the dock, which leads to the landing.
	_map.player.position = Vector2(400, 860)
	await _walk(Vector2.DOWN, 1.5)
	_check(_map.player.position.y < TownMap.RIVER_TOP, "you can't walk into the river (y %.0f)" % _map.player.position.y)
	_map.player.position = Vector2(985, 640)
	await _walk(Vector2.DOWN, 2.5)
	_check(_map.player.position.y > TownMap.RIVER_TOP and _map.near == "landing",
		"the dock leads out over the water to the landing (y %.0f)" % _map.player.position.y)

	_check(not _map.go_to("nowhere"), "an unknown place is rejected")
	for place in TownMap.PLACES:
		_map.go_to(place)
		_check(_map.near == place, "go_to(%s) stands you at its door" % place)
	_map.player.position = Vector2(-50, -50)
	await _walk(Vector2.LEFT, 0.2)
	_check(_map.player.position.x >= 0.0 and _map.player.position.y >= 0.0, "you can't leave the map")

	_map.set_scene(false, true)
	_check(not _map._drifter_kempt and _map._riverboat_docked, "the town shows the drifter's look and the riverboat")

	print("PASSES: %d" % _passes)
	print("FAILURES: %d" % _failures)
	quit(1 if _failures > 0 else 0)
