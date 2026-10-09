extends SceneTree

# Generated poses may cross nominal column edges. Extract each connected
# silhouette, then place it inside one cell with a guaranteed transparent gutter.
const UNITS := ["warrior", "mage", "cleric", "archer", "small-goblin", "armored-goblin", "wolf"]
const COLUMNS := 8
const MIN_SILHOUETTE_PIXELS := 3000


func _init() -> void:
	for unit_id in UNITS:
		var source: String = ProjectSettings.globalize_path("res://assets/animation_chroma/%s.png" % unit_id)
		var destination: String = ProjectSettings.globalize_path("res://assets/%s-animation-8f.png" % unit_id)
		var image: Image = Image.load_from_file(source)
		if image == null or image.is_empty():
			push_error("Cannot read sprite sheet: %s" % source)
			quit(1)
			return
		image.convert(Image.FORMAT_RGBA8)
		_key_green(image)
		var rows: int = 3 if unit_id in ["warrior", "small-goblin", "armored-goblin", "wolf"] else 4
		var packed: Image = _pack_frames(image, rows)
		var error: Error = packed.save_png(destination)
		if error != OK:
			push_error("Cannot write sprite sheet: %s (%d)" % [destination, error])
			quit(1)
			return
		print("Created %s" % destination)
	quit()


func _key_green(image: Image) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			var green_excess: float = color.g - maxf(color.r, color.b)
			if color.g <= 0.56 or green_excess <= 0.25:
				continue
			var alpha: float = clampf((0.60 - green_excess) / 0.35, 0.0, 1.0)
			if alpha < 0.18:
				color = Color.TRANSPARENT
			else:
				color.r = clampf((color.r - (1.0 - alpha) * 0.012) / alpha, 0.0, 1.0)
				color.g = clampf((color.g - (1.0 - alpha) * 0.98) / alpha, 0.0, 1.0)
				color.b = clampf((color.b - (1.0 - alpha) * 0.012) / alpha, 0.0, 1.0)
				color.a = alpha
			image.set_pixel(x, y, color)
	# Remove the bright green spill left on anti-aliased silhouette edges.
	var keyed: Image = image.duplicate()
	for y in range(1, image.get_height() - 1):
		for x in range(1, image.get_width() - 1):
			var color: Color = keyed.get_pixel(x, y)
			if color.a < 0.2 or color.g < 0.42 or color.g - maxf(color.r, color.b) < 0.14:
				continue
			if keyed.get_pixel(x - 1, y).a < 0.35 or keyed.get_pixel(x + 1, y).a < 0.35 or keyed.get_pixel(x, y - 1).a < 0.35 or keyed.get_pixel(x, y + 1).a < 0.35:
				color.g = minf(color.g, maxf(color.r, color.b) + 0.08)
				image.set_pixel(x, y, color)


func _pack_frames(source: Image, rows: int) -> Image:
	var width: int = source.get_width()
	var height: int = source.get_height()
	var result: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for row in range(rows):
		var top: int = roundi(float(row * height) / rows)
		var bottom: int = roundi(float((row + 1) * height) / rows)
		var row_height: int = bottom - top
		var labels := PackedInt32Array()
		labels.resize(width * row_height)
		var silhouettes: Array[Dictionary] = []
		for y in range(row_height):
			for x in range(width):
				var index: int = y * width + x
				if labels[index] != 0 or source.get_pixel(x, top + y).a < 0.6:
					continue
				var label: int = silhouettes.size() + 1
				var queue := PackedInt32Array([index])
				labels[index] = label
				var head: int = 0
				var min_x: int = x
				var max_x: int = x
				var min_y: int = y
				var max_y: int = y
				while head < queue.size():
					var point: int = queue[head]
					head += 1
					var px: int = point % width
					var py: int = point / width
					min_x = mini(min_x, px)
					max_x = maxi(max_x, px)
					min_y = mini(min_y, py)
					max_y = maxi(max_y, py)
					for next in [point - 1, point + 1, point - width, point + width]:
						if next < 0 or next >= width * row_height or labels[next] != 0:
							continue
						if absi(next % width - px) + absi(next / width - py) != 1:
							continue
						if source.get_pixel(next % width, top + next / width).a < 0.6:
							continue
						labels[next] = label
						queue.append(next)
				silhouettes.append({"label": label, "size": queue.size(), "left": min_x, "right": max_x, "top": min_y, "bottom": max_y})
		var poses: Array[Dictionary] = []
		for silhouette in silhouettes:
			if silhouette["size"] >= MIN_SILHOUETTE_PIXELS:
				poses.append(silhouette)
		poses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["left"] < b["left"])
		var slots: Array[Dictionary] = []
		slots.resize(COLUMNS)
		if poses.size() == COLUMNS:
			for column in range(COLUMNS):
				slots[column] = poses[column]
		else:
			print("Row %d has %d separate poses; empty slots use the nearest pose" % [row, poses.size()])
			for pose in poses:
				var center_x: float = (float(pose["left"]) + float(pose["right"])) * 0.5
				var slot: int = clampi(roundi(center_x * COLUMNS / width - 0.5), 0, COLUMNS - 1)
				slots[slot] = pose
			for column in range(COLUMNS):
				if slots[column].is_empty() and not poses.is_empty():
					slots[column] = poses[clampi(column, 0, poses.size() - 1)]
		for column in range(COLUMNS):
			if not slots[column].is_empty():
				_place_pose(source, result, labels, width, top, bottom, column, slots[column])
	return result


func _place_pose(source: Image, result: Image, labels: PackedInt32Array, width: int, top: int, bottom: int, column: int, pose: Dictionary) -> void:
	var min_x: int = maxi(0, int(pose["left"]) - 2)
	var max_x: int = mini(width - 1, int(pose["right"]) + 2)
	var min_y: int = maxi(0, int(pose["top"]) - 2)
	var max_y: int = mini(bottom - top - 1, int(pose["bottom"]) + 2)
	var cutout: Image = Image.create_empty(max_x - min_x + 1, max_y - min_y + 1, false, Image.FORMAT_RGBA8)
	cutout.fill(Color.TRANSPARENT)
	var label: int = pose["label"]
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var index: int = y * width + x
			var belongs: bool = labels[index] == label
			if not belongs:
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						var nx: int = x + ox
						var ny: int = y + oy
						if nx >= 0 and nx < width and ny >= 0 and ny < bottom - top and labels[ny * width + nx] == label:
							belongs = true
			if belongs:
				cutout.set_pixel(x - min_x, y - min_y, source.get_pixel(x, top + y))
	var cell_left: int = roundi(float(column * width) / COLUMNS)
	var cell_right: int = roundi(float((column + 1) * width) / COLUMNS)
	var cell_width: int = cell_right - cell_left
	var cell_height: int = bottom - top
	var scale: float = minf(float(cell_width) * 0.82 / cutout.get_width(), float(cell_height) * 0.86 / cutout.get_height())
	var new_width: int = maxi(1, roundi(cutout.get_width() * scale))
	var new_height: int = maxi(1, roundi(cutout.get_height() * scale))
	cutout.resize(new_width, new_height, Image.INTERPOLATE_BILINEAR)
	var destination := Vector2i(cell_left + (cell_width - new_width) / 2, top + roundi(cell_height * 0.95) - new_height)
	result.blend_rect(cutout, Rect2i(Vector2i.ZERO, cutout.get_size()), destination)
