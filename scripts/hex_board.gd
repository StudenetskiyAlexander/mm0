extends RefCounted

const ROWS := 9
const COLUMNS := 10
const RADIUS := 58.0
const ORIGIN := Vector2(490.0, 160.0)
const HORIZONTAL_STEP := 1.7320508075688772 * RADIUS
const VERTICAL_STEP := 1.5 * RADIUS
const HERO_ROWS := [1, 3, 5, 7]
const AXIAL_DIRECTIONS := [
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1)
]

static func valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLUMNS and cell.y >= 0 and cell.y < ROWS


static func center(cell: Vector2i) -> Vector2:
	var stagger := 0.5 if cell.y % 2 == 1 else 0.0
	return ORIGIN + Vector2((float(cell.x) + stagger) * HORIZONTAL_STEP, float(cell.y) * VERTICAL_STEP)


static func corners(cell: Vector2i) -> PackedVector2Array:
	var points := PackedVector2Array()
	var origin := center(cell)
	for index in range(6):
		var angle := deg_to_rad(-90.0 + 60.0 * float(index))
		points.append(origin + Vector2(cos(angle), sin(angle)) * RADIUS)
	return points


static func to_axial(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x - floori(float(cell.y - (cell.y & 1)) / 2.0), cell.y)


static func from_axial(axial: Vector2i) -> Vector2i:
	return Vector2i(axial.x + floori(float(axial.y - (axial.y & 1)) / 2.0), axial.y)


static func distance(first: Vector2i, second: Vector2i) -> int:
	var a := to_axial(first)
	var b := to_axial(second)
	var dq := a.x - b.x
	var dr := a.y - b.y
	return floori(float(absi(dq) + absi(dr) + absi(dq + dr)) / 2.0)


static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin := to_axial(cell)
	for direction in AXIAL_DIRECTIONS:
		var next_cell := from_axial(origin + direction)
		if valid(next_cell):
			result.append(next_cell)
	return result
