extends RefCounted

const GRID_SIZE := 10
const SLOT_ORDER := ["right_hand", "left_hand", "body", "head", "back"]
const SLOT_SIZE_CELLS := {
	"right_hand": Vector2i(2, 3),
	"left_hand": Vector2i(2, 3),
	"body": Vector2i(2, 3),
	"head": Vector2i(2, 2),
	"back": Vector2i(2, 3)
}


static func equip(profile: Dictionary, inventory_index: int, definitions: Dictionary) -> bool:
	var inventory: Array = profile.get("inventory", [])
	if inventory_index < 0 or inventory_index >= inventory.size():
		return false
	var entry: Dictionary = inventory[inventory_index]
	var item_id: String = str(entry.get("item_id", ""))
	var item: Dictionary = definitions.get(item_id, {})
	if item.is_empty():
		return false
	var equipped: Dictionary = profile.get("equipped", {}).duplicate(true)
	var target_slot: String = _choose_slot(item, equipped, definitions)
	if target_slot == "":
		return false
	var remaining: Array = inventory.duplicate(true)
	remaining.remove_at(inventory_index)
	var previous_item_id: String = str(equipped.get(target_slot, ""))
	if previous_item_id != "":
		var previous_item: Dictionary = definitions.get(previous_item_id, {})
		if previous_item.is_empty():
			return false
		var preferred: Dictionary = entry.get("position_cells", {})
		var free_cell: Vector2i = _find_free_cell(remaining, previous_item, definitions, Vector2i(int(preferred.get("x", -1)), int(preferred.get("y", -1))))
		if free_cell.x < 0:
			return false
		remaining.append({"item_id": previous_item_id, "position_cells": {"x": free_cell.x, "y": free_cell.y}})
	equipped[target_slot] = item_id
	profile["inventory"] = remaining
	profile["equipped"] = equipped
	return true


static func unequip(profile: Dictionary, slot: String, definitions: Dictionary) -> bool:
	var equipped: Dictionary = profile.get("equipped", {}).duplicate(true)
	var item_id: String = str(equipped.get(slot, ""))
	if item_id == "":
		return false
	var item: Dictionary = definitions.get(item_id, {})
	if item.is_empty():
		return false
	var inventory: Array = profile.get("inventory", []).duplicate(true)
	var free_cell: Vector2i = _find_free_cell(inventory, item, definitions)
	if free_cell.x < 0:
		return false
	inventory.append({"item_id": item_id, "position_cells": {"x": free_cell.x, "y": free_cell.y}})
	equipped.erase(slot)
	profile["inventory"] = inventory
	profile["equipped"] = equipped
	return true


static func _choose_slot(item: Dictionary, equipped: Dictionary, definitions: Dictionary) -> String:
	var allowed: Array = item.get("equip_slots", [])
	# Replacing an item of the same kind takes priority over an empty hand.
	for slot in SLOT_ORDER:
		if not allowed.has(slot) or not _fits_slot(item, str(slot)):
			continue
		var other_id: String = str(equipped.get(slot, ""))
		var other_item: Dictionary = definitions.get(other_id, {})
		if other_id != "" and _same_type(item, other_item):
			return str(slot)
	for slot in SLOT_ORDER:
		if allowed.has(slot) and _fits_slot(item, str(slot)) and str(equipped.get(slot, "")) == "":
			return str(slot)
	for slot in SLOT_ORDER:
		if allowed.has(slot) and _fits_slot(item, str(slot)):
			return str(slot)
	return ""


static func _fits_slot(item: Dictionary, slot: String) -> bool:
	var capacity: Vector2i = SLOT_SIZE_CELLS.get(slot, Vector2i.ZERO)
	var size: Dictionary = item.get("size_cells", {})
	var width: int = int(size.get("width", 0))
	var height: int = int(size.get("height", 0))
	return width > 0 and height > 0 and width <= capacity.x and height <= capacity.y


static func _same_type(first: Dictionary, second: Dictionary) -> bool:
	if second.is_empty() or str(first.get("category", "")) != str(second.get("category", "")):
		return false
	var category: String = str(first.get("category", ""))
	if category == "weapon":
		var first_weapon: Dictionary = first.get("weapon", {})
		var second_weapon: Dictionary = second.get("weapon", {})
		return str(first_weapon.get("type", "")) == str(second_weapon.get("type", ""))
	if category == "armor":
		var first_armor: Dictionary = first.get("armor", {})
		var second_armor: Dictionary = second.get("armor", {})
		return str(first_armor.get("type", "")) == str(second_armor.get("type", ""))
	return false


static func _find_free_cell(inventory: Array, item: Dictionary, definitions: Dictionary, preferred: Vector2i = Vector2i(-1, -1)) -> Vector2i:
	if _cell_fits(inventory, item, definitions, preferred):
		return preferred
	for row in range(GRID_SIZE):
		for column in range(GRID_SIZE):
			var cell := Vector2i(column, row)
			if _cell_fits(inventory, item, definitions, cell):
				return cell
	return Vector2i(-1, -1)


static func _cell_fits(inventory: Array, item: Dictionary, definitions: Dictionary, cell: Vector2i) -> bool:
	var size: Dictionary = item.get("size_cells", {})
	var width: int = int(size.get("width", 0))
	var height: int = int(size.get("height", 0))
	if cell.x < 0 or cell.y < 0 or width < 1 or height < 1 or cell.x + width > GRID_SIZE or cell.y + height > GRID_SIZE:
		return false
	for entry in inventory:
		if not entry is Dictionary:
			continue
		var other: Dictionary = definitions.get(str(entry.get("item_id", "")), {})
		var other_size: Dictionary = other.get("size_cells", {})
		var position: Dictionary = entry.get("position_cells", {})
		var other_x: int = int(position.get("x", -1))
		var other_y: int = int(position.get("y", -1))
		var other_width: int = int(other_size.get("width", 0))
		var other_height: int = int(other_size.get("height", 0))
		if cell.x < other_x + other_width and cell.x + width > other_x and cell.y < other_y + other_height and cell.y + height > other_y:
			return false
	return true
