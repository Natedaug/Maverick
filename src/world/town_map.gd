class_name TownMap
extends Node2D
## Walkable top-down Devil's Draw. The player walks the main street; standing
## at a door reports that place as `near`, and the Svelte interface opens it.
##
## Art: the Jarppix western sheets, local-only (assets/third_party/README.md;
## run tools/prepare_jarppix.gd once to make the `_keyed` sheets). Without
## them, the town draws plain stand-in shapes so the game always runs.
## People, water, and the riverboat are drawn here; the pack has none.

signal near_changed(place: String)

const ART_DIR := "res://assets/third_party/jarppix_western/"
const WORLD := Rect2(0, 0, 1800, 1260)
const ROAD := Rect2(0, 470, 1800, 150)
const RIVER_TOP := 900.0
const DOCK := Rect2(940, 600, 90, 420)
const SPEED := 170.0
const PLAYER_RADIUS := 15.0
const NEAR_DISTANCE := 56.0
const START := Vector2(300, 540)

## Places you can enter: door position and the name shown in the world.
const PLACES := {
	assay = {name = "Assay Office", door = Vector2(281, 455)},
	rusty_spur = {name = "The Rusty Spur", door = Vector2(769, 455)},
	boarding = {name = "Boarding House", door = Vector2(1257, 455)},
	landing = {name = "Riverboat Landing", door = Vector2(985, 990)},
}

## Sprite regions on the keyed sheets (found by tools/prepare_jarppix.gd).
const SPRITES := {
	roof_saloon = ["houses mountains", Rect2(427, 0, 338, 250)],
	roof_assay = ["houses mountains", Rect2(5, 240, 282, 203)],
	roof_boarding = ["houses mountains", Rect2(776, 1, 214, 283)],
	roof_shed = ["houses mountains", Rect2(262, 1, 156, 215)],
	roof_barn = ["houses mountains", Rect2(4, 21, 254, 194)],
	rock = ["houses mountains", Rect2(444, 268, 519, 328)],
	sign_saloon = ["peoples buildings other", Rect2(46, 215, 104, 32)],
	sign_small = ["peoples buildings other", Rect2(170, 224, 76, 22)],
	boardwalk = ["peoples buildings other", Rect2(319, 506, 202, 44)],
	barrel = ["peoples buildings other", Rect2(316, 133, 20, 19)],
	wheel = ["peoples buildings other", Rect2(274, 172, 22, 18)],
	trough = ["buildings other", Rect2(388, 22, 114, 89)],
	fence = ["buildings other", Rect2(41, 511, 358, 42)],
	rails = ["buildings other", Rect2(16, 17, 324, 35)],
	tree = ["Plants and fences", Rect2(487, 199, 212, 226)],
	agave = ["Plants and fences", Rect2(228, 9, 128, 126)],
	bush_dry = ["Plants and fences", Rect2(171, 348, 79, 77)],
	tumbleweed = ["Plants and fences", Rect2(321, 356, 67, 68)],
	cactus_a = ["Plants and fences", Rect2(436, 13, 40, 48)],
	cactus_b = ["Plants and fences", Rect2(487, 20, 41, 35)],
}

## Buildings and obstacles: sprite, top-left position, and whether it blocks.
const LAYOUT := [
	["rails", Vector2(0, 8)], ["rails", Vector2(324, 8)], ["rails", Vector2(648, 8)],
	["rails", Vector2(972, 8)], ["rails", Vector2(1296, 8)], ["rails", Vector2(1620, 8)],
	["fence", Vector2(20, 60)], ["fence", Vector2(420, 60)], ["fence", Vector2(1400, 60)],
	["roof_assay", Vector2(140, 230), true],
	["roof_saloon", Vector2(600, 180), true],
	["roof_boarding", Vector2(1150, 150), true],
	["roof_barn", Vector2(560, 660), true],
	["roof_shed", Vector2(1380, 650), true],
	["rock", Vector2(-60, 640), true],
	["tree", Vector2(1520, 240), true],
	["agave", Vector2(20, 300)], ["bush_dry", Vector2(470, 350)], ["bush_dry", Vector2(1660, 700)],
	["tumbleweed", Vector2(1100, 640)], ["cactus_a", Vector2(1080, 380)], ["cactus_b", Vector2(470, 720)],
	["cactus_a", Vector2(1690, 520)], ["cactus_b", Vector2(1240, 760)],
	["trough", Vector2(960, 420), true], ["barrel", Vector2(590, 438)], ["barrel", Vector2(612, 440)],
	["wheel", Vector2(1110, 445)],
]
## Boardwalk strips in front of the north-side buildings.
const BOARDWALKS := [Vector2(130, 436), Vector2(330, 436), Vector2(590, 436), Vector2(792, 436),
	Vector2(1140, 436), Vector2(1342, 436)]
## Blocking footprints are inset this much so roofs overhang a little.
const FOOTPRINT_INSET := 6.0
## Where the drifter loiters when he's not dealing.
const DRIFTER_SPOT := Vector2(700, 488)

var near: String = ""
var player: CharacterBody2D
var camera: Camera2D
var _move := Vector2.ZERO
var _sheets: Dictionary = {}  # sheet name -> Texture2D (missing when the art isn't installed)
var _grass: Texture2D
var _drifter_kempt := true
var _riverboat_docked := false
var _sprites: Dictionary = {}  # sprite name -> AtlasTexture

func _ready() -> void:
	_load_art()
	_build_world()
	_build_player()
	queue_redraw()

## True when the local art pack is installed and prepared.
func has_art() -> bool:
	return not _sheets.is_empty()

## Walking intent from the interface: each axis in -1..1.
func set_move(direction: Vector2) -> void:
	_move = direction.limit_length(1.0)

## Put the player at a place's door (used when opening a place from a menu).
func go_to(place: String) -> bool:
	if not PLACES.has(place):
		return false
	player.position = PLACES[place].door + Vector2(0, 30 if place != "landing" else -30)
	_update_near()
	return true

## What the town shows: the drifter's look and whether the riverboat is in.
func set_scene(drifter_kempt: bool, riverboat_docked: bool) -> void:
	if drifter_kempt == _drifter_kempt and riverboat_docked == _riverboat_docked:
		return
	_drifter_kempt = drifter_kempt
	_riverboat_docked = riverboat_docked
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if player == null:
		return
	player.velocity = _move * SPEED
	if _move != Vector2.ZERO:
		player.move_and_slide()
		player.position = player.position.clamp(WORLD.position + Vector2.ONE * PLAYER_RADIUS,
			WORLD.end - Vector2.ONE * PLAYER_RADIUS)
		player.queue_redraw()
		_update_near()

func _update_near() -> void:
	var found := ""
	var best := NEAR_DISTANCE
	for id in PLACES:
		var d: float = player.position.distance_to(PLACES[id].door)
		if d < best:
			best = d
			found = id
	if found != near:
		near = found
		near_changed.emit(near)

# --- Building the world ---

func _load_art() -> void:
	var names := {}
	for key in SPRITES:
		names[SPRITES[key][0]] = true
	for sheet in names:
		var path: String = ART_DIR + sheet + "_keyed.png"
		if not ResourceLoader.exists(path):
			_sheets.clear()
			return
		_sheets[sheet] = load(path)
	if ResourceLoader.exists(ART_DIR + "background grass.png"):
		_grass = load(ART_DIR + "background grass.png")
	for key in SPRITES:
		var atlas := AtlasTexture.new()
		atlas.atlas = _sheets[SPRITES[key][0]]
		atlas.region = SPRITES[key][1]
		_sprites[key] = atlas

func _build_world() -> void:
	for item in LAYOUT:
		var key: String = item[0]
		var pos: Vector2 = item[1]
		var size: Vector2 = SPRITES[key][1].size
		if has_art():
			var sprite := Sprite2D.new()
			sprite.texture = _sprites[key]
			sprite.centered = false
			sprite.position = pos
			sprite.z_index = 2 if key == "tree" else 0
			add_child(sprite)
		if item.size() > 2 and item[2]:
			_add_blocker(Rect2(pos, size).grow(-FOOTPRINT_INSET))
	if has_art():
		var saloon_sign := Sprite2D.new()
		saloon_sign.texture = _sprites.sign_saloon
		saloon_sign.scale = Vector2(1.6, 1.6)
		saloon_sign.position = Vector2(769, 418)
		saloon_sign.z_index = 1
		add_child(saloon_sign)
	# Place names float above everything, so roofs can't hide them.
	var labels := Node2D.new()
	labels.z_index = 5
	labels.draw.connect(func(): _draw_labels(labels))
	add_child(labels)
	# The river, except where the dock runs out over it.
	_add_blocker(Rect2(0, RIVER_TOP, DOCK.position.x, WORLD.end.y - RIVER_TOP))
	_add_blocker(Rect2(DOCK.end.x, RIVER_TOP, WORLD.end.x - DOCK.end.x, WORLD.end.y - RIVER_TOP))
	_add_blocker(Rect2(DOCK.position.x, DOCK.end.y, DOCK.size.x, WORLD.end.y - DOCK.end.y))

func _add_blocker(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.position = rect.get_center()
	body.add_child(shape)
	add_child(body)

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PLAYER_RADIUS
	shape.shape = circle
	player.add_child(shape)
	player.position = START
	player.z_index = 1
	player.draw.connect(func(): _draw_person(player, Vector2.ZERO, Color("#6b4a2b"), Color("#3a2716"), true))
	add_child(player)
	camera = Camera2D.new()
	camera.limit_left = int(WORLD.position.x)
	camera.limit_top = int(WORLD.position.y)
	camera.limit_right = int(WORLD.end.x)
	camera.limit_bottom = int(WORLD.end.y)
	camera.position_smoothing_enabled = true
	player.add_child(camera)
	_update_near()

func _process(_delta: float) -> void:
	# Show roughly 800 world pixels of height whatever the window size.
	if camera != null:
		var height := get_viewport_rect().size.y
		var zoom := clampf(height / 800.0, 0.6, 2.0)
		if not is_equal_approx(camera.zoom.x, zoom):
			camera.zoom = Vector2(zoom, zoom)

# --- Drawing what the pack doesn't have ---

func _draw() -> void:
	# Ground, road, and boardwalks.
	if _grass != null:
		draw_texture_rect(_grass, WORLD, true)
	else:
		draw_rect(WORLD, Color("#b9925e"))
	_draw_road()
	if has_art():
		for pos in BOARDWALKS:
			draw_texture(_sprites.boardwalk, pos)
		# The dock: boardwalk planks laid across it.
		var y := DOCK.position.y
		while y < DOCK.end.y:
			draw_texture_rect_region(_sheets[SPRITES.boardwalk[0]], Rect2(DOCK.position.x, y, DOCK.size.x, 44),
				Rect2(SPRITES.boardwalk[1].position, Vector2(DOCK.size.x, 44)))
			y += 44
	else:
		draw_rect(DOCK, Color("#7a5a3a"))
		for item in LAYOUT:
			if item.size() > 2 and item[2]:
				var rect := Rect2(item[1], SPRITES[item[0]][1].size)
				draw_rect(rect, Color("#5b4630"))
				draw_rect(rect, Color("#2e2117"), false, 3.0)
	# The river.
	draw_rect(Rect2(0, RIVER_TOP, WORLD.size.x, WORLD.end.y - RIVER_TOP), Color("#4b5f5a"))
	for i in range(14):
		var wx := float(i) * 140.0 + 30.0
		draw_line(Vector2(wx, RIVER_TOP + 40 + (i % 3) * 30), Vector2(wx + 60, RIVER_TOP + 40 + (i % 3) * 30),
			Color(1, 1, 1, 0.15), 2.0)
	if has_art():
		var y2 := DOCK.position.y
		while y2 < DOCK.end.y:
			if y2 >= RIVER_TOP - 44:
				draw_texture_rect_region(_sheets[SPRITES.boardwalk[0]], Rect2(DOCK.position.x, y2, DOCK.size.x, 44),
					Rect2(SPRITES.boardwalk[1].position, Vector2(DOCK.size.x, 44)))
			y2 += 44
	else:
		draw_rect(Rect2(DOCK.position.x, RIVER_TOP, DOCK.size.x, DOCK.end.y - RIVER_TOP), Color("#7a5a3a"))
	if _riverboat_docked:
		_draw_riverboat(Vector2(1090, 940))
	# The drifter, outside the saloon.
	_draw_person(self, DRIFTER_SPOT, Color("#5a4630") if _drifter_kempt else Color("#6e5a42"),
		Color("#2e2117"), false, not _drifter_kempt)

## Name boards over each door.
func _draw_labels(target: CanvasItem) -> void:
	var font := ThemeDB.fallback_font
	for id in PLACES:
		var label: String = PLACES[id].name
		var door: Vector2 = PLACES[id].door
		var at := door + (Vector2(0, -60) if id != "landing" else Vector2(0, 46))
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 15).x
		target.draw_rect(Rect2(at.x - width / 2 - 8, at.y - 16, width + 16, 22), Color(0.1, 0.07, 0.04, 0.8))
		target.draw_string(font, Vector2(at.x - width / 2, at.y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			Color("#f0d7a1"))

## The main street: packed dirt with two wagon ruts and loose stones.
func _draw_road() -> void:
	draw_rect(ROAD, Color("#c4a274"))
	draw_rect(Rect2(ROAD.position.x, ROAD.position.y, ROAD.size.x, 10), Color("#b08f62"))
	draw_rect(Rect2(ROAD.position.x, ROAD.end.y - 10, ROAD.size.x, 10), Color("#b08f62"))
	for rut_y in [ROAD.position.y + 48, ROAD.position.y + 102]:
		draw_line(Vector2(ROAD.position.x, rut_y), Vector2(ROAD.end.x, rut_y), Color("#9c7c52"), 7.0)
		draw_line(Vector2(ROAD.position.x, rut_y + 4), Vector2(ROAD.end.x, rut_y + 4), Color("#d6b788"), 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # the same stones every time
	for i in range(220):
		var p := Vector2(rng.randf_range(ROAD.position.x, ROAD.end.x), rng.randf_range(ROAD.position.y + 12, ROAD.end.y - 12))
		draw_circle(p, rng.randf_range(1.0, 2.6), Color("#8f714b", 0.55))

## A person seen from above: shadow, shoulders, hat brim, crown.
func _draw_person(target: CanvasItem, at: Vector2, brim: Color, crown: Color, is_player: bool,
		dusty: bool = false) -> void:
	target.draw_circle(at + Vector2(4, 6), 17.0, Color(0, 0, 0, 0.32))
	# Shoulders, then the hat on top.
	target.draw_colored_polygon(_ellipse(at + Vector2(0, 2), Vector2(17, 11)),
		Color("#3b4a5e") if is_player else Color("#4a3424"))
	var hat_offset := Vector2(-3, -2) if dusty else Vector2.ZERO
	target.draw_circle(at + hat_offset, 13.0, brim)
	target.draw_arc(at + hat_offset, 13.0, 0.0, TAU, 32, Color(0, 0, 0, 0.35), 1.5)
	target.draw_circle(at + hat_offset, 7.0, crown)
	target.draw_line(at + hat_offset + Vector2(-7, 0), at + hat_offset + Vector2(7, 0), Color("#8a6a3e"), 2.0)
	if is_player:
		target.draw_arc(at, 19.0, 0.0, TAU, 40, Color("#f0d7a1", 0.9), 2.5)
	if dusty:
		for p in [Vector2(-12, 9), Vector2(10, 11), Vector2(14, -4), Vector2(-14, -7), Vector2(3, 15)]:
			target.draw_circle(at + p, 2.2, Color("#a08a64", 0.85))

func _ellipse(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points

func _draw_riverboat(at: Vector2) -> void:
	var hull := PackedVector2Array([at, at + Vector2(330, 0), at + Vector2(380, 55), at + Vector2(330, 110),
		at + Vector2(0, 110)])
	draw_colored_polygon(hull, Color("#efe6d0"))
	draw_polyline(hull + PackedVector2Array([at]), Color("#2a2420"), 3.0)
	draw_rect(Rect2(at + Vector2(30, 15), Vector2(250, 80)), Color("#7c2f26"))
	draw_rect(Rect2(at + Vector2(-46, 10), Vector2(46, 90)), Color("#5b2330"))
	for i in range(5):
		draw_line(at + Vector2(-46, 18 + i * 18), at + Vector2(0, 18 + i * 18), Color("#2a2420"), 2.0)
	draw_circle(at + Vector2(110, 30), 11.0, Color("#18181d"))
	draw_circle(at + Vector2(110, 80), 11.0, Color("#18181d"))
	draw_rect(Rect2(at + Vector2(175, 38), Vector2(80, 34)), Color("#d9b45a"))
	draw_string(ThemeDB.fallback_font, at + Vector2(46, 128), "THE GILDED RIVERBOAT", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 15, Color("#e8c56a"))
