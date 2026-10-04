extends Control

const BOARD = preload("res://scripts/hex_board.gd")
const CATALOG = preload("res://scripts/data_catalog.gd")
const BATTLE = preload("res://scripts/battle_state.gd")
const BACKGROUND: Texture2D = preload("res://assets/battle-ground.png")
const COMBATANTS: Texture2D = preload("res://assets/combatants-atlas.png")
const CLERIC: Texture2D = preload("res://assets/human-cleric.png")
const ARCHER: Texture2D = preload("res://assets/human-archer.png")
const ARCHER_SPRITE: Texture2D = preload("res://assets/human-archer-sprite.png")

const SCREEN_SIZE := Vector2(1600, 1000)
const CLASS_ORDER := ["warrior", "mage", "cleric", "archer"]
const CLASS_NAMES := {"warrior": "Воин", "mage": "Маг", "cleric": "Клирик", "archer": "Лучник"}
const SLOT_ACTIONS := ["melee_attack", "shoot", "spell", "unused", "health_potion", "mana_potion"]
const SLOT_KEYS := ["Q", "W", "E", "R", "A", "S"]

var catalog = CATALOG.new()
var battle = BATTLE.new()
var font: Font
var combat_log: Array[String] = []
var setup_overlay: ColorRect
var setup_panel: PanelContainer
var setup_notice: Label
var hero_checks := {}
var hero_levels := {}
var enemy_counts := {}
var log_panel: PanelContainer
var log_content: RichTextLabel


func _ready() -> void:
	font = get_theme_default_font()
	catalog.load_all()
	battle.event_logged.connect(_on_battle_event)
	battle.battle_ended.connect(_on_battle_end)
	_build_log_panel()
	_build_setup_overlay()
	queue_redraw()


func _process(delta: float) -> void:
	if setup_overlay.visible or log_panel.visible:
		return
	battle.tick(delta)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if setup_overlay.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if log_panel.visible:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				log_panel.hide()
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			log_panel.show()
			get_viewport().set_input_as_handled()
			return
		_handle_key(event)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if log_panel.visible:
			return
		_handle_click(event.position)


func _handle_key(event: InputEventKey) -> void:
	var key := event.physical_keycode
	if key >= KEY_1 and key <= KEY_4:
		battle.select_hero(key - KEY_1)
	elif key == KEY_SPACE:
		battle.select_next_active(battle.selected_hero)
	elif key == KEY_Q:
		battle.perform_selected("melee_attack")
	elif key == KEY_W:
		battle.perform_selected("shoot")
	elif key == KEY_E:
		if battle.selected_hero >= 0:
			battle.perform_selected(_spell_for(battle.heroes[battle.selected_hero]))
	elif key == KEY_A:
		battle.perform_selected("health_potion")
	elif key == KEY_S:
		battle.perform_selected("mana_potion")
	elif key == KEY_ESCAPE:
		_show_setup()
	queue_redraw()
	get_viewport().set_input_as_handled()


func _handle_click(point: Vector2) -> void:
	if battle.ended and Rect2(650, 540, 300, 68).has_point(point):
		_show_setup()
		return
	if Rect2(375, 918, 1170, 58).has_point(point):
		log_panel.show()
		return
	for index in range(battle.heroes.size()):
		if point.distance_to(BOARD.center(battle.heroes[index].cell)) <= BOARD.RADIUS:
			battle.select_hero(index)
			queue_redraw()
			return
	for index in range(battle.heroes.size()):
		var top := 109.0 + float(index) * 211.0
		if Rect2(14, top + 9, 192, 139).has_point(point):
			battle.select_hero(index)
			queue_redraw()
			return
		for slot in range(6):
			if _slot_rect(top, slot).has_point(point):
				if battle.select_hero(index):
					var action_id := _slot_action_id(battle.heroes[index], slot)
					if action_id != "":
						battle.perform_action(index, action_id)
				queue_redraw()
				return


func _draw() -> void:
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, SCREEN_SIZE), false)
	_draw_top_status()
	_draw_board()
	_draw_units()
	_draw_hero_panel()
	_draw_journal_preview()
	if battle.ended and not setup_overlay.visible:
		_draw_end_banner()


func _draw_top_status() -> void:
	draw_rect(Rect2(1280, 12, 296, 69), Color(0.04, 0.05, 0.06, 0.82), true)
	draw_rect(Rect2(1280, 12, 296, 69), Color("b89b63"), false, 2.0)
	_text("ВРАГИ: %d / %d" % [battle.defeated_enemies, battle.defeated_enemies + battle.enemies_remaining_to_spawn + _living_enemy_count()], Vector2(1295, 42), 20, Color("f2e1ae"))
	_text("ВРЕМЯ: %.0f c" % battle.elapsed, Vector2(1295, 67), 15, Color("d6d8d2"))


func _living_enemy_count() -> int:
	var result := 0
	for enemy in battle.enemies:
		if enemy.conscious():
			result += 1
	return result


func _draw_board() -> void:
	for row in range(BOARD.ROWS):
		for column in range(BOARD.COLUMNS):
			var cell := Vector2i(column, row)
			var points: PackedVector2Array = BOARD.corners(cell)
			draw_colored_polygon(points, Color(0.43, 0.35, 0.16, 0.06))
			var outline := points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, Color(0.89, 0.83, 0.58, 0.78), 2.0, true)


func _draw_units() -> void:
	for enemy in battle.enemies:
		if enemy.conscious():
			_draw_cell_frame(enemy.cell, Color(0.92, 0.50, 0.24, 0.88), false)
			_draw_enemy(enemy)
	for index in range(battle.heroes.size()):
		var hero = battle.heroes[index]
		var active: bool = hero.ready()
		var selected: bool = battle.selected_hero == index and active
		var color := Color("f9d45c") if selected else (Color("43db80") if active else Color("92999d"))
		_draw_cell_frame(hero.cell, color, selected)
		_draw_hero_sprite(hero)


func _draw_cell_frame(cell: Vector2i, color: Color, selected: bool) -> void:
	var corners: PackedVector2Array = BOARD.corners(cell)
	draw_colored_polygon(corners, Color(color.r, color.g, color.b, 0.18 if selected else 0.09))
	var outline := corners.duplicate()
	outline.append(corners[0])
	draw_polyline(outline, color, 5.0 if selected else 3.0, true)


func _draw_hero_sprite(hero) -> void:
	var center: Vector2 = BOARD.center(hero.cell)
	var tint := Color.WHITE if hero.conscious() else Color(0.5, 0.5, 0.5, 0.8)
	match hero.class_id():
		"warrior":
			draw_texture_rect_region(COMBATANTS, Rect2(center - Vector2(52, 55), Vector2(104, 110)), Rect2(45, 46, 275, 246), tint)
		"mage":
			draw_texture_rect_region(COMBATANTS, Rect2(center - Vector2(51, 54), Vector2(102, 108)), Rect2(48, 288, 270, 220), tint)
		"cleric":
			draw_texture_rect(CLERIC, Rect2(center - Vector2(52, 55), Vector2(104, 110)), false, tint)
		"archer":
			draw_texture_rect(ARCHER_SPRITE, Rect2(center - Vector2(45, 72), Vector2(90, 135)), false, tint)


func _draw_enemy(enemy) -> void:
	var center: Vector2 = BOARD.center(enemy.cell)
	var enemy_id: String = enemy.id()
	if enemy_id == "forest_wolf":
		draw_texture_rect_region(COMBATANTS, Rect2(center - Vector2(61, 49), Vector2(122, 98)), Rect2(1262, 436, 306, 170))
	else:
		var tint := Color(0.72, 0.78, 0.84) if enemy_id == "armored_goblin" else Color.WHITE
		draw_texture_rect_region(COMBATANTS, Rect2(center - Vector2(52, 51), Vector2(104, 102)), Rect2(1270, 270, 250, 166), tint)
	var ratio: float = clampf(float(enemy.health) / float(maxi(1, enemy.max_health())), 0.0, 1.0)
	draw_rect(Rect2(center + Vector2(-35, -58), Vector2(70, 6)), Color(0.12, 0.04, 0.04, 0.8), true)
	draw_rect(Rect2(center + Vector2(-34, -57), Vector2(68.0 * ratio, 4)), Color("d84b39"), true)


func _draw_hero_panel() -> void:
	draw_rect(Rect2(0, 100, 348, 900), Color(0.07, 0.06, 0.05, 0.94), true)
	draw_rect(Rect2(346, 100, 4, 900), Color("ac8750"), true)
	for index in range(4):
		var top := 109.0 + float(index) * 211.0
		var panel := Rect2(8, top, 330, 202)
		draw_rect(panel, Color(0.14, 0.13, 0.11, 0.96), true)
		draw_rect(panel, Color("8d8064"), false, 3.0)
		if index >= battle.heroes.size():
			_text("Пустая ячейка", Vector2(88, top + 108), 18, Color("8b8c86"))
			continue
		var hero = battle.heroes[index]
		var selected: bool = battle.selected_hero == index and hero.ready()
		var edge := Color("f6cf62") if selected else (Color("3dbe74") if hero.ready() else Color("717b7d"))
		var portrait := Rect2(14, top + 9, 192, 139)
		draw_rect(portrait, Color("17202a"), true)
		draw_rect(portrait, edge, false, 4.0)
		_draw_portrait(hero, portrait)
		_text("%d  %s · ур. %d" % [index + 1, hero.name(), int(hero.profile.get("level", 1))], Vector2(21, top + 141), 14, Color.WHITE)
		_draw_resource_bar(Rect2(14, top + 155, 192, 17), hero.health, hero.max_health(), Color("d83834"))
		_draw_resource_bar(Rect2(14, top + 178, 192, 17), hero.mana, hero.max_mana(), Color("3187dc"))
		for slot in range(6):
			_draw_action_slot(hero, top, slot)
		if not hero.conscious():
			var status := "МЁРТВ" if not hero.alive() else "БЕЗ СОЗНАНИЯ"
			_text(status, Vector2(27, top + 78), 16, Color("f48a85"))
		elif hero.cooldown > 0.0:
			_text("Отдых %.1f c" % hero.cooldown, Vector2(228, top + 194), 12, Color("dfbd78"))


func _draw_portrait(hero, rect: Rect2) -> void:
	var inner := Rect2(rect.position + Vector2(5, 5), rect.size - Vector2(10, 10))
	match hero.class_id():
		"warrior":
			draw_texture_rect_region(COMBATANTS, inner, Rect2(126, 50, 130, 126))
		"mage":
			draw_texture_rect_region(COMBATANTS, inner, Rect2(112, 298, 140, 128))
		"cleric":
			draw_texture_rect_region(CLERIC, inner, Rect2(484, 18, 400, 400))
		"archer":
			draw_texture_rect_region(ARCHER, inner, Rect2(270, 60, 470, 435))
	if not hero.conscious():
		draw_rect(inner, Color(0.05, 0.05, 0.06, 0.55), true)


func _draw_resource_bar(rect: Rect2, value: int, maximum: int, fill_color: Color) -> void:
	var ratio := clampf(float(maxi(0, value)) / float(maxi(1, maximum)), 0.0, 1.0)
	draw_rect(rect, Color(0.03, 0.03, 0.04, 0.95), true)
	draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2((rect.size.x - 6.0) * ratio, rect.size.y - 6.0)), fill_color, true)
	draw_rect(rect, Color("b7a274"), false, 2.0)
	var label := "%d/%d" % [value, maximum]
	_text(label, rect.position + Vector2(67, 13), 14, Color.WHITE)


func _slot_rect(top: float, slot: int) -> Rect2:
	var column := slot % 2
	var row := floori(float(slot) / 2.0)
	return Rect2(212 + column * 59, top + 12 + row * 49, 54, 44)


func _slot_action_id(hero, slot: int) -> String:
	if slot == 2:
		return _spell_for(hero)
	if slot == 3:
		return ""
	return SLOT_ACTIONS[slot]


func _spell_for(hero) -> String:
	if hero.has_action("fire_arrow"):
		return "fire_arrow"
	if hero.has_action("quick_heal"):
		return "quick_heal"
	return ""


func _slot_available(hero, slot: int) -> bool:
	if not hero.ready():
		return false
	if slot == 4:
		return hero.health_potions > 0
	if slot == 5:
		return hero.mana_potions > 0
	var action_id := _slot_action_id(hero, slot)
	if action_id == "" or not hero.has_action(action_id):
		return false
	if action_id == "fire_arrow" or action_id == "quick_heal":
		return hero.mana >= 5
	return true


func _draw_action_slot(hero, top: float, slot: int) -> void:
	var rect: Rect2 = _slot_rect(top, slot)
	var available: bool = _slot_available(hero, slot)
	var edge: Color = Color("c6ab76") if available else Color("77736d")
	draw_rect(rect, Color(0.09, 0.13, 0.17, 0.93) if available else Color(0.08, 0.08, 0.09, 0.86), true)
	draw_rect(rect, edge, false, 2.0)
	draw_rect(Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6)), Color("4c5b63") if available else Color("36383a"), false, 1.0)
	var center: Vector2 = rect.position + Vector2(24, 22)
	match slot:
		0: _draw_swords_icon(center, available)
		1: _draw_bow_icon(center, available)
		2:
			if hero.has_action("fire_arrow"):
				_draw_fire_icon(center, available)
			elif hero.has_action("quick_heal"):
				_draw_heal_icon(center, available)
			else:
				_draw_empty_icon(center)
		3: _draw_empty_icon(center)
		4: _draw_potion_icon(center, Color("cc493e"), available)
		5: _draw_potion_icon(center, Color("338fd0"), available)
	var badge_center: Vector2 = rect.position + Vector2(rect.size.x - 9, 8)
	draw_circle(badge_center, 9.0, Color("2d8dba") if available else Color("585e62"))
	draw_arc(badge_center, 9.0, 0.0, TAU, 20, Color("e0c681") if available else Color("77736d"), 1.5, true)
	_text(SLOT_KEYS[slot], badge_center + Vector2(-5, 4), 11, Color.WHITE)
	if slot == 4 or slot == 5:
		var count: int = hero.health_potions if slot == 4 else hero.mana_potions
		var count_center: Vector2 = rect.position + Vector2(rect.size.x - 9, 36)
		draw_circle(count_center, 7.0, Color("182025"))
		_text(str(count), count_center + Vector2(-3, 4), 11, Color.WHITE if available else Color("999999"))


func _draw_swords_icon(center: Vector2, available: bool) -> void:
	var steel: Color = Color("dce9e8") if available else Color("6b7172")
	var gold: Color = Color("dbad63") if available else Color("68635a")
	for side in [-1.0, 1.0]:
		var hilt: Vector2 = center + Vector2(-10.0 * side, 10)
		var tip: Vector2 = center + Vector2(11.0 * side, -11)
		draw_line(hilt, tip, Color("283b42"), 6.0, true)
		draw_line(hilt + Vector2(3.0 * side, -3), tip, steel, 3.0, true)
		draw_line(hilt + Vector2(-3.0 * side, -3), hilt + Vector2(3.0 * side, 3), gold, 3.0, true)
		draw_circle(hilt + Vector2(-2.0 * side, 2), 2.0, gold)


func _draw_bow_icon(center: Vector2, available: bool) -> void:
	var wood: Color = Color("c68f51") if available else Color("69645e")
	var arrow: Color = Color("e6e4d2") if available else Color("737575")
	draw_arc(center + Vector2(-5, 0), 14.0, -PI / 2.0, PI / 2.0, 20, wood, 4.0, true)
	draw_line(center + Vector2(-5, -14), center + Vector2(-5, 14), arrow, 1.5, true)
	draw_line(center + Vector2(-14, 0), center + Vector2(14, 0), arrow, 2.5, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(15, 0), center + Vector2(8, -4), center + Vector2(8, 4)]), arrow)
	draw_line(center + Vector2(-13, 0), center + Vector2(-17, -4), wood, 2.0, true)
	draw_line(center + Vector2(-13, 0), center + Vector2(-17, 4), wood, 2.0, true)


func _draw_fire_icon(center: Vector2, available: bool) -> void:
	var flame: Color = Color("ee792e") if available else Color("6e6660")
	var core: Color = Color("ffe49a") if available else Color("85817a")
	draw_line(center + Vector2(-12, 11), center + Vector2(6, -7), Color("c8b99a") if available else core, 3.0, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(2, -3), center + Vector2(8, -15), center + Vector2(10, -7), center + Vector2(15, -11), center + Vector2(14, 0), center + Vector2(7, 5)]), flame)
	draw_colored_polygon(PackedVector2Array([center + Vector2(6, -2), center + Vector2(10, -8), center + Vector2(11, 0), center + Vector2(8, 2)]), core)


func _draw_heal_icon(center: Vector2, available: bool) -> void:
	var glow: Color = Color("72c987") if available else Color("686d69")
	var light: Color = Color("e9f5d5") if available else Color("929792")
	draw_circle(center, 13.0, Color("174638") if available else Color("303635"))
	draw_arc(center, 13.0, 0.0, TAU, 24, glow, 2.0, true)
	draw_rect(Rect2(center + Vector2(-3, -10), Vector2(6, 20)), light, true)
	draw_rect(Rect2(center + Vector2(-10, -3), Vector2(20, 6)), light, true)
	draw_circle(center, 2.5, glow)


func _draw_empty_icon(center: Vector2) -> void:
	draw_circle(center, 10.0, Color("252c30"))
	draw_arc(center, 10.0, 0.0, TAU, 20, Color("50595b"), 2.0, true)


func _draw_potion_icon(center: Vector2, liquid: Color, available: bool) -> void:
	var outline: Color = Color("d9e4df") if available else Color("747a78")
	var fill: Color = liquid if available else Color("565b5c")
	draw_colored_polygon(PackedVector2Array([center + Vector2(-5, -10), center + Vector2(5, -10), center + Vector2(5, -5), center + Vector2(10, 4), center + Vector2(8, 12), center + Vector2(-8, 12), center + Vector2(-10, 4), center + Vector2(-5, -5)]), Color("243238"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-8, 2), center + Vector2(8, 2), center + Vector2(7, 10), center + Vector2(-7, 10)]), fill)
	draw_line(center + Vector2(-5, -10), center + Vector2(-5, -5), outline, 2.0, true)
	draw_line(center + Vector2(-5, -5), center + Vector2(-10, 4), outline, 2.0, true)
	draw_line(center + Vector2(-10, 4), center + Vector2(-8, 12), outline, 2.0, true)
	draw_line(center + Vector2(-8, 12), center + Vector2(8, 12), outline, 2.0, true)
	draw_line(center + Vector2(8, 12), center + Vector2(10, 4), outline, 2.0, true)
	draw_line(center + Vector2(10, 4), center + Vector2(5, -5), outline, 2.0, true)
	draw_line(center + Vector2(5, -5), center + Vector2(5, -10), outline, 2.0, true)
	draw_rect(Rect2(center + Vector2(-6, -14), Vector2(12, 4)), Color("9b754c") if available else Color("585550"), true)
	draw_line(center + Vector2(-5, 4), center + Vector2(-3, 8), Color(1, 1, 1, 0.7 if available else 0.25), 2.0, true)


func _draw_journal_preview() -> void:
	var rect := Rect2(370, 913, 1185, 72)
	draw_rect(rect, Color(0.04, 0.05, 0.06, 0.82), true)
	draw_rect(rect, Color("b59b63"), false, 2.0)
	_text("ЖУРНАЛ БОЯ  ·  НАЖМИТЕ ИЛИ ENTER ДЛЯ ИСТОРИИ", Vector2(385, 934), 13, Color("e6cb87"))
	var latest := "Ожидание боя"
	if not combat_log.is_empty():
		latest = combat_log.back()
	_text(latest, Vector2(385, 962), 17, Color("f1e8d8"), 1120.0)


func _draw_end_banner() -> void:
	var rect := Rect2(555, 385, 490, 244)
	draw_rect(rect, Color(0.06, 0.07, 0.08, 0.94), true)
	draw_rect(rect, Color("e3c477") if battle.won else Color("a76560"), false, 4.0)
	_text("ПОБЕДА" if battle.won else "ПОРАЖЕНИЕ", Vector2(670, 455), 38, Color("f5dc92") if battle.won else Color("efb2a7"))
	_text("Повержено врагов: %d" % battle.defeated_enemies, Vector2(665, 499), 19, Color.WHITE)
	draw_rect(Rect2(650, 540, 300, 68), Color("3b5b48"), true)
	draw_rect(Rect2(650, 540, 300, 68), Color("b9d09a"), false, 2.0)
	_text("НОВЫЙ БОЙ", Vector2(708, 583), 22, Color.WHITE)


func _text(value: String, at: Vector2, size: int, color: Color, width: float = -1.0) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)


func _build_setup_overlay() -> void:
	setup_overlay = ColorRect.new()
	setup_overlay.color = Color(0.015, 0.02, 0.03, 0.78)
	setup_overlay.anchor_right = 1.0
	setup_overlay.anchor_bottom = 1.0
	setup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(setup_overlay)
	setup_panel = PanelContainer.new()
	setup_panel.position = Vector2(340, 80)
	setup_panel.size = Vector2(920, 830)
	setup_panel.add_theme_stylebox_override("panel", _panel_style())
	setup_overlay.add_child(setup_panel)
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 28)
	padding.add_theme_constant_override("margin_right", 28)
	padding.add_theme_constant_override("margin_top", 23)
	padding.add_theme_constant_override("margin_bottom", 23)
	setup_panel.add_child(padding)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	padding.add_child(body)
	body.add_child(_label("СОСТАВ БОЯ", 32, Color("ead28f")))
	body.add_child(_label("Выберите от одного до четырёх героев и любое число врагов.", 17, Color("d4d5cf")))
	body.add_child(_label("ГЕРОИ", 23, Color("e9c675")))
	for class_id in CLASS_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 15)
		body.add_child(row)
		var check := CheckBox.new()
		check.text = str(CLASS_NAMES[class_id])
		check.button_pressed = true
		check.custom_minimum_size = Vector2(260, 44)
		check.add_theme_font_size_override("font_size", 20)
		row.add_child(check)
		hero_checks[class_id] = check
		var levels := OptionButton.new()
		levels.custom_minimum_size = Vector2(170, 42)
		for level in [1, 3, 5]:
			if not catalog.hero_profile(class_id, level).is_empty():
				levels.add_item("%d уровень" % level, level)
		levels.select(0)
		row.add_child(levels)
		hero_levels[class_id] = levels
		var profile: Dictionary = catalog.hero_profile(class_id, 1)
		row.add_child(_label(str(profile.get("name", "")), 19, Color("c5c7c1")))
	body.add_child(_label("ВРАГИ", 23, Color("e9c675")))
	for profile in catalog.enemies:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		body.add_child(row)
		var enemy_name := _label(str(profile.get("name", "Враг")) + " · ур. " + str(profile.get("level", 1)), 19, Color.WHITE)
		enemy_name.custom_minimum_size = Vector2(370, 45)
		row.add_child(enemy_name)
		var count := SpinBox.new()
		count.min_value = 0
		count.max_value = 1000000
		count.step = 1
		count.rounded = true
		count.value = 20 if str(profile.get("id", "")) == "small_goblin" else 0
		count.custom_minimum_size = Vector2(145, 44)
		row.add_child(count)
		enemy_counts[str(profile.get("id", ""))] = count
	setup_notice = _label("", 17, Color("f1a09a"))
	body.add_child(setup_notice)
	var start_button := Button.new()
	start_button.text = "НАЧАТЬ БОЙ"
	start_button.custom_minimum_size = Vector2(0, 66)
	start_button.add_theme_font_size_override("font_size", 24)
	start_button.pressed.connect(_begin_battle)
	body.add_child(start_button)


func _build_log_panel() -> void:
	log_panel = PanelContainer.new()
	log_panel.position = Vector2(360, 115)
	log_panel.size = Vector2(880, 765)
	log_panel.add_theme_stylebox_override("panel", _panel_style())
	log_panel.visible = false
	add_child(log_panel)
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 23)
	padding.add_theme_constant_override("margin_right", 23)
	padding.add_theme_constant_override("margin_top", 20)
	padding.add_theme_constant_override("margin_bottom", 20)
	log_panel.add_child(padding)
	var body := VBoxContainer.new()
	padding.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var title := _label("ЖУРНАЛ БОЯ · ПАУЗА", 26, Color("ead28f"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "Закрыть  Enter / Esc"
	close_button.pressed.connect(func(): log_panel.hide())
	header.add_child(close_button)
	log_content = RichTextLabel.new()
	log_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_content.scroll_following = true
	log_content.add_theme_font_size_override("normal_font_size", 17)
	body.add_child(log_content)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.09, 0.97)
	style.border_color = Color("b29a62")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	return style


func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _begin_battle() -> void:
	var chosen_heroes: Array[Dictionary] = []
	for class_id in CLASS_ORDER:
		if hero_checks[class_id].button_pressed:
			var level: int = hero_levels[class_id].get_selected_id()
			var profile: Dictionary = catalog.hero_profile(class_id, level)
			if not profile.is_empty():
				chosen_heroes.append(profile)
	if chosen_heroes.is_empty():
		setup_notice.text = "Выберите хотя бы одного героя."
		return
	var chosen_enemies: Array[Dictionary] = []
	for profile in catalog.enemies:
		var enemy_id := str(profile.get("id", ""))
		var count := int(enemy_counts[enemy_id].value)
		if count > 0:
			chosen_enemies.append({"profile": profile, "count": count})
	combat_log.clear()
	log_content.text = ""
	setup_notice.text = ""
	setup_overlay.hide()
	battle.start(chosen_heroes, chosen_enemies)
	queue_redraw()


func _show_setup() -> void:
	log_panel.hide()
	setup_overlay.show()
	queue_redraw()


func _on_battle_event(message: String) -> void:
	combat_log.append("[%05.1f] %s" % [battle.elapsed, message])
	if combat_log.size() > 500:
		combat_log.pop_front()
	var full_text := ""
	for line in combat_log:
		full_text += line + "\n\n"
	log_content.text = full_text
	queue_redraw()


func _on_battle_end(_victory: bool) -> void:
	queue_redraw()
