extends SceneTree
## Prepares the Jarppix western sheets (local-only art, see
## assets/third_party/README.md): removes each sheet's solid background by
## flood-filling from the edges, saves `<name>_keyed.png` beside it, and prints
## every sprite's bounding box so the town can reference them by rectangle.
## Run: godot --headless --path . -s tools/prepare_jarppix.gd

const DIR := "res://assets/third_party/jarppix_western/"
const SHEETS := ["houses mountains", "peoples buildings other", "buildings other", "Plants and fences"]
const TOLERANCE := 0.06
const MIN_AREA := 40

func _init() -> void:
	for name in SHEETS:
		var path := ProjectSettings.globalize_path(DIR + name + ".png")
		var image := Image.load_from_file(path)
		if image == null:
			push_error("missing " + path)
			continue
		image.convert(Image.FORMAT_RGBA8)
		_key_background(image)
		image.save_png(ProjectSettings.globalize_path(DIR + name + "_keyed.png"))
		print("== %s (%dx%d)" % [name, image.get_width(), image.get_height()])
		for box in _components(image):
			print("  ", box)
	quit(0)

## Clear every pixel connected to the border that matches the corner colour.
func _key_background(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var bg := image.get_pixel(0, 0)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[int] = []
	for x in range(w):
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in range(h):
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		if seen[i] == 1:
			continue
		seen[i] = 1
		var x := i % w
		var y := i / w
		var c := image.get_pixel(x, y)
		if absf(c.r - bg.r) > TOLERANCE or absf(c.g - bg.g) > TOLERANCE or absf(c.b - bg.b) > TOLERANCE:
			continue
		image.set_pixel(x, y, Color(0, 0, 0, 0))
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)

## Bounding boxes of opaque regions (8-connected), largest first.
func _components(image: Image) -> Array:
	var w := image.get_width()
	var h := image.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var boxes: Array = []
	for start in range(w * h):
		if seen[start] == 1 or image.get_pixel(start % w, start / w).a == 0.0:
			continue
		var stack: Array[int] = [start]
		var x0 := w
		var y0 := h
		var x1 := 0
		var y1 := 0
		var area := 0
		while not stack.is_empty():
			var i: int = stack.pop_back()
			if seen[i] == 1:
				continue
			seen[i] = 1
			var x := i % w
			var y := i / w
			if image.get_pixel(x, y).a == 0.0:
				continue
			area += 1
			x0 = mini(x0, x); y0 = mini(y0, y); x1 = maxi(x1, x); y1 = maxi(y1, y)
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if nx >= 0 and ny >= 0 and nx < w and ny < h:
						stack.append(ny * w + nx)
		if area >= MIN_AREA:
			boxes.append(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1))
	boxes.sort_custom(func(a, b): return a.get_area() > b.get_area())
	return boxes
