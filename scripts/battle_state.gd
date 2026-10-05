extends RefCounted

signal event_logged(message: String)
signal battle_ended(victory: bool)
signal visual_event(event: Dictionary)

const BOARD = preload("res://scripts/hex_board.gd")
const COMBATANT = preload("res://scripts/combatant.gd")
const ACTION_COOLDOWN := 3.0

var heroes: Array = []
var enemies: Array = []
var enemy_queue: Array[Dictionary] = []
var enemies_remaining_to_spawn := 0
var selected_hero := -1
var spawn_clock := 0.0
var elapsed := 0.0
var defeated_enemies := 0
var ended := false
var won := false
var rng := RandomNumberGenerator.new()


func start(hero_profiles: Array[Dictionary], selected_enemies: Array[Dictionary]) -> void:
	rng.randomize()
	heroes.clear()
	enemies.clear()
	enemy_queue = selected_enemies.duplicate(true)
	enemies_remaining_to_spawn = 0
	for entry in enemy_queue:
		enemies_remaining_to_spawn += int(entry.get("count", 0))
	selected_hero = -1
	spawn_clock = 0.0
	elapsed = 0.0
	defeated_enemies = 0
	ended = false
	for index in range(hero_profiles.size()):
		var unit = COMBATANT.new()
		unit.initialize(hero_profiles[index], true, Vector2i(0, BOARD.HERO_ROWS[index]))
		heroes.append(unit)
	select_next_active(-1)
	_log("Бой начался. Герои: %d; враги в очереди: %d." % [heroes.size(), enemies_remaining_to_spawn])
	_check_end()


func tick(delta: float) -> void:
	if ended:
		return
	elapsed += delta
	for hero in heroes:
		hero.cooldown = maxf(0.0, hero.cooldown - delta)
	for enemy in enemies:
		enemy.cooldown = maxf(0.0, enemy.cooldown - delta)
	if selected_hero < 0 or selected_hero >= heroes.size() or not heroes[selected_hero].ready():
		select_next_active(selected_hero)
	for enemy in enemies:
		if enemy.conscious():
			_update_enemy(enemy, delta)
	spawn_clock += delta
	while spawn_clock >= 1.0 and enemies_remaining_to_spawn > 0:
		if _spawn_enemy():
			spawn_clock -= 1.0
		else:
			spawn_clock = 1.0
			break
	_check_end()


func select_hero(index: int) -> bool:
	if ended or index < 0 or index >= heroes.size() or not heroes[index].ready():
		return false
	selected_hero = index
	return true


func select_next_active(after_index: int) -> void:
	selected_hero = -1
	if heroes.is_empty():
		return
	for offset in range(1, heroes.size() + 1):
		var index := (after_index + offset + heroes.size()) % heroes.size()
		if heroes[index].ready():
			selected_hero = index
			return


func perform_selected(action_id: String) -> bool:
	return perform_action(selected_hero, action_id)


func perform_action(index: int, action_id: String) -> bool:
	if ended or index < 0 or index >= heroes.size():
		return false
	var hero = heroes[index]
	if not hero.ready():
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
		var target = _nearest_enemy(hero.cell, 1, 1)
		if target == null:
			_log("%s атакует пустую клетку." % hero.name())
			visual_event.emit({"kind": "melee", "unit": hero, "target": null, "hit": false, "damage": 0})
		else:
			_physical_attack(hero, target, false)
	elif action_id == "shoot":
		if not can_shoot(hero):
			return false
		var minimum_range: int = int(hero.weapon(true).get("minimum_attack_range_hexes", 2))
		var target = _nearest_enemy(hero.cell, minimum_range, -1)
		if target == null:
			_log("%s выпускает стрелу, но подходящей цели нет." % hero.name())
			visual_event.emit({"kind": "shoot", "unit": hero, "target": null, "hit": false, "damage": 0})
		else:
			_physical_attack(hero, target, true)
	elif action_id == "fire_arrow":
		if hero.mana < 5:
			return false
		hero.mana -= 5
		var target = _nearest_enemy(hero.cell, 1, 6)
		if target == null:
			_log("%s выпускает Огненную стрелу без цели. Потрачено 5 маны." % hero.name())
			visual_event.emit({"kind": "fire_arrow", "unit": hero, "target": null, "hit": false, "damage": 0})
		else:
			var damage := _roll_dice("1d8")
			_log("%s применяет Огненную стрелу к %s: магия попадает всегда, 1д8 = %d урона; −5 маны." % [hero.name(), target.name(), damage])
			_apply_damage(hero, target, damage)
			visual_event.emit({"kind": "fire_arrow", "unit": hero, "target": target, "hit": true, "damage": damage})
	elif action_id == "quick_heal":
		if hero.mana < 5:
			return false
		hero.mana -= 5
		var target = _lowest_health_hero()
		if target == null:
			_log("%s применяет Быстрое лечение без цели. Потрачено 5 маны." % hero.name())
			visual_event.emit({"kind": "quick_heal", "unit": hero, "target": null, "amount": 0, "revived": false})
		else:
			var was_unconscious: bool = not target.conscious()
			var recovered: int = target.restore_health(6)
			if recovered > 0:
				_log("%s лечит %s: +%d здоровья (%d/%d); −5 маны." % [hero.name(), target.name(), recovered, target.health, target.max_health()])
			else:
				_log("%s лечит %s: здоровье уже полное (%d/%d); −5 маны." % [hero.name(), target.name(), target.health, target.max_health()])
			visual_event.emit({"kind": "quick_heal", "unit": hero, "target": target, "amount": recovered, "revived": was_unconscious and target.conscious()})
	else:
		return false
	hero.cooldown = ACTION_COOLDOWN
	select_next_active(index)
	_check_end()
	return true


func _update_enemy(enemy, delta: float) -> void:
	var target = _nearest_hero(enemy.cell)
	if target == null:
		return
	var weapon: Dictionary = enemy.weapon()
	var attack_range := int(weapon.get("attack_range_hexes", 1))
	if BOARD.distance(enemy.cell, target.cell) <= attack_range:
		enemy.movement_progress = 0.0
		if enemy.cooldown <= 0.0:
			_physical_attack(enemy, target, false)
			enemy.cooldown = ACTION_COOLDOWN
		return
	var speed := float(enemy.profile.get("movement_speed_hexes_per_second", 1.0))
	enemy.movement_progress += delta * speed
	var steps := 0
	while enemy.movement_progress >= 1.0 and steps < 3:
		var next_cell := _next_step(enemy.cell, target.cell, attack_range)
		if next_cell.x < 0:
			enemy.movement_progress = 1.0
			return
		visual_event.emit({"kind": "move", "unit": enemy, "from_cell": enemy.cell, "to_cell": next_cell, "speed": speed})
		enemy.cell = next_cell
		enemy.movement_progress -= 1.0
		steps += 1
		if BOARD.distance(enemy.cell, target.cell) <= attack_range:
			enemy.movement_progress = 0.0
			return


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
		var distance: int = BOARD.distance(from_cell, hero.cell)
		if distance < best_distance:
			best_distance = distance
			closest = [hero]
		elif distance == best_distance:
			closest.append(hero)
	if closest.is_empty():
		return null
	return closest[rng.randi_range(0, closest.size() - 1)]


func _nearest_enemy(from_cell: Vector2i, minimum_range: int, maximum_range: int):
	var closest: Array = []
	var best_distance := 999
	for enemy in enemies:
		if not enemy.conscious():
			continue
		var distance: int = BOARD.distance(from_cell, enemy.cell)
		if distance < minimum_range or (maximum_range >= 0 and distance > maximum_range):
			continue
		if distance < best_distance:
			best_distance = distance
			closest = [enemy]
		elif distance == best_distance:
			closest.append(enemy)
	if closest.is_empty():
		return null
	return closest[rng.randi_range(0, closest.size() - 1)]


func can_shoot(hero) -> bool:
	var minimum_range: int = int(hero.weapon(true).get("minimum_attack_range_hexes", 2))
	for enemy in enemies:
		if enemy.conscious() and BOARD.distance(hero.cell, enemy.cell) < minimum_range:
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
	var skill_value: int = attacker.skill(skill_name)
	var weapon_bonus := int(weapon.get("accuracy_bonus", 0))
	var distance: int = BOARD.distance(attacker.cell, target.cell)
	var range_penalty: int = maxi(0, distance - 5) * 3 if ranged else 0
	var die := rng.randi_range(1, 20)
	var attack_total := attribute_value + skill_value + weapon_bonus + die - range_penalty
	var armor_value: Variant = target.profile.get("armor", null)
	var armor_name := "нет"
	var armor_skill := 0
	if armor_value is Dictionary:
		armor_name = str(armor_value.get("name", "Броня"))
		armor_skill = target.skill(str(armor_value.get("skill_id", "")))
	var target_dexterity: int = target.attribute("dexterity")
	var equipment_bonus := int(target.profile.get("defense_equipment_bonus", 0))
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
	if equipment_bonus != 0:
		defense_parts.append("снаряжение %d" % equipment_bonus)
	var details: String = "%s %s %s. Точность: %s = %d. Защита: %s = %d." % [attacker.name(), action_name, target.name(), attack_expression, attack_total, " + ".join(defense_parts), defense_total]
	if hit:
		var damage_dice := str(weapon.get("damage_dice", "1d4"))
		var die_damage := _roll_dice(damage_dice)
		var strength_bonus: int = 0 if ranged else attacker.attribute("strength")
		damage = die_damage + strength_bonus
		var damage_parts := PackedStringArray()
		if die_damage != 0:
			damage_parts.append("%s (%d)" % [damage_dice, die_damage])
		if strength_bonus != 0:
			damage_parts.append("Сила (%d)" % strength_bonus)
		var damage_details: String = "Урон: %d" % damage
		if not damage_parts.is_empty():
			damage_details = "Урон: %s = %d" % [" + ".join(damage_parts), damage]
		_log(details + " Попадание. %s." % damage_details)
		_apply_damage(attacker, target, damage)
	else:
		_log(details + " Промах.")
	visual_event.emit({"kind": "shoot" if ranged else "melee", "unit": attacker, "target": target, "hit": hit, "damage": damage})


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
		if current != start_cell and BOARD.distance(current, target_cell) <= attack_range:
			goal = current
			break
		var candidates: Array[Vector2i] = BOARD.neighbors(current)
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var a_score: int = BOARD.distance(a, target_cell) * 10 + absi(a.y - target_cell.y)
			var b_score: int = BOARD.distance(b, target_cell) * 10 + absi(b.y - target_cell.y)
			return a_score < b_score
		)
		for neighbor in candidates:
			if visited.has(neighbor) or _occupied(neighbor):
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
	for enemy in enemies:
		if enemy.conscious():
			return
	ended = true
	won = true
	_log("Победа: все враги погибли. Опыт в первой версии не начисляется.")
	battle_ended.emit(true)


func _log(message: String) -> void:
	event_logged.emit(message)
