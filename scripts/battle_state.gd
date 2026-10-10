extends RefCounted

signal event_logged(message: String)
signal battle_ended(victory: bool)
signal visual_event(event: Dictionary)

const BOARD = preload("res://scripts/battle_board.gd")
const COMBATANT = preload("res://scripts/combatant.gd")
const INVENTORY_STATE = preload("res://scripts/inventory_state.gd")
const PROJECTILE_LAUNCH_DELAY := 0.32
const ACTION_ANIMATION_TIME := 0.55
const ENEMY_MOVE_CELLS_PER_TURN := 1

var heroes: Array = []
var enemies: Array = []
var enemy_queue: Array[Dictionary] = []
var enemies_remaining_to_spawn := 0
var selected_hero := -1
var phase := "heroes"
var round_number := 0
var hero_turn_cursor := 0
var enemy_turn_cursor := 0
var enemy_turn_limit := 0
var turn_delay := 0.0
var defeated_enemies := 0
var pending_projectiles: Array[Dictionary] = []
var ended := false
var won := false
var rng := RandomNumberGenerator.new()


func start(hero_profiles: Array[Dictionary], selected_enemies: Array[Dictionary], equipment_definitions: Dictionary = {}) -> void:
	rng.randomize()
	heroes.clear()
	enemies.clear()
	enemy_queue = selected_enemies.duplicate(true)
	enemies_remaining_to_spawn = 0
	for entry in enemy_queue:
		enemies_remaining_to_spawn += int(entry.get("count", 0))
	selected_hero = -1
	phase = "heroes"
	round_number = 0
	hero_turn_cursor = 0
	enemy_turn_cursor = 0
	enemy_turn_limit = 0
	turn_delay = 0.0
	defeated_enemies = 0
	pending_projectiles.clear()
	ended = false
	for index in range(hero_profiles.size()):
		var unit = COMBATANT.new()
		unit.initialize(hero_profiles[index], true, Vector2i(0, BOARD.HERO_ROWS[index]), equipment_definitions)
		heroes.append(unit)
	_log("Бой начался. Герои: %d; выбрано врагов: %d." % [heroes.size(), enemies_remaining_to_spawn])
	_begin_round()
	_check_end()


func tick(delta: float) -> void:
	if ended:
		return
	_advance_projectiles(delta)
	_check_end()
	if ended:
		return
	turn_delay = maxf(0.0, turn_delay - delta)
	if turn_delay > 0.0:
		return
	_fill_spawn_cells()
	if phase == "heroes":
		if selected_hero < 0:
			_advance_hero_turn()
	else:
		_take_next_enemy_turn()
	_check_end()


func select_hero(index: int) -> bool:
	return can_hero_act(index)


func can_hero_act(index: int) -> bool:
	return not ended and phase == "heroes" and turn_delay <= 0.0 and index == selected_hero and index >= 0 and index < heroes.size() and heroes[index].conscious()


func skip_current_hero() -> void:
	if not can_hero_act(selected_hero):
		return
	_log("%s пропускает ход." % heroes[selected_hero].name())
	hero_turn_cursor = selected_hero + 1
	selected_hero = -1
	_advance_hero_turn()


func _begin_round() -> void:
	round_number += 1
	phase = "heroes"
	hero_turn_cursor = 0
	enemy_turn_cursor = 0
	enemy_turn_limit = 0
	selected_hero = -1
	_log("Раунд %d: ход героев." % round_number)
	_fill_spawn_cells()
	_advance_hero_turn()


func _advance_hero_turn() -> void:
	while hero_turn_cursor < heroes.size():
		var index := hero_turn_cursor
		hero_turn_cursor += 1
		if heroes[index].conscious():
			selected_hero = index
			return
	selected_hero = -1
	phase = "enemies"
	enemy_turn_cursor = 0
	enemy_turn_limit = enemies.size()
	_log("Раунд %d: ход врагов." % round_number)


func _take_next_enemy_turn() -> void:
	while enemy_turn_cursor < enemy_turn_limit:
		var enemy = enemies[enemy_turn_cursor]
		enemy_turn_cursor += 1
		if enemy.conscious():
			_update_enemy(enemy)
			return
	_begin_round()


func available_enemy_targets(index: int, action_id: String) -> Array:
	var targets: Array = []
	if not can_hero_act(index):
		return targets
	var hero = heroes[index]
	if not hero.has_action(action_id):
		return targets
	var minimum_range := 1
	var maximum_range := -1
	match action_id:
		"melee_attack":
			maximum_range = 1
		"shoot":
			if not can_shoot(hero):
				return targets
			minimum_range = int(hero.weapon(true).get("minimum_attack_range_cells", 2))
		"fire_arrow":
			if hero.mana < 5:
				return targets
		_:
			return targets
	for enemy in enemies:
		if not enemy.conscious():
			continue
		var distance: int = BOARD.attack_distance(hero.cell, enemy.cell)
		if distance >= minimum_range and (maximum_range < 0 or distance <= maximum_range):
			targets.append(enemy)
	return targets


func available_heal_targets(index: int) -> Array:
	var targets: Array = []
	if not can_hero_act(index):
		return targets
	var caster = heroes[index]
	if not caster.has_action("quick_heal") or caster.mana < 5:
		return targets
	for hero in heroes:
		if hero.alive():
			targets.append(hero)
	return targets


func perform_selected(action_id: String, target_override = null) -> bool:
	return perform_action(selected_hero, action_id, target_override)


func perform_action(index: int, action_id: String, target_override = null) -> bool:
	if not can_hero_act(index):
		return false
	var hero = heroes[index]
	var enemy_target = null
	if action_id == "melee_attack" or action_id == "shoot" or action_id == "fire_arrow":
		var targets: Array = available_enemy_targets(index, action_id)
		if target_override != null:
			if not targets.has(target_override):
				return false
			enemy_target = target_override
		elif not targets.is_empty():
			enemy_target = targets[rng.randi_range(0, targets.size() - 1)]
	if action_id == "quick_heal" and target_override != null:
		if not available_heal_targets(index).has(target_override):
			return false
	if action_id == "health_potion":
		if hero.health_potions <= 0:
			return false
		hero.health_potions -= 1
		var recovered: int = hero.restore_health(10)
		if recovered > 0:
			_log("%s выпивает зелье здоровья: +%d здоровья (%d/%d)." % [hero.name(), recovered, hero.health, hero.max_health()])
		else:
			_log("%s выпивает зелье здоровья при полном запасе (%d/%d)." % [hero.name(), hero.health, hero.max_health()])
		visual_event.emit({"kind": "health_potion", "unit": hero, "amount": recovered})
	elif action_id == "mana_potion":
		if hero.mana_potions <= 0:
			return false
		hero.mana_potions -= 1
		var recovered: int = hero.restore_mana(10)
		if recovered > 0:
			_log("%s выпивает зелье маны: +%d маны (%d/%d)." % [hero.name(), recovered, hero.mana, hero.max_mana()])
		else:
			_log("%s выпивает зелье маны при полном запасе (%d/%d)." % [hero.name(), hero.mana, hero.max_mana()])
		visual_event.emit({"kind": "mana_potion", "unit": hero, "amount": recovered})
	elif not hero.has_action(action_id):
		return false
	elif action_id == "melee_attack":
		var target = enemy_target
		if target == null:
			_log("%s атакует пустую клетку." % hero.name())
			visual_event.emit({"kind": "melee", "unit": hero, "target": null, "hit": false, "damage": 0})
		else:
			_physical_attack(hero, target, false)
	elif action_id == "shoot":
		if not can_shoot(hero):
			return false
		var target = enemy_target
		if target == null:
			_log("%s выпускает стрелу, но подходящей цели нет." % hero.name())
			visual_event.emit({"kind": "shoot", "unit": hero, "target": null, "hit": false, "damage": 0})
			turn_delay = _empty_projectile_delay("shoot")
		else:
			_physical_attack(hero, target, true)
	elif action_id == "fire_arrow":
		if hero.mana < 5:
			return false
		hero.mana -= 5
		var target = enemy_target
		if target == null:
			_log("%s выпускает Огненную стрелу без цели." % hero.name())
			visual_event.emit({"kind": "fire_arrow", "unit": hero, "target": null, "hit": false, "damage": 0})
			turn_delay = _empty_projectile_delay("fire_arrow")
		else:
			var damage := _roll_dice("1d8")
			var result := "%s применяет Огненную стрелу к %s: 1д8 = %d урона." % [hero.name(), target.name(), damage]
			_launch_projectile(hero, target, "fire_arrow", true, damage, result)
	elif action_id == "quick_heal":
		if hero.mana < 5:
			return false
		hero.mana -= 5
		var target = target_override if target_override != null else _lowest_health_hero()
		if target == null:
			_log("%s применяет Быстрое лечение без цели." % hero.name())
			visual_event.emit({"kind": "quick_heal", "unit": hero, "target": null, "amount": 0, "revived": false})
		else:
			var was_unconscious: bool = not target.conscious()
			var recovered: int = target.restore_health(6)
			if recovered > 0:
				_log("%s лечит %s: +%d здоровья (%d/%d)." % [hero.name(), target.name(), recovered, target.health, target.max_health()])
			else:
				_log("%s лечит %s: здоровье уже полное (%d/%d)." % [hero.name(), target.name(), target.health, target.max_health()])
			visual_event.emit({"kind": "quick_heal", "unit": hero, "target": target, "amount": recovered, "revived": was_unconscious and target.conscious()})
	else:
		return false
	turn_delay = maxf(turn_delay, ACTION_ANIMATION_TIME)
	hero_turn_cursor = index + 1
	selected_hero = -1
	_check_end()
	return true


func _update_enemy(enemy) -> void:
	var target = _nearest_hero(enemy.cell)
	if target == null:
		return
	var weapon: Dictionary = enemy.weapon()
	var attack_range := int(weapon.get("attack_range_cells", 1))
	if BOARD.attack_distance(enemy.cell, target.cell) <= attack_range:
		_physical_attack(enemy, target, false)
		turn_delay = ACTION_ANIMATION_TIME
		return
	var next_cell := _next_step(enemy.cell, target.cell, attack_range)
	if next_cell.x < 0:
		turn_delay = 0.16
		return
	visual_event.emit({"kind": "move", "unit": enemy, "from_cell": enemy.cell, "to_cell": next_cell, "speed": float(ENEMY_MOVE_CELLS_PER_TURN)})
	enemy.cell = next_cell
	_log("%s перемещается на одну клетку." % enemy.name())
	turn_delay = 0.95


func _fill_spawn_cells() -> void:
	while enemies_remaining_to_spawn > 0:
		if not _spawn_enemy():
			break


func _spawn_enemy() -> bool:
	var free_cells: Array[Vector2i] = []
	for row in range(BOARD.ROWS):
		var cell := Vector2i(BOARD.COLUMNS - 1, row)
		if not _occupied(cell):
			free_cells.append(cell)
	if free_cells.is_empty():
		return false
	var cell := free_cells[rng.randi_range(0, free_cells.size() - 1)]
	var ticket := rng.randi_range(1, enemies_remaining_to_spawn)
	var profile: Dictionary = {}
	for entry in enemy_queue:
		ticket -= int(entry.get("count", 0))
		if ticket <= 0:
			profile = entry.get("profile", {})
			entry["count"] = int(entry.get("count", 0)) - 1
			break
	enemies_remaining_to_spawn -= 1
	var enemy = COMBATANT.new()
	enemy.initialize(profile, false, cell)
	enemies.append(enemy)
	visual_event.emit({"kind": "spawn", "unit": enemy})
	_log("На поле появляется %s (%d/%d здоровья)." % [enemy.name(), enemy.health, enemy.max_health()])
	return true


func _nearest_hero(from_cell: Vector2i):
	var closest: Array = []
	var best_distance := 999
	for hero in heroes:
		if not hero.conscious():
			continue
		var distance: int = BOARD.attack_distance(from_cell, hero.cell)
		if distance < best_distance:
			best_distance = distance
			closest = [hero]
		elif distance == best_distance:
			closest.append(hero)
	if closest.is_empty():
		return null
	return closest[rng.randi_range(0, closest.size() - 1)]


func can_shoot(hero) -> bool:
	if not hero.has_action("shoot"):
		return false
	var minimum_range: int = int(hero.weapon(true).get("minimum_attack_range_cells", 2))
	for enemy in enemies:
		if enemy.conscious() and BOARD.attack_distance(hero.cell, enemy.cell) < minimum_range:
			return false
	return true


func _lowest_health_hero():
	var choices: Array = []
	var lowest := 999999
	for hero in heroes:
		if not hero.alive():
			continue
		if hero.health < lowest:
			lowest = hero.health
			choices = [hero]
		elif hero.health == lowest:
			choices.append(hero)
	if choices.is_empty():
		return null
	return choices[rng.randi_range(0, choices.size() - 1)]


func _physical_attack(attacker, target, ranged: bool) -> void:
	var weapon: Dictionary = attacker.weapon(ranged)
	var attribute_key := "dexterity" if ranged else "strength"
	var attribute_name := "Ловкость" if ranged else "Сила"
	var attribute_value: int = attacker.attribute(attribute_key)
	var skill_name := str(weapon.get("skill_id", ""))
	var skill_value: int = attacker.weapon_skill_bonus(ranged)
	var weapon_bonus: int = attacker.weapon_accuracy_bonus(ranged)
	var distance: int = BOARD.attack_distance(attacker.cell, target.cell)
	var range_penalty: int = maxi(0, distance - 5) * 3 if ranged else 0
	var die := rng.randi_range(1, 20)
	var attack_total: int = attacker.accuracy(ranged) + die - range_penalty
	var armor_name := "Броня"
	if target.is_hero:
		for slot in ["body", "head"]:
			var equipped_armor: Dictionary = target.equipped_item(slot)
			if str(equipped_armor.get("category", "")) == "armor" and INVENTORY_STATE.can_use(target.profile, equipped_armor):
				armor_name = str(equipped_armor.get("name", "Броня"))
				break
	else:
		var armor_value: Variant = target.profile.get("armor", null)
		if armor_value is Dictionary:
			armor_name = str(armor_value.get("name", "Броня"))
	var armor_skill: int = target.armor_skill_bonus()
	var armor_bonus: int = target.armor_equipment_bonus()
	var target_dexterity: int = target.attribute("dexterity")
	var defense_total: int = target.defense()
	var action_name := "стреляет в" if ranged else "атакует"
	var hit: bool = attack_total >= defense_total
	var damage: int = 0
	var attack_parts := PackedStringArray()
	if attribute_value != 0:
		attack_parts.append("%s %d" % [attribute_name, attribute_value])
	if skill_value != 0:
		attack_parts.append("навык %s %d" % [skill_name, skill_value])
	if weapon_bonus != 0:
		attack_parts.append("оружие %d" % weapon_bonus)
	attack_parts.append("1д20 (%d)" % die)
	var attack_expression: String = " + ".join(attack_parts)
	if range_penalty > 0:
		attack_expression += " − штраф дальности %d (%d клет. сверх 5)" % [range_penalty, distance - 5]
	var defense_parts := PackedStringArray(["10"])
	if target_dexterity != 0:
		defense_parts.append("Ловкость %d" % target_dexterity)
	if armor_skill != 0:
		defense_parts.append("%s %d" % [armor_name, armor_skill])
	if armor_bonus != 0:
		defense_parts.append("снаряжение %d" % armor_bonus)
	var details: String = "%s %s %s. Точность: %s = %d. Защита: %s = %d." % [attacker.name(), action_name, target.name(), attack_expression, attack_total, " + ".join(defense_parts), defense_total]
	if hit:
		var damage_dice: String = str(weapon.get("damage_dice", ""))
		var base_damage: int = int(weapon.get("damage_flat", 0))
		if damage_dice != "":
			base_damage = _roll_dice(damage_dice)
		var strength_bonus: int = 0 if ranged else attacker.attribute("strength")
		damage = base_damage + strength_bonus
		var damage_parts := PackedStringArray()
		if damage_dice != "" and base_damage != 0:
			damage_parts.append("%s (%d)" % [damage_dice, base_damage])
		elif base_damage != 0:
			damage_parts.append("без оружия (%d)" % base_damage)
		if strength_bonus != 0:
			damage_parts.append("Сила (%d)" % strength_bonus)
		var damage_details: String = "Урон: %d" % damage
		if not damage_parts.is_empty():
			damage_details = "Урон: %s = %d" % [" + ".join(damage_parts), damage]
		if ranged:
			_launch_projectile(attacker, target, "shoot", true, damage, details + " Попадание. %s." % damage_details)
		else:
			_log(details + " Попадание. %s." % damage_details)
			_apply_damage(attacker, target, damage)
	else:
		if ranged:
			_launch_projectile(attacker, target, "shoot", false, 0, details + " Промах.")
		else:
			_log(details + " Промах.")
	if not ranged:
		visual_event.emit({"kind": "melee", "unit": attacker, "target": target, "hit": hit, "damage": damage})


func _launch_projectile(attacker, target, kind: String, hit: bool, damage: int, result: String) -> void:
	var origin: Vector2 = BOARD.center(attacker.cell)
	var destination: Vector2 = BOARD.center(target.cell)
	var speed := 650.0 if kind == "shoot" else 570.0
	var travel_time: float = clampf(origin.distance_to(destination) / speed, 0.2, 0.72)
	var impact_delay: float = PROJECTILE_LAUNCH_DELAY + travel_time
	turn_delay = maxf(turn_delay, impact_delay)
	pending_projectiles.append({"remaining": impact_delay, "unit": attacker, "target": target, "kind": kind, "hit": hit, "damage": damage, "result": result})
	visual_event.emit({"kind": kind, "unit": attacker, "target": target, "launch_delay": PROJECTILE_LAUNCH_DELAY, "travel_time": travel_time, "impact_delay": impact_delay})


func _empty_projectile_delay(kind: String) -> float:
	var speed := 650.0 if kind == "shoot" else 570.0
	return PROJECTILE_LAUNCH_DELAY + clampf(260.0 / speed, 0.2, 0.72)


func _advance_projectiles(delta: float) -> void:
	for index in range(pending_projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = pending_projectiles[index]
		projectile["remaining"] = float(projectile["remaining"]) - delta
		if float(projectile["remaining"]) > 0.0:
			pending_projectiles[index] = projectile
			continue
		pending_projectiles.remove_at(index)
		var attacker = projectile["unit"]
		var target = projectile["target"]
		var hit: bool = bool(projectile["hit"]) and target.conscious()
		if target.conscious():
			_log(str(projectile["result"]))
			if hit:
				_apply_damage(attacker, target, int(projectile["damage"]))
		else:
			_log("%s: цель уже повержена к моменту попадания." % attacker.name())
		visual_event.emit({"kind": "projectile_impact", "projectile_kind": projectile["kind"], "unit": attacker, "target": target, "hit": hit, "damage": int(projectile["damage"]) if hit else 0})


func _apply_damage(_attacker, target, amount: int) -> void:
	target.health -= amount
	if target.is_hero:
		if target.health < -10:
			_log("%s погибает. Его нельзя вылечить во время боя." % target.name())
		elif target.health <= 0:
			_log("%s теряет сознание." % target.name())
	else:
		if target.health <= 0:
			defeated_enemies += 1
			_log("%s погибает." % target.name())
			if target.cell.x == BOARD.COLUMNS - 1 and enemies_remaining_to_spawn > 0:
				turn_delay = maxf(turn_delay, 0.9)


func _roll_dice(notation: String) -> int:
	var parts := notation.to_lower().split("d")
	if parts.size() != 2:
		return 0
	var count := maxi(0, int(parts[0]))
	var sides := maxi(1, int(parts[1]))
	var total := 0
	for _index in range(count):
		total += rng.randi_range(1, sides)
	return total


func _occupied(cell: Vector2i) -> bool:
	for hero in heroes:
		if hero.cell == cell:
			return true
	for enemy in enemies:
		if enemy.conscious() and enemy.cell == cell:
			return true
	return false


func _next_step(start_cell: Vector2i, target_cell: Vector2i, attack_range: int) -> Vector2i:
	var frontier: Array[Vector2i] = [start_cell]
	var visited := {start_cell: true}
	var previous := {}
	var goal := Vector2i(-1, -1)
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current != start_cell and BOARD.attack_distance(current, target_cell) <= attack_range:
			goal = current
			break
		var candidates: Array[Vector2i] = BOARD.neighbors(current)
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var a_score: int = BOARD.attack_distance(a, target_cell) * 10 + absi(a.y - start_cell.y)
			var b_score: int = BOARD.attack_distance(b, target_cell) * 10 + absi(b.y - start_cell.y)
			return a_score < b_score
		)
		for neighbor in candidates:
			if neighbor.x == 0 or visited.has(neighbor) or _occupied(neighbor):
				continue
			visited[neighbor] = true
			previous[neighbor] = current
			frontier.append(neighbor)
	if goal.x < 0:
		return goal
	while previous[goal] != start_cell:
		goal = previous[goal]
	return goal


func _check_end() -> void:
	if ended:
		return
	var any_conscious := false
	for hero in heroes:
		if hero.conscious():
			any_conscious = true
			break
	if not any_conscious:
		ended = true
		won = false
		_log("Поражение: все герои погибли или потеряли сознание.")
		battle_ended.emit(false)
		return
	if enemies_remaining_to_spawn > 0:
		return
	if not pending_projectiles.is_empty():
		return
	for enemy in enemies:
		if enemy.conscious():
			return
	ended = true
	won = true
	_log("Победа: все враги погибли. Опыт в первой версии не начисляется.")
	battle_ended.emit(true)


func _log(message: String) -> void:
	event_logged.emit(message)
