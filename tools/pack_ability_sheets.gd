extends SceneTree

# Pack the image-generated action strips into the same frame geometry as the
# existing battle atlases. Connected silhouettes can cross their nominal source
# columns, so cutting the source on a regular grid would show neighboring poses.
const ACTION_ROWS := {"warrior": 3, "mage": 2, "cleric": 2, "archer": 2}
const COLUMNS := 8
const MIN_POSE_PIXELS := 5000


func _init() -> void:
	for class_id in ACTION_ROWS:
		var source_path: String = ProjectSettings.globalize_path("res://assets/ability_animation/%s-abilities.png" % class_id)
		var reference_path: String = ProjectSettings.globalize_path("res://assets/%s-animation-8f.png" % class_id)
		var destination_path: String = ProjectSettings.globalize_path("res://assets/ability_animation/%s-abilities-packed.png" % class_id)
		var source: Image = Image.load_from_file(source_path)
		var reference: Image = Image.load_from_file(reference_path)
		if source == null or source.is_empty() or reference == null or reference.is_empty():
			push_error("Cannot read ability sheet or reference for %s" % class_id)
			quit(1)
			return
		source.convert(Image.FORMAT_RGBA8)
		var packed: Image = _pack(source, int(ACTION_ROWS[class_id]), reference.get_size())
		if packed == null:
			quit(1)
			return
		var error: Error = packed.save_png(destination_path)
		if error != OK:
			push_error("Cannot save %s (%d)" % [destination_path, error])
			quit(1)
			return
		print("Packed %s" % destination_path)
	quit()


func _pack(source: Image, rows: int, atlas_size: Vector2i) -> Image:
	var width: int = source.get_width()
	var height: int = source.get_height()
	var pose_rows: Array[Array] = []
	var widest: int = 1
	var tallest: int = 1
	for row in range(rows):
		var top: int = roundi(float(row * height) / rows)
		var bottom: int = roundi(float((row + 1) * height) / rows)
		var row_height: int = bottom - top
		var labels := PackedInt32Array()
		labels.resize(width * row_height)
		var poses: Array[Dictionary] = []
		var next_label := 0
		for y in range(row_height):
			for x in range(width):
				var index: int = y * width + x
				if labels[index] != 0 or source.get_pixel(x, top + y).a < 0.6:
					continue
				next_label += 1
				var label: int = next_label
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
						if next < 0 or next >= labels.size() or labels[next] != 0:
							continue
						if absi(next % width - px) + absi(next / width - py) != 1:
							continue
						if source.get_pixel(next % width, top + next / width).a < 0.6:
							continue
						labels[next] = label
						queue.append(next)
				if queue.size() >= MIN_POSE_PIXELS:
					poses.append({"label": label, "left": min_x, "right": max_x, "top": min_y, "bottom": max_y})
		# Small disconnected sparkles do not count as independent character poses.
		if poses.size() != COLUMNS:
			push_error("Expected 8 poses in row %d, found %d" % [row, poses.size()])
			return null
		poses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["left"] < b["left"])
		for pose in poses:
			widest = maxi(widest, int(pose["right"]) - int(pose["left"]) + 5)
			tallest = maxi(tallest, int(pose["bottom"]) - int(pose["top"]) + 5)
		pose_rows.append([top, bottom, labels, poses])
	var result_height: int = roundi(float(atlas_size.y) * rows / (3.0 if rows == 3 else 4.0))
	var result: Image = Image.create_empty(atlas_size.x, result_height, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var cell_width: float = float(atlas_size.x) / COLUMNS
	var cell_height: float = float(result_height) / rows
	var uniform_scale: float = minf(cell_width * 0.88 / widest, cell_height * 0.86 / tallest)
	for row in range(rows):
		var data: Array = pose_rows[row]
		var labels: PackedInt32Array = data[2]
		var poses: Array[Dictionary] = data[3]
		for column in range(COLUMNS):
			_place_pose(source, result, labels, width, int(data[0]), int(data[1]),
				row, column, rows, poses[column], uniform_scale)
	return result


func _place_pose(source: Image, result: Image, labels: PackedInt32Array, source_width: int,
		row_top: int, row_bottom: int, row: int, column: int, rows: int, pose: Dictionary, scale: float) -> void:
	var min_x: int = maxi(0, int(pose["left"]) - 2)
	var max_x: int = mini(source_width - 1, int(pose["right"]) + 2)
	var min_y: int = maxi(0, int(pose["top"]) - 2)
	var max_y: int = mini(row_bottom - row_top - 1, int(pose["bottom"]) + 2)
	var cutout: Image = Image.create_empty(max_x - min_x + 1, max_y - min_y + 1, false, Image.FORMAT_RGBA8)
	cutout.fill(Color.TRANSPARENT)
	var label: int = int(pose["label"])
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var belongs: bool = labels[y * source_width + x] == label
			if not belongs:
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						var nx: int = x + ox
						var ny: int = y + oy
						if nx >= 0 and nx < source_width and ny >= 0 and ny < row_bottom - row_top and labels[ny * source_width + nx] == label:
							belongs = true
			if belongs:
				cutout.set_pixel(x - min_x, y - min_y, source.get_pixel(x, row_top + y))
	var new_width: int = maxi(1, roundi(cutout.get_width() * scale))
	var new_height: int = maxi(1, roundi(cutout.get_height() * scale))
	cutout.resize(new_width, new_height, Image.INTERPOLATE_BILINEAR)
	var cell_left: int = roundi(float(column * result.get_width()) / COLUMNS)
	var cell_right: int = roundi(float((column + 1) * result.get_width()) / COLUMNS)
	var cell_top: int = roundi(float(row * result.get_height()) / rows)
	var cell_bottom: int = roundi(float((row + 1) * result.get_height()) / rows)
	var cell_height: int = cell_bottom - cell_top
	var destination := Vector2i(cell_left + (cell_right - cell_left - new_width) / 2,
		cell_top + roundi(cell_height * 0.95) - new_height)
	result.blend_rect(cutout, Rect2i(Vector2i.ZERO, cutout.get_size()), destination)
