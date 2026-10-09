extends RefCounted

const ROWS := 4
const COLUMNS := 4
const CELL_SIZE := Vector2(280.0, 180.0)
const TOP_LEFT := Vector2(400.0, 164.0)
const HERO_ROWS := [0, 1, 2, 3]
const DIRECTIONS := [
	Vector2i(-1, 0), Vector2i(0, -1),
	Vector2i(0, 1), Vector2i(1, 0)
]


static func valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLUMNS and cell.y >= 0 and cell.y < ROWS


static func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(TOP_LEFT + Vector2(cell) * CELL_SIZE, CELL_SIZE)


static func center(cell: Vector2i) -> Vector2:
	return cell_rect(cell).get_center()


static func attack_distance(first: Vector2i, second: Vector2i) -> int:
	return absi(first.x - second.x)


static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var next_cell: Vector2i = cell + direction
		if valid(next_cell):
			result.append(next_cell)
	return result
