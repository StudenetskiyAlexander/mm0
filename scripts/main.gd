extends Control

const BOARD = preload("res://scripts/battle_board.gd")
const CATALOG = preload("res://scripts/data_catalog.gd")
const BATTLE = preload("res://scripts/battle_state.gd")
const BATTLE_AUDIO = preload("res://scripts/battle_audio.gd")
const COMBATANT = preload("res://scripts/combatant.gd")
const BACKGROUND: Texture2D = preload("res://assets/battle-ground.png")
const WORLD_MAP: Texture2D = preload("res://assets/world-map-preview.png")
const COMBATANTS: Texture2D = preload("res://assets/combatants-atlas.png")
const WARRIOR_ANIMATION: Texture2D = preload("res://assets/warrior-animation-8f.png")
const WARRIOR_ABILITIES: Texture2D = preload("res://assets/ability_animation/warrior-abilities-packed.png")
const WARRIOR_TARGET_MASK: Texture2D = preload("res://assets/warrior-target-mask-8f.png")
const MAGE_ANIMATION: Texture2D = preload("res://assets/mage-animation-8f.png")
const MAGE_ABILITIES: Texture2D = preload("res://assets/ability_animation/mage-abilities-packed.png")
const MAGE_TARGET_MASK: Texture2D = preload("res://assets/mage-target-mask-8f.png")
const MAGE_IDLE: Texture2D = preload("res://assets/mage-idle.png")
const MAGE_IDLE_MASK: Texture2D = preload("res://assets/mage-idle-mask.png")
const CLERIC_ANIMATION: Texture2D = preload("res://assets/cleric-animation-8f.png")
const CLERIC_ABILITIES: Texture2D = preload("res://assets/ability_animation/cleric-abilities-packed.png")
const CLERIC_TARGET_MASK: Texture2D = preload("res://assets/cleric-target-mask-8f.png")
const ARCHER_ANIMATION: Texture2D = preload("res://assets/archer-animation-8f.png")
const ARCHER_ABILITIES: Texture2D = preload("res://assets/ability_animation/archer-abilities-packed.png")
const ARCHER_TARGET_MASK: Texture2D = preload("res://assets/archer-target-mask-8f.png")
const ARCHER_IDLE: Texture2D = preload("res://assets/archer-idle.png")
const ARCHER_IDLE_MASK: Texture2D = preload("res://assets/archer-idle-mask.png")
const SMALL_GOBLIN_ANIMATION: Texture2D = preload("res://assets/small-goblin-animation-8f.png")
const SMALL_GOBLIN_TARGET_MASK: Texture2D = preload("res://assets/small-goblin-target-mask-8f.png")
const ARMORED_GOBLIN_ANIMATION: Texture2D = preload("res://assets/armored-goblin-animation-8f.png")
const ARMORED_GOBLIN_TARGET_MASK: Texture2D = preload("res://assets/armored-goblin-target-mask-8f.png")
const WOLF_ANIMATION: Texture2D = preload("res://assets/wolf-animation-8f.png")
const WOLF_TARGET_MASK: Texture2D = preload("res://assets/wolf-target-mask-8f.png")
const WARRIOR_PORTRAITS: Texture2D = preload("res://assets/warrior-portrait-sheet.png")
const MAGE_PORTRAITS: Texture2D = preload("res://assets/mage-portrait-sheet.png")
const CLERIC_PORTRAITS: Texture2D = preload("res://assets/cleric-portrait-sheet.png")
const ARCHER_PORTRAITS: Texture2D = preload("res://assets/archer-portrait-sheet.png")
const CLERIC: Texture2D = preload("res://assets/human-cleric.png")
const ARCHER: Texture2D = preload("res://assets/human-archer.png")
const ARCHER_SPRITE: Texture2D = preload("res://assets/human-archer-sprite.png")

const SCREEN_SIZE := Vector2(1600, 1000)
const MAP_VIEW_RECT := Rect2(364, 20, 1212, 960)
const TOWN_SOURCE_POINTS := [Vector2(130, 433), Vector2(161, 407), Vector2(225, 382), Vector2(293, 397), Vector2(341, 433), Vector2(342, 475), Vector2(281, 498), Vector2(211, 494), Vector2(157, 472)]
const HERO_SHEET_RECT := Rect2(375, 55, 1150, 890)
const HERO_SHEET_CLOSE_RECT := Rect2(1290, 91, 190, 54)
const HERO_SHEET_TAB_NAMES := ["ХАРАКТЕРИСТИКИ", "НАВЫКИ", "ИНВЕНТАРЬ", "СПОСОБНОСТИ"]
const BATTLE_MAP_RECT := Rect2(1112, 12, 151, 69)
const PREVIEW_GOLD_TEXT := "12 450"
const CLASS_ORDER := ["warrior", "mage", "cleric", "archer"]
const CLASS_NAMES := {"warrior": "Воин", "mage": "Маг", "cleric": "Клирик", "archer": "Лучник"}
const SLOT_ACTIONS := ["melee_attack", "shoot", "spell", "unused", "health_potion", "mana_potion"]
const SLOT_KEYS := ["Q", "W", "E", "R", "A", "S"]
const ANIMATION_ATLAS_WIDTH_SCALE := 1.25
const HERO_BATTLE_SPRITE_SCALE := 1.10
const GOBLIN_BATTLE_SPRITE_SCALE := 0.85
# The generated cleric poses have different body sizes around the raised mace
# and healing glow. Keep his apparent height steady without cropping those effects.
const CLERIC_MELEE_FRAME_SCALES := [1.0, 1.05, 1.13, 1.22, 1.20, 1.22, 1.08, 1.0]
const CLERIC_HEAL_FRAME_SCALES := [1.0, 1.12, 1.19, 1.22, 1.20, 1.20, 1.10, 1.0]

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
var music_select: OptionButton
var music_preview_button: Button
var log_panel: PanelContainer
var log_content: RichTextLabel
var animation_time := 0.0
var movement_animations: Dictionary = {}
var action_animations: Dictionary = {}
var impact_animations: Dictionary = {}
var spawn_animations: Dictionary = {}
var fall_animations: Dictionary = {}
var death_animations: Dictionary = {}
var portrait_reactions: Dictionary = {}
var visual_effects: Array[Dictionary] = []
var targeting_action := ""
var targeting_hero_index := -1
var battle_audio
var map_mode := true
var town_hovered := false
var hovered_map_hero := -1
var hero_sheet_index := -1
var hero_sheet_tab := 0
var party_profiles: Array[Dictionary] = []
var map_heroes: Array = []


func _ready() -> void:
	font = get_theme_default_font()
	battle_audio = BATTLE_AUDIO.new()
	add_child(battle_audio)
	battle_audio.music_preview_finished.connect(_on_music_preview_finished)
	catalog.load_all()
	battle.event_logged.connect(_on_battle_event)
	battle.battle_ended.connect(_on_battle_end)
	battle.visual_event.connect(_on_visual_event)
	battle.visual_event.connect(battle_audio.handle_visual_event)
	_build_log_panel()
	log_panel.visibility_changed.connect(_sync_audio_pause)
	_build_setup_overlay()
	queue_redraw()


func _process(delta: float) -> void:
	if map_mode or setup_overlay.visible or log_panel.visible:
		return
	battle.tick(delta)
	if targeting_action != "" and not battle.can_hero_act(targeting_hero_index):
		_cancel_targeting()
	_advance_animations(delta)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if setup_overlay.visible:
		return
	if map_mode:
		if hero_sheet_index >= 0:
			_handle_hero_sheet_input(event)
			return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_show_setup()
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion:
			var hovering_town: bool = _town_at(event.position)
			var hovering_hero: int = _map_hero_at(event.position)
			if hovering_town != town_hovered or hovering_hero != hovered_map_hero:
				town_hovered = hovering_town
				hovered_map_hero = hovering_hero
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovering_town or hovering_hero >= 0 else Control.CURSOR_ARROW
				queue_redraw()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var clicked_hero: int = _map_hero_at(event.position)
			if clicked_hero >= 0:
				_open_hero_sheet(clicked_hero)
				get_viewport().set_input_as_handled()
			elif _town_at(event.position):
				_begin_battle()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if log_panel.visible:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				log_panel.hide()
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_cancel_targeting()
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
	if key == KEY_M:
		_return_to_map()
		return
	if key >= KEY_1 and key <= KEY_4:
		battle.select_hero(key - KEY_1)
	elif key == KEY_SPACE:
		_cancel_targeting()
		battle.skip_current_hero()
	elif key == KEY_Q:
		_activate_action("melee_attack")
	elif key == KEY_W:
		_activate_action("shoot")
	elif key == KEY_E:
		if battle.selected_hero >= 0:
			_activate_action(_spell_for(battle.heroes[battle.selected_hero]))
	elif key == KEY_R:
		if battle.selected_hero >= 0:
			_activate_action(_support_spell_for(battle.heroes[battle.selected_hero]))
	elif key == KEY_A:
		_activate_action("health_potion")
	elif key == KEY_S:
		_activate_action("mana_potion")
	elif key == KEY_ESCAPE:
		if targeting_action != "":
			_cancel_targeting()
		else:
			_return_to_map()
	queue_redraw()
	get_viewport().set_input_as_handled()


func _activate_action(action_id: String) -> void:
	var index: int = battle.selected_hero
	if action_id == "" or not battle.can_hero_act(index):
		return
	if action_id == "quick_heal":
		if battle.available_heal_targets(index).is_empty():
			return
		if targeting_action == action_id and targeting_hero_index == index:
			if battle.perform_action(index, action_id):
				_cancel_targeting()
		else:
			targeting_action = action_id
			targeting_hero_index = index
			mouse_default_cursor_shape = Control.CURSOR_CROSS
		queue_redraw()
		return
	if action_id == "melee_attack" or action_id == "shoot" or action_id == "fire_arrow":
		var targets: Array = battle.available_enemy_targets(index, action_id)
		if targets.size() > 1:
			if targeting_action == action_id and targeting_hero_index == index:
				if battle.perform_action(index, action_id):
					_cancel_targeting()
			else:
				targeting_action = action_id
				targeting_hero_index = index
				mouse_default_cursor_shape = Control.CURSOR_CROSS
			queue_redraw()
			return
		if targets.size() == 1:
			if battle.perform_action(index, action_id, targets[0]):
				_cancel_targeting()
			return
	if battle.perform_action(index, action_id):
		_cancel_targeting()


func _cancel_targeting() -> void:
	if targeting_action == "":
		return
	targeting_action = ""
	targeting_hero_index = -1
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()


func _handle_click(point: Vector2) -> void:
	if BATTLE_MAP_RECT.has_point(point):
		_return_to_map()
		return
	if battle.ended and Rect2(650, 540, 300, 68).has_point(point):
		_return_to_map()
		return
	if Rect2(375, 918, 1170, 58).has_point(point):
		_cancel_targeting()
		log_panel.show()
		return
	if targeting_action == "quick_heal":
		for hero in battle.available_heal_targets(targeting_hero_index):
			var target_index: int = battle.heroes.find(hero)
			if _target_hitbox(hero).has_point(point) or _hero_portrait_rect(target_index).has_point(point):
				if battle.perform_action(targeting_hero_index, targeting_action, hero):
					_cancel_targeting()
				queue_redraw()
				return
	elif targeting_action != "":
		for enemy in battle.available_enemy_targets(targeting_hero_index, targeting_action):
			if _target_hitbox(enemy).has_point(point):
				if battle.perform_action(targeting_hero_index, targeting_action, enemy):
					_cancel_targeting()
				queue_redraw()
				return
	for index in range(battle.heroes.size()):
		if BOARD.cell_rect(battle.heroes[index].cell).has_point(point):
			battle.select_hero(index)
			queue_redraw()
			return
	for index in range(battle.heroes.size()):
		var top := 109.0 + float(index) * 211.0
		if _hero_portrait_rect(index).has_point(point):
			battle.select_hero(index)
			queue_redraw()
			return
		for slot in range(6):
			if _slot_rect(top, slot).has_point(point):
				if battle.select_hero(index):
					var action_id := _slot_action_id(battle.heroes[index], slot)
					_activate_action(action_id)
				queue_redraw()
				return


func _draw() -> void:
	if map_mode:
		_draw_map_screen()
		return
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, SCREEN_SIZE), false)
	_draw_gold_counter()
	_draw_top_status()
	_draw_units()
	_draw_targeting_banner()
	_draw_visual_effects()
	_draw_hero_panel(battle.heroes, false)
	_draw_journal_preview()
	if battle.ended and not setup_overlay.visible:
		_draw_end_banner()


func _draw_top_status() -> void:
	draw_rect(BATTLE_MAP_RECT, Color(0.04, 0.05, 0.06, 0.82), true)
	draw_rect(BATTLE_MAP_RECT, Color("b89b63"), false, 2.0)
	_text("КАРТА", Vector2(1139, 54), 21, Color("f2e1ae"))
	draw_rect(Rect2(1280, 12, 296, 69), Color(0.04, 0.05, 0.06, 0.82), true)
	draw_rect(Rect2(1280, 12, 296, 69), Color("b89b63"), false, 2.0)
	_text("ВРАГИ: %d / %d" % [battle.defeated_enemies, battle.defeated_enemies + battle.enemies_remaining_to_spawn + _living_enemy_count()], Vector2(1295, 42), 20, Color("f2e1ae"))
	var phase_label := "ГЕРОИ" if battle.phase == "heroes" else "ВРАГИ"
	_text("РАУНД %d · %s" % [battle.round_number, phase_label], Vector2(1295, 67), 15, Color("d6d8d2"))


func _draw_gold_counter() -> void:
	var plate := Rect2(12, 12, 326, 70)
	draw_rect(plate, Color(0.04, 0.05, 0.06, 0.9), true)
	draw_rect(plate, Color("b89b63"), false, 3.0)
	draw_circle(Vector2(48, 47), 19.0, Color("593c16"))
	draw_circle(Vector2(48, 47), 16.0, Color("efbd4c"))
	draw_arc(Vector2(48, 47), 12.0, 0.0, TAU, 32, Color("fff0a9"), 2.0, true)
	draw_circle(Vector2(48, 47), 5.0, Color("cf842e"))
	_text(PREVIEW_GOLD_TEXT, Vector2(80, 58), 29, Color("f8df9b"))


func _draw_map_screen() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color("19211f"), true)
	draw_rect(Rect2(350, 6, 1240, 988), Color("1b1b19"), true)
	draw_texture_rect_region(WORLD_MAP, MAP_VIEW_RECT, _map_source_rect())
	draw_rect(Rect2(350, 6, 1240, 988), Color("b89b63"), false, 4.0)
	if town_hovered:
		var outline := _town_polygon()
		draw_colored_polygon(outline, Color(1.0, 0.84, 0.40, 0.17))
		outline.append(outline[0])
		draw_polyline(outline, Color("ffe6a4"), 3.0, true)
		var label_rect := Rect2(385, 899, 370, 57)
		draw_rect(label_rect, Color(0.07, 0.10, 0.10, 0.91), true)
		draw_rect(label_rect, Color("e9c879"), false, 2.0)
		_text("МАЛЫЙ ГОРОД · НАЧАТЬ БОЙ", Vector2(400, 936), 18, Color("ffebba"))
	_draw_gold_counter()
	_draw_hero_panel(map_heroes, true)
	if hero_sheet_index >= 0:
		_draw_hero_sheet()


func _draw_hero_sheet() -> void:
	if hero_sheet_index >= map_heroes.size():
		return
	var hero = map_heroes[hero_sheet_index]
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0.015, 0.02, 0.025, 0.72), true)
	draw_rect(HERO_SHEET_RECT, Color("171c1e"), true)
	draw_rect(HERO_SHEET_RECT, Color("c2a86f"), false, 4.0)
	draw_rect(Rect2(389, 69, 1122, 238), Color("20282a"), true)
	draw_line(Vector2(405, 305), Vector2(1495, 305), Color("695a3e"), 2.0, true)
	_text("СВОЙСТВА ГЕРОЯ", Vector2(411, 112), 29, Color("e7cd89"))
	draw_rect(Rect2(409, 134, 156, 163), Color("111b22"), true)
	_draw_portrait(hero, Rect2(412, 137, 150, 157), hero_sheet_index)
	draw_rect(Rect2(409, 134, 156, 163), Color("d7ba79"), false, 3.0)
	_text(hero.name(), Vector2(598, 196), 37, Color("f1e9d9"), 650.0)
	var hero_class_label: String = str(CLASS_NAMES.get(hero.class_id(), "Герой"))
	_text("%s · %d уровень" % [hero_class_label, int(hero.profile.get("level", 1))], Vector2(600, 243), 22, Color("c9b786"))
	draw_rect(HERO_SHEET_CLOSE_RECT, Color("303b3a"), true)
	draw_rect(HERO_SHEET_CLOSE_RECT, Color("bda36b"), false, 2.0)
	_text("ЗАКРЫТЬ · ESC", Vector2(1307, 126), 18, Color("f0e1bd"))
	for index in range(HERO_SHEET_TAB_NAMES.size()):
		var rect := _hero_sheet_tab_rect(index)
		var selected: bool = index == hero_sheet_tab
		draw_rect(rect, Color("343d3b") if selected else Color("242b2d"), true)
		draw_rect(rect, Color("edcf83") if selected else Color("806f50"), false, 2.0)
		if selected:
			draw_rect(Rect2(rect.position + Vector2(2, rect.size.y - 6), Vector2(rect.size.x - 4, 4)), Color("edcf83"), true)
		_text(HERO_SHEET_TAB_NAMES[index], rect.position + Vector2(13, 40), 19, Color("ffebbc") if selected else Color("b9b6a9"), rect.size.x - 22)
	draw_rect(Rect2(405, 389, 1090, 514), Color("111719"), true)
	draw_rect(Rect2(405, 389, 1090, 514), Color("665b42"), false, 2.0)


func _hero_sheet_tab_rect(index: int) -> Rect2:
	return Rect2(405 + float(index) * 272.0, 317, 256, 59)


func _map_hero_at(point: Vector2) -> int:
	for index in range(map_heroes.size()):
		var top := 109.0 + float(index) * 211.0
		if Rect2(8, top, 199, 202).has_point(point):
			return index
	return -1


func _open_hero_sheet(index: int) -> void:
	hero_sheet_index = index
	hero_sheet_tab = 0
	town_hovered = false
	hovered_map_hero = -1
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()


func _close_hero_sheet() -> void:
	hero_sheet_index = -1
	hero_sheet_tab = 0
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()


func _handle_hero_sheet_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_close_hero_sheet()
		elif event.keycode == KEY_LEFT:
			hero_sheet_tab = posmod(hero_sheet_tab - 1, HERO_SHEET_TAB_NAMES.size())
			queue_redraw()
		elif event.keycode == KEY_RIGHT:
			hero_sheet_tab = posmod(hero_sheet_tab + 1, HERO_SHEET_TAB_NAMES.size())
			queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if HERO_SHEET_CLOSE_RECT.has_point(event.position) or not HERO_SHEET_RECT.has_point(event.position):
			_close_hero_sheet()
		else:
			for index in range(HERO_SHEET_TAB_NAMES.size()):
				if _hero_sheet_tab_rect(index).has_point(event.position):
					hero_sheet_tab = index
					queue_redraw()
					break
		get_viewport().set_input_as_handled()


func _map_source_rect() -> Rect2:
	var image_size: Vector2 = WORLD_MAP.get_size()
	var image_ratio: float = image_size.x / image_size.y
	var view_ratio: float = MAP_VIEW_RECT.size.x / MAP_VIEW_RECT.size.y
	var crop_size := image_size
	if image_ratio > view_ratio:
		crop_size.x = image_size.y * view_ratio
	else:
		crop_size.y = image_size.x / view_ratio
	var crop_origin := (image_size - crop_size) * 0.5
	if image_ratio > view_ratio:
		crop_origin.x = 0.0 # Keep the small town fully visible.
	return Rect2(crop_origin, crop_size)


func _town_polygon() -> PackedVector2Array:
	var source := _map_source_rect()
	var points := PackedVector2Array()
	for source_point in TOWN_SOURCE_POINTS:
		var point: Vector2 = source_point
		var relative: Vector2 = (point - source.position) / source.size
		points.append(MAP_VIEW_RECT.position + relative * MAP_VIEW_RECT.size)
	return points


func _town_at(point: Vector2) -> bool:
	return MAP_VIEW_RECT.has_point(point) and Geometry2D.is_point_in_polygon(point, _town_polygon())


func _living_enemy_count() -> int:
	var result := 0
	for enemy in battle.enemies:
		if enemy.conscious():
			result += 1
	return result


func _draw_units() -> void:
	for enemy in battle.enemies:
		var enemy_id: int = enemy.get_instance_id()
		if enemy.conscious() or death_animations.has(enemy_id):
			_draw_animated_unit(enemy)
	for hero in battle.heroes:
		_draw_animated_unit(hero)


func _draw_targeting_banner() -> void:
	if targeting_action == "" or not battle.can_hero_act(targeting_hero_index):
		return
	var key := "E"
	if targeting_action == "melee_attack":
		key = "Q"
	elif targeting_action == "shoot":
		key = "W"
	elif targeting_action == "quick_heal" and _slot_action_id(battle.heroes[targeting_hero_index], 3) == "quick_heal":
		key = "R"
	var banner := Rect2(650, 101, 620, 49)
	draw_rect(banner, Color(0.05, 0.09, 0.08, 0.91), true)
	draw_rect(banner, Color("8ee6b0") if targeting_action == "quick_heal" else Color("e6b974"), false, 2.0)
	var prompt: String = "ВЫБЕРИТЕ ВРАГА  ·  ESC — ОТМЕНА  ·  %s — СЛУЧАЙНАЯ ЦЕЛЬ" % key
	if targeting_action == "quick_heal":
		prompt = "ВЫБЕРИТЕ ГЕРОЯ  ·  ESC — ОТМЕНА  ·  %s — САМЫЙ РАНЕНЫЙ" % key
	_text(prompt, Vector2(664, 131), 16, Color("e3f4df"), 590.0)


func _target_hitbox(unit) -> Rect2:
	return Rect2(_unit_position(unit) - Vector2(98, 88), Vector2(196, 176))


func _hero_portrait_rect(index: int) -> Rect2:
	return Rect2(14, 118.0 + float(index) * 211.0, 192, 139)


func _draw_animated_unit(unit) -> void:
	var sheet: Texture2D = _animation_sheet(unit)
	if sheet != null:
		_draw_frame_unit(unit, sheet)
		return
	var pose: Dictionary = _unit_pose(unit)
	var position: Vector2 = pose["position"]
	var rotation: float = pose["rotation"]
	var scale: float = pose["scale"]
	var tint: Color = pose["tint"]
	draw_set_transform(position, rotation, Vector2(scale, scale))
	if unit.is_hero:
		_draw_hero_sprite(unit, Vector2.ZERO, tint)
	else:
		_draw_enemy(unit, Vector2.ZERO, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _animation_sheet(unit) -> Texture2D:
	if unit.is_hero:
		match unit.class_id():
			"warrior":
				return WARRIOR_ANIMATION
			"mage":
				return MAGE_ANIMATION
			"cleric":
				return CLERIC_ANIMATION
			"archer":
				return ARCHER_ANIMATION
	else:
		match unit.id():
			"small_goblin":
				return SMALL_GOBLIN_ANIMATION
			"armored_goblin":
				return ARMORED_GOBLIN_ANIMATION
			"forest_wolf":
				return WOLF_ANIMATION
	return null


func _ability_animation(class_id: String, action_kind: String) -> Dictionary:
	# Each class keeps its original attack and signature ability frames. The
	# supplemental sheets cover the other ability types at eight frames each.
	match class_id:
		"warrior":
			match action_kind:
				"shoot": return {"sheet": WARRIOR_ABILITIES, "row": 0, "rows": 3}
				"fire_arrow", "enemy_magic": return {"sheet": WARRIOR_ABILITIES, "row": 1, "rows": 3}
				"quick_heal", "ally_magic": return {"sheet": WARRIOR_ABILITIES, "row": 2, "rows": 3}
		"mage":
			match action_kind:
				"shoot": return {"sheet": MAGE_ABILITIES, "row": 0, "rows": 2}
				"quick_heal", "ally_magic": return {"sheet": MAGE_ABILITIES, "row": 1, "rows": 2}
		"cleric":
			match action_kind:
				"shoot": return {"sheet": CLERIC_ABILITIES, "row": 0, "rows": 2}
				"fire_arrow", "enemy_magic": return {"sheet": CLERIC_ABILITIES, "row": 1, "rows": 2}
		"archer":
			match action_kind:
				"fire_arrow", "enemy_magic": return {"sheet": ARCHER_ABILITIES, "row": 0, "rows": 2}
				"quick_heal", "ally_magic": return {"sheet": ARCHER_ABILITIES, "row": 1, "rows": 2}
	return {}


func _target_mask_sheet(unit) -> Texture2D:
	if unit.is_hero:
		match unit.class_id():
			"warrior":
				return WARRIOR_TARGET_MASK
			"mage":
				return MAGE_TARGET_MASK
			"cleric":
				return CLERIC_TARGET_MASK
			"archer":
				return ARCHER_TARGET_MASK
	else:
		match unit.id():
			"small_goblin":
				return SMALL_GOBLIN_TARGET_MASK
			"armored_goblin":
				return ARMORED_GOBLIN_TARGET_MASK
			"forest_wolf":
				return WOLF_TARGET_MASK
	return null


func _target_outline_state(unit) -> int:
	if targeting_action == "" or not battle.can_hero_act(targeting_hero_index):
		return 0
	var targets: Array = battle.available_heal_targets(targeting_hero_index) if targeting_action == "quick_heal" else battle.available_enemy_targets(targeting_hero_index, targeting_action)
	if not targets.has(unit):
		return 0
	var mouse_point: Vector2 = get_local_mouse_position()
	var hovered: bool = _target_hitbox(unit).has_point(mouse_point)
	if targeting_action == "quick_heal":
		hovered = hovered or _hero_portrait_rect(battle.heroes.find(unit)).has_point(mouse_point)
	return 2 if hovered else 1


func _draw_target_outline(mask: Texture2D, destination: Rect2, column: int, row: int, rows: int, idle: bool, strength: int) -> void:
	if mask == null or strength == 0:
		return
	var glow: Color = Color("a0f1c0") if targeting_action == "quick_heal" else Color("ffd18a")
	var pulse: float = 0.5 + 0.5 * sin(animation_time * 4.0)
	if strength == 1:
		glow.a = 0.14 + 0.04 * pulse
	else:
		glow.a = 0.29 + 0.09 * pulse
	var radius: float = 2.0 if strength == 1 else 4.0
	for offset in [Vector2(-radius, 0), Vector2(radius, 0), Vector2(0, -radius), Vector2(0, radius), Vector2(-radius, -radius), Vector2(radius, -radius), Vector2(-radius, radius), Vector2(radius, radius)]:
		var shifted := Rect2(destination.position + offset, destination.size)
		if idle:
			draw_texture_rect(mask, shifted, false, glow)
		else:
			_draw_sprite_frame(mask, shifted, column, row, rows, glow)


func _draw_frame_unit(unit, sheet: Texture2D) -> void:
	var unit_id: int = unit.get_instance_id()
	var fall_row: int = 3 if unit.is_hero and unit.class_id() != "warrior" else 2
	var base_sheet: Texture2D = sheet
	var sheet_rows: int = fall_row + 1
	var idle_row: int = 1
	var idle_frame: int = 0
	if unit.is_hero:
		match unit.class_id():
			"warrior":
				idle_frame = 7
			"cleric", "archer":
				idle_row = 2
	elif unit.id() == "forest_wolf":
		idle_row = 2
	var row: int = idle_row
	var frame: int = idle_frame
	var tint: Color = Color.WHITE
	if movement_animations.has(unit_id):
		var movement: Dictionary = movement_animations[unit_id]
		var step: float = clampf(float(movement["elapsed"]) / float(movement["duration"]), 0.0, 1.0)
		row = 0
		frame = clampi(int(step * 8.0), 0, 7)
	if action_animations.has(unit_id):
		var action: Dictionary = action_animations[unit_id]
		var phase: float = clampf(float(action["elapsed"]) / float(action["duration"]), 0.0, 1.0)
		match str(action["kind"]):
			"melee":
				row = 1
				frame = clampi(int(phase * 8.0), 0, 7)
			"shoot", "fire_arrow", "quick_heal", "enemy_magic", "ally_magic":
				if unit.is_hero:
					var ability: Dictionary = _ability_animation(unit.class_id(), str(action["kind"]))
					if ability.is_empty():
						row = 2
					else:
						sheet = ability["sheet"] as Texture2D
						row = int(ability["row"])
						sheet_rows = int(ability["rows"])
					frame = clampi(int(phase * 8.0), 0, 7)
			"recover":
				row = fall_row
				frame = 7 - clampi(int(phase * 8.0), 0, 7)
	if impact_animations.has(unit_id):
		var impact: Dictionary = impact_animations[unit_id]
		var impact_phase: float = float(impact["elapsed"]) / float(impact["duration"])
		if impact_phase >= 0.0 and impact_phase < 1.0:
			sheet = base_sheet
			sheet_rows = fall_row + 1
			row = fall_row
			frame = clampi(int(impact_phase * 8.0), 0, 7)
			tint = Color(1.0, 0.68, 0.68)
	if unit.is_hero and not unit.conscious():
		sheet = base_sheet
		sheet_rows = fall_row + 1
		row = fall_row
		frame = 7
		if fall_animations.has(unit_id):
			var fall: Dictionary = fall_animations[unit_id]
			var fall_phase: float = float(fall["elapsed"]) / float(fall["duration"])
			if fall_phase < 0.0:
				row = idle_row
				frame = idle_frame
			else:
				frame = clampi(int(fall_phase * 8.0), 0, 7)
		if frame == 7:
			tint = Color(0.6, 0.6, 0.64, 0.9)
	if death_animations.has(unit_id):
		sheet = base_sheet
		sheet_rows = fall_row + 1
		var death: Dictionary = death_animations[unit_id]
		var death_phase: float = float(death["elapsed"]) / float(death["duration"])
		row = fall_row
		if death_phase < 0.0:
			row = idle_row
			frame = idle_frame
		else:
			frame = clampi(int(death_phase * 8.0), 0, 7)
			tint.a = 1.0 - clampf((death_phase - 0.7) / 0.3, 0.0, 1.0)
	if spawn_animations.has(unit_id):
		var spawn: Dictionary = spawn_animations[unit_id]
		tint.a *= clampf(float(spawn["elapsed"]) / float(spawn["duration"]), 0.0, 1.0)
	var size := Vector2(170, 170) if unit.is_hero else Vector2(168, 168)
	if unit.is_hero:
		size *= HERO_BATTLE_SPRITE_SCALE
	elif unit.id() == "forest_wolf":
		size = Vector2(194, 160)
	elif unit.id() == "small_goblin" or unit.id() == "armored_goblin":
		size *= GOBLIN_BATTLE_SPRITE_SCALE
	size.x *= ANIMATION_ATLAS_WIDTH_SCALE
	var center: Vector2 = _unit_position(unit)
	var bottom_y: float = center.y + size.y * 0.44
	if unit.is_hero and unit.class_id() == "cleric" and sheet == base_sheet:
		if row == 1:
			size *= float(CLERIC_MELEE_FRAME_SCALES[frame])
		elif row == 2:
			size *= float(CLERIC_HEAL_FRAME_SCALES[frame])
	var destination := Rect2(Vector2(center.x - size.x * 0.5, bottom_y - size.y), size)
	var use_standing_sprite: bool = unit.is_hero and unit.conscious() and not movement_animations.has(unit_id) and not action_animations.has(unit_id) and not impact_animations.has(unit_id) and not fall_animations.has(unit_id) and not death_animations.has(unit_id)
	var outline_strength: int = _target_outline_state(unit)
	if outline_strength > 0:
		var mask: Texture2D = _target_mask_sheet(unit)
		var idle_mask: bool = false
		if use_standing_sprite and unit.class_id() == "mage":
			mask = MAGE_IDLE_MASK
			idle_mask = true
		elif use_standing_sprite and unit.class_id() == "archer":
			mask = ARCHER_IDLE_MASK
			idle_mask = true
		_draw_target_outline(mask, destination, frame, row, sheet_rows, idle_mask, outline_strength)
	if use_standing_sprite and unit.class_id() == "mage":
		draw_texture_rect(MAGE_IDLE, destination, false, tint)
	elif use_standing_sprite and unit.class_id() == "archer":
		draw_texture_rect(ARCHER_IDLE, destination, false, tint)
	else:
		_draw_sprite_frame(sheet, destination, frame, row, sheet_rows, tint)
	if not unit.is_hero and unit.conscious():
		var ratio: float = clampf(float(unit.health) / float(maxi(1, unit.max_health())), 0.0, 1.0)
		var is_goblin: bool = unit.id() == "small_goblin" or unit.id() == "armored_goblin"
		var bar_width: float = 76.0 if is_goblin else 90.0
		var bar_y: float = -82.0 if is_goblin else -93.0
		draw_rect(Rect2(center + Vector2(-bar_width * 0.5, bar_y), Vector2(bar_width, 7)), Color(0.12, 0.04, 0.04, 0.8), true)
		draw_rect(Rect2(center + Vector2(1.0 - bar_width * 0.5, bar_y + 1.0), Vector2((bar_width - 2.0) * ratio, 5)), Color("d84b39"), true)


func _draw_sprite_frame(sheet: Texture2D, destination: Rect2, column: int, row: int, rows: int, tint: Color) -> void:
	# Integer bounds and a small gutter keep filtered pixels from neighboring atlas cells out.
	var left: int = roundi(float(column * sheet.get_width()) / 8.0) + 2
	var right: int = roundi(float((column + 1) * sheet.get_width()) / 8.0) - 2
	var top: int = roundi(float(row * sheet.get_height()) / float(rows)) + 2
	var bottom: int = roundi(float((row + 1) * sheet.get_height()) / float(rows)) - 2
	draw_texture_rect_region(sheet, destination, Rect2(left, top, right - left, bottom - top), tint)


func _draw_hero_sprite(hero, center: Vector2, tint: Color) -> void:
	match hero.class_id():
		"warrior":
			draw_texture_rect_region(COMBATANTS, Rect2(center - Vector2(73, 77), Vector2(146, 154)), Rect2(45, 46, 275, 246), tint)
		"mage":
			draw_texture_rect_region(COMBATANTS, Rect2(center - Vector2(73, 77), Vector2(146, 154)), Rect2(48, 288, 270, 220), tint)
		"cleric":
			draw_texture_rect(CLERIC, Rect2(center - Vector2(73, 77), Vector2(146, 154)), false, tint)
		"archer":
			draw_texture_rect(ARCHER_SPRITE, Rect2(center - Vector2(59, 83), Vector2(118, 166)), false, tint)


func _draw_enemy(enemy, center: Vector2, tint: Color) -> void:
	var enemy_id: String = enemy.id()
	if enemy_id == "forest_wolf":
		draw_texture_rect_region(COMBATANTS, Rect2(center - Vector2(84, 67), Vector2(168, 134)), Rect2(1262, 436, 306, 170), tint)
	else:
		var base_tint: Color = Color(0.72, 0.78, 0.84) if enemy_id == "armored_goblin" else Color.WHITE
		draw_texture_rect_region(COMBATANTS, Rect2(center - Vector2(74, 73), Vector2(148, 146)), Rect2(1270, 270, 250, 166), base_tint * tint)
	if not enemy.conscious():
		return
	var ratio: float = clampf(float(enemy.health) / float(maxi(1, enemy.max_health())), 0.0, 1.0)
	draw_rect(Rect2(center + Vector2(-45, -93), Vector2(90, 7)), Color(0.12, 0.04, 0.04, 0.8), true)
	draw_rect(Rect2(center + Vector2(-44, -92), Vector2(88.0 * ratio, 5)), Color("d84b39"), true)


func _unit_position(unit) -> Vector2:
	var unit_id: int = unit.get_instance_id()
	if not movement_animations.has(unit_id):
		return BOARD.center(unit.cell)
	var motion: Dictionary = movement_animations[unit_id]
	var start: Vector2 = motion["from"]
	var finish: Vector2 = motion["to"]
	var progress: float = clampf(float(motion["elapsed"]) / float(motion["duration"]), 0.0, 1.0)
	return start.lerp(finish, progress) + Vector2(0, -5.0 * sin(PI * progress))


func _unit_pose(unit) -> Dictionary:
	var unit_id: int = unit.get_instance_id()
	var position: Vector2 = _unit_position(unit)
	var rotation := 0.0
	var scale := 1.0
	var tint := Color.WHITE
	if unit.conscious():
		scale += 0.012 * sin(animation_time * 2.6 + float(unit_id % 17))
	if spawn_animations.has(unit_id):
		var spawn: Dictionary = spawn_animations[unit_id]
		var spawn_progress: float = clampf(float(spawn["elapsed"]) / float(spawn["duration"]), 0.0, 1.0)
		scale *= lerpf(0.65, 1.0, spawn_progress)
		position.y -= 12.0 * (1.0 - spawn_progress)
		tint.a *= spawn_progress
	if action_animations.has(unit_id):
		var action: Dictionary = action_animations[unit_id]
		var action_progress: float = clampf(float(action["elapsed"]) / float(action["duration"]), 0.0, 1.0)
		var motion_curve: float = sin(PI * action_progress)
		var direction: Vector2 = action["direction"]
		match str(action["kind"]):
			"melee":
				position += direction * (23.0 * motion_curve)
				rotation += 0.10 * signf(direction.x) * motion_curve
			"shoot":
				position -= direction * (9.0 * motion_curve)
				rotation -= 0.07 * signf(direction.x) * motion_curve
			"fire_arrow":
				position -= direction * (5.0 * motion_curve)
				scale += 0.08 * motion_curve
			"quick_heal":
				position.y -= 6.0 * motion_curve
				scale += 0.07 * motion_curve
			"health_potion", "mana_potion":
				position.y -= 8.0 * motion_curve
				rotation += 0.05 * motion_curve
			"recover":
				position.y += 9.0 * (1.0 - action_progress)
				rotation += 0.18 * (1.0 - action_progress)
	if impact_animations.has(unit_id):
		var impact: Dictionary = impact_animations[unit_id]
		var impact_progress: float = float(impact["elapsed"]) / float(impact["duration"])
		if impact_progress >= 0.0 and impact_progress < 1.0:
			position.x += sin(impact_progress * TAU * 2.0) * 6.0 * (1.0 - impact_progress)
			tint = tint.lerp(Color(1.0, 0.42, 0.42, tint.a), 0.75 * (1.0 - impact_progress))
	if unit.is_hero and not unit.conscious():
		var fall_progress := 1.0
		if fall_animations.has(unit_id):
			var fall: Dictionary = fall_animations[unit_id]
			fall_progress = clampf(float(fall["elapsed"]) / float(fall["duration"]), 0.0, 1.0)
		position.y += 9.0 * fall_progress
		rotation += 0.18 * fall_progress
		tint = tint.lerp(Color(0.52, 0.52, 0.56, 0.9), fall_progress)
	if death_animations.has(unit_id):
		var death: Dictionary = death_animations[unit_id]
		var death_progress: float = clampf(float(death["elapsed"]) / float(death["duration"]), 0.0, 1.0)
		position.y += 17.0 * death_progress
		rotation += 0.3 * death_progress
		scale *= 1.0 - 0.35 * death_progress
		tint.a *= 1.0 - death_progress
	return {"position": position, "rotation": rotation, "scale": scale, "tint": tint}


func _draw_visual_effects() -> void:
	for effect in visual_effects:
		var elapsed: float = float(effect["elapsed"])
		if elapsed < 0.0:
			continue
		var progress: float = clampf(elapsed / float(effect["duration"]), 0.0, 1.0)
		match str(effect["kind"]):
			"arrow", "fire":
				_draw_projectile(effect, progress)
			"slash":
				var slash_position: Vector2 = effect["position"]
				var slash_direction: Vector2 = effect["direction"]
				var slash_color := Color(1.0, 0.95, 0.7, 1.0 - progress)
				draw_arc(slash_position, 20.0 + 11.0 * progress, slash_direction.angle() - 0.9, slash_direction.angle() + 0.9, 24, slash_color, 4.0, true)
			"pulse":
				var pulse_position: Vector2 = effect["position"]
				var pulse_color: Color = effect["color"]
				pulse_color.a = 0.82 * (1.0 - progress)
				draw_arc(pulse_position, 8.0 + 38.0 * progress, 0.0, TAU, 32, pulse_color, 3.0, true)
			"burst":
				var burst_position: Vector2 = effect["position"]
				var burst_color := Color(1.0, 0.86, 0.65, 1.0 - progress)
				for ray in range(6):
					var angle: float = TAU * float(ray) / 6.0
					var direction := Vector2(cos(angle), sin(angle))
					draw_line(burst_position + direction * (6.0 + progress * 8.0), burst_position + direction * (16.0 + progress * 15.0), burst_color, 2.0, true)
			"text":
				var text_position: Vector2 = effect["position"]
				var text_color: Color = effect["color"]
				text_color.a = 1.0 - progress
				_text(str(effect["label"]), text_position + Vector2(-24, -36 - progress * 25.0), 17, text_color)


func _draw_projectile(effect: Dictionary, progress: float) -> void:
	var start: Vector2 = effect["start"]
	var finish: Vector2 = effect["end"]
	var target = effect.get("target", null)
	if target != null and target.conscious():
		finish = _unit_position(target)
	var position: Vector2 = start.lerp(finish, progress)
	var direction: Vector2 = (finish - start).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var normal := Vector2(-direction.y, direction.x)
	if str(effect["kind"]) == "arrow":
		draw_line(position - direction * 20.0, position + direction * 7.0, Color("f2e5bd"), 3.0, true)
		draw_colored_polygon(PackedVector2Array([position + direction * 13.0, position + normal * 5.0, position - normal * 5.0]), Color("d9e5e8"))
		draw_line(position - direction * 18.0, position - direction * 12.0 + normal * 5.0, Color("9bc6d2"), 2.0, true)
		draw_line(position - direction * 18.0, position - direction * 12.0 - normal * 5.0, Color("9bc6d2"), 2.0, true)
	else:
		draw_line(position - direction * 22.0, position, Color(0.96, 0.25, 0.08, 0.55), 10.0, true)
		draw_circle(position, 10.0, Color(1.0, 0.35, 0.09, 0.75))
		draw_circle(position + direction * 3.0, 5.0, Color("ffefaa"))


func _draw_hero_panel(party: Array, map_view: bool) -> void:
	draw_rect(Rect2(0, 100, 348, 900), Color(0.07, 0.06, 0.05, 0.94), true)
	draw_rect(Rect2(346, 100, 4, 900), Color("ac8750"), true)
	for index in range(4):
		var top := 109.0 + float(index) * 211.0
		var panel := Rect2(8, top, 330, 202)
		draw_rect(panel, Color(0.14, 0.13, 0.11, 0.96), true)
		draw_rect(panel, Color("8d8064"), false, 3.0)
		if index >= party.size():
			_text("Пустая ячейка", Vector2(88, top + 108), 18, Color("8b8c86"))
			continue
		var hero = party[index]
		var selected: bool = not map_view and battle.can_hero_act(index)
		var edge := Color("f9d985") if map_view and hovered_map_hero == index else (Color("c8ae76") if map_view else (Color("f6cf62") if selected else Color("717b7d")))
		var portrait := _hero_portrait_rect(index)
		draw_rect(portrait, Color("17202a"), true)
		draw_rect(portrait, edge, false, 4.0)
		_draw_portrait(hero, portrait, index)
		if not map_view and targeting_action == "quick_heal" and hero.alive():
			var hovered: bool = portrait.has_point(get_local_mouse_position())
			draw_rect(portrait, Color("b9ffd1") if hovered else Color("8ee6b0"), false, 4.0)
		_text("%d  %s · ур. %d" % [index + 1, hero.name(), int(hero.profile.get("level", 1))], Vector2(21, top + 141), 14, Color.WHITE)
		_draw_resource_bar(Rect2(14, top + 155, 192, 17), hero.health, hero.max_health(), Color("d83834"))
		_draw_resource_bar(Rect2(14, top + 178, 192, 17), hero.mana, hero.max_mana(), Color("3187dc"))
		for slot in range(6):
			_draw_action_slot(hero, top, slot, map_view)
		if not hero.conscious():
			var status := "МЁРТВ" if not hero.alive() else "БЕЗ СОЗНАНИЯ"
			_text(status, Vector2(27, top + 78), 16, Color("f48a85"))
		elif selected:
			_text("ВАШ ХОД", Vector2(228, top + 194), 12, Color("dfbd78"))


func _draw_portrait(hero, rect: Rect2, index: int) -> void:
	var inner := Rect2(rect.position + Vector2(5, 5), rect.size - Vector2(10, 10))
	var sheet: Texture2D = _portrait_sheet(hero)
	if sheet != null:
		var frame: int = _portrait_frame(hero, index)
		var frame_width: float = float(sheet.get_width()) / 4.0
		var frame_height: float = float(sheet.get_height()) / 2.0
		var crop_height: float = minf(frame_height, frame_width * inner.size.y / inner.size.x)
		var crop_top: float = (frame_height - crop_height) * 0.18
		var frame_row: int = floori(float(frame) / 4.0)
		var source := Rect2(float(frame % 4) * frame_width, float(frame_row) * frame_height + crop_top, frame_width, crop_height)
		draw_texture_rect_region(sheet, inner, source)
		return
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


func _portrait_sheet(hero) -> Texture2D:
	match hero.class_id():
		"warrior":
			return WARRIOR_PORTRAITS
		"mage":
			return MAGE_PORTRAITS
		"cleric":
			return CLERIC_PORTRAITS
		"archer":
			return ARCHER_PORTRAITS
	return null


func _portrait_frame(hero, index: int) -> int:
	var unit_id: int = hero.get_instance_id()
	if portrait_reactions.has(unit_id):
		var reaction: Dictionary = portrait_reactions[unit_id]
		if float(reaction["elapsed"]) < 0.0:
			return int(reaction.get("before", 0))
		return int(reaction["frame"])
	if not hero.alive():
		return 7
	if not hero.conscious():
		return 6
	var blink_phase: float = fposmod(animation_time + float(index) * 1.1, 4.1)
	if blink_phase >= 3.85 and blink_phase < 3.95:
		return 2
	if blink_phase >= 3.77 and blink_phase < 4.03:
		return 1
	return 0


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
		return _support_spell_for(hero)
	return SLOT_ACTIONS[slot]


func _spell_for(hero) -> String:
	if hero.has_action("fire_arrow"):
		return "fire_arrow"
	if hero.has_action("quick_heal"):
		return "quick_heal"
	return ""


func _support_spell_for(hero) -> String:
	# Keep E as the cleric's heal when it is their only spell. Heroes with both
	# spells receive the second one on R.
	if hero.has_action("fire_arrow") and hero.has_action("quick_heal"):
		return "quick_heal"
	return ""


func _slot_available(hero, slot: int) -> bool:
	if not battle.can_hero_act(battle.heroes.find(hero)):
		return false
	if slot == 4:
		return hero.health_potions > 0
	if slot == 5:
		return hero.mana_potions > 0
	var action_id := _slot_action_id(hero, slot)
	if action_id == "" or not hero.has_action(action_id):
		return false
	if action_id == "shoot":
		return battle.can_shoot(hero)
	if action_id == "fire_arrow" or action_id == "quick_heal":
		return hero.mana >= 5
	return true


func _draw_action_slot(hero, top: float, slot: int, map_view: bool) -> void:
	var rect: Rect2 = _slot_rect(top, slot)
	var action_id := _slot_action_id(hero, slot)
	var configured := false
	if slot == 4:
		configured = hero.health_potions > 0
	elif slot == 5:
		configured = hero.mana_potions > 0
	else:
		configured = action_id != "" and hero.has_action(action_id)
	var available: bool = configured if map_view else _slot_available(hero, slot)
	var edge: Color = Color("c6ab76") if available else Color("77736d")
	if not map_view and available and battle.heroes.find(hero) == targeting_hero_index and action_id == targeting_action:
		edge = Color("8ee6b0")
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
		3:
			if _slot_action_id(hero, slot) == "quick_heal":
				_draw_heal_icon(center, available)
			else:
				_draw_empty_icon(center)
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
	_text("НА КАРТУ", Vector2(733, 583), 22, Color.WHITE)


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
	body.add_child(_label("СОСТАВ ОТРЯДА", 32, Color("ead28f")))
	body.add_child(_label("Выберите героев, врагов и музыку для боёв у малого города.", 17, Color("d4d5cf")))
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
		levels.custom_minimum_size = Vector2(260, 42)
		for level in [1, 3, 5]:
			if not catalog.hero_profile(class_id, level).is_empty():
				var level_name: String = "%d уровень" % level
				if level == 3:
					level_name += " · все действия"
				levels.add_item(level_name, level)
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
	body.add_child(_label("МУЗЫКА БОЯ", 23, Color("e9c675")))
	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 14)
	body.add_child(music_row)
	music_select = OptionButton.new()
	music_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_select.custom_minimum_size = Vector2(0, 44)
	music_select.add_item("Случайная", BATTLE_AUDIO.MUSIC_RANDOM_ID)
	for index in range(BATTLE_AUDIO.MUSIC_TITLES.size()):
		music_select.add_item(str(BATTLE_AUDIO.MUSIC_TITLES[index]), index)
	music_select.select(0)
	music_select.item_selected.connect(_on_music_selected)
	music_row.add_child(music_select)
	music_preview_button = Button.new()
	music_preview_button.text = "ПРОСЛУШАТЬ"
	music_preview_button.custom_minimum_size = Vector2(190, 44)
	music_preview_button.pressed.connect(_toggle_music_preview)
	music_row.add_child(music_preview_button)
	setup_notice = _label("", 17, Color("f1a09a"))
	body.add_child(setup_notice)
	var map_button := Button.new()
	map_button.text = "НА КАРТУ"
	map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_button.custom_minimum_size = Vector2(0, 66)
	map_button.add_theme_font_size_override("font_size", 24)
	map_button.pressed.connect(_confirm_party)
	body.add_child(map_button)


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


func _selected_hero_profiles() -> Array[Dictionary]:
	var chosen_heroes: Array[Dictionary] = []
	for class_id in CLASS_ORDER:
		if hero_checks[class_id].button_pressed:
			var level: int = hero_levels[class_id].get_selected_id()
			var profile: Dictionary = catalog.hero_profile(class_id, level)
			if not profile.is_empty():
				chosen_heroes.append(profile)
	return chosen_heroes


func _confirm_party() -> void:
	var chosen_heroes: Array[Dictionary] = _selected_hero_profiles()
	if chosen_heroes.is_empty():
		setup_notice.text = "Выберите хотя бы одного героя."
		return
	party_profiles = chosen_heroes.duplicate(true)
	map_heroes.clear()
	for profile in party_profiles:
		var hero = COMBATANT.new()
		hero.initialize(profile, true, Vector2i.ZERO)
		map_heroes.append(hero)
	map_mode = true
	town_hovered = false
	hovered_map_hero = -1
	hero_sheet_index = -1
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	battle_audio.stop_preview()
	music_preview_button.text = "ПРОСЛУШАТЬ"
	setup_notice.text = ""
	setup_overlay.hide()
	queue_redraw()


func _return_to_map() -> void:
	_cancel_targeting()
	map_mode = true
	town_hovered = false
	hovered_map_hero = -1
	hero_sheet_index = -1
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	battle_audio.stop_battle()
	log_panel.hide()
	queue_redraw()


func _begin_battle() -> void:
	if party_profiles.is_empty():
		_show_setup()
		return
	var chosen_enemies: Array[Dictionary] = []
	for profile in catalog.enemies:
		var enemy_id := str(profile.get("id", ""))
		var count := int(enemy_counts[enemy_id].value)
		if count > 0:
			chosen_enemies.append({"profile": profile, "count": count})
	combat_log.clear()
	_cancel_targeting()
	log_content.text = ""
	_clear_animations()
	setup_notice.text = ""
	map_mode = false
	town_hovered = false
	hovered_map_hero = -1
	hero_sheet_index = -1
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	battle_audio.start_battle(music_select.get_selected_id())
	battle.start(party_profiles, chosen_enemies)
	queue_redraw()


func _show_setup() -> void:
	_cancel_targeting()
	battle_audio.stop_battle()
	music_preview_button.text = "ПРОСЛУШАТЬ"
	log_panel.hide()
	town_hovered = false
	hovered_map_hero = -1
	hero_sheet_index = -1
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	setup_overlay.show()
	queue_redraw()


func _toggle_music_preview() -> void:
	if battle_audio.previewing:
		battle_audio.stop_preview()
		music_preview_button.text = "ПРОСЛУШАТЬ"
	else:
		battle_audio.preview_theme(music_select.get_selected_id())
		music_preview_button.text = "ОСТАНОВИТЬ"


func _on_music_selected(_index: int) -> void:
	if battle_audio.previewing:
		battle_audio.preview_theme(music_select.get_selected_id())


func _on_music_preview_finished() -> void:
	music_preview_button.text = "ПРОСЛУШАТЬ"


func _sync_audio_pause() -> void:
	battle_audio.set_audio_paused(log_panel.visible)


func _on_battle_event(message: String) -> void:
	var prefix := "[Бой]" if battle.round_number == 0 else "[Раунд %d]" % battle.round_number
	combat_log.append("%s %s" % [prefix, message])
	if combat_log.size() > 500:
		combat_log.pop_front()
	var full_text := ""
	for line in combat_log:
		full_text += line + "\n\n"
	log_content.text = full_text
	queue_redraw()


func _on_battle_end(_victory: bool) -> void:
	_cancel_targeting()
	battle_audio.finish_battle()
	queue_redraw()


func _clear_animations() -> void:
	animation_time = 0.0
	movement_animations.clear()
	action_animations.clear()
	impact_animations.clear()
	spawn_animations.clear()
	fall_animations.clear()
	death_animations.clear()
	portrait_reactions.clear()
	visual_effects.clear()


func _on_visual_event(event: Dictionary) -> void:
	var kind: String = str(event.get("kind", ""))
	var unit = event.get("unit", null)
	if unit == null:
		return
	var unit_id: int = unit.get_instance_id()
	if kind == "move":
		_queue_movement(event)
		return
	if kind == "projectile_impact":
		_schedule_impact(event, event["target"], 0.0)
		return
	var origin: Vector2 = _unit_position(unit)
	if kind == "spawn":
		spawn_animations[unit_id] = {"elapsed": 0.0, "duration": 0.32}
		visual_effects.append({"kind": "pulse", "position": origin, "color": Color("d9a562"), "elapsed": 0.0, "duration": 0.42})
		return
	var target = event.get("target", null)
	var direction := Vector2.RIGHT if unit.is_hero else Vector2.LEFT
	var destination: Vector2 = origin + direction * 260.0
	if target != null:
		destination = _unit_position(target)
		var toward_target: Vector2 = (destination - origin).normalized()
		if toward_target != Vector2.ZERO:
			direction = toward_target
	var animation_kind: String = str(event.get("animation_type", kind))
	var action_duration := 0.44
	if animation_kind == "shoot" or animation_kind == "fire_arrow" or animation_kind == "enemy_magic":
		action_duration = 0.56
	elif animation_kind == "quick_heal" or animation_kind == "ally_magic":
		action_duration = 0.52
	action_animations[unit_id] = {"kind": animation_kind, "direction": direction, "elapsed": 0.0, "duration": action_duration}
	if unit.is_hero:
		var action_frame: int = 5 if (kind == "health_potion" or kind == "mana_potion") and int(event.get("amount", 0)) > 0 else 3
		portrait_reactions[unit_id] = {"frame": action_frame, "elapsed": 0.0, "duration": action_duration + 0.14}
	match kind:
		"melee":
			if target != null:
				var impact_delay: float = 0.22
				visual_effects.append({"kind": "slash", "position": destination, "direction": direction, "elapsed": -impact_delay, "duration": 0.25})
				_schedule_impact(event, target, impact_delay)
		"shoot", "fire_arrow":
			var launch_delay: float = float(event.get("launch_delay", 0.32))
			var travel_time: float = float(event.get("travel_time", clampf(origin.distance_to(destination) / (650.0 if kind == "shoot" else 570.0), 0.2, 0.72)))
			visual_effects.append({"kind": "arrow" if kind == "shoot" else "fire", "start": origin, "end": destination, "target": target, "elapsed": -launch_delay, "duration": travel_time})
		"quick_heal":
			var heal_position: Vector2 = destination if target != null else origin
			visual_effects.append({"kind": "pulse", "position": heal_position, "color": Color("80e6aa"), "elapsed": -0.25, "duration": 0.55})
			var recovered: int = int(event.get("amount", 0))
			if recovered > 0:
				visual_effects.append({"kind": "text", "position": heal_position, "label": "+%d" % recovered, "color": Color("a9f2ba"), "elapsed": -0.25, "duration": 0.7})
				if target != null and target.is_hero:
					portrait_reactions[target.get_instance_id()] = {"frame": 5, "before": 6 if bool(event.get("revived", false)) else 0, "elapsed": -0.25, "duration": 0.75}
			if target != null and bool(event.get("revived", false)):
				var target_id: int = target.get_instance_id()
				fall_animations.erase(target_id)
				action_animations[target_id] = {"kind": "recover", "direction": Vector2.ZERO, "elapsed": 0.0, "duration": 0.45}
		"health_potion", "mana_potion":
			var effect_color: Color = Color("ee6965") if kind == "health_potion" else Color("68b7f1")
			visual_effects.append({"kind": "pulse", "position": origin, "color": effect_color, "elapsed": 0.0, "duration": 0.5})
			var amount: int = int(event.get("amount", 0))
			if amount > 0:
				visual_effects.append({"kind": "text", "position": origin, "label": "+%d" % amount, "color": effect_color, "elapsed": 0.0, "duration": 0.7})


func _queue_movement(event: Dictionary) -> void:
	var unit = event["unit"]
	var unit_id: int = unit.get_instance_id()
	var start: Vector2 = BOARD.center(event["from_cell"])
	var finish: Vector2 = BOARD.center(event["to_cell"])
	var speed: float = maxf(0.1, float(event.get("speed", 1.0)))
	var duration: float = clampf(0.95 / speed, 0.12, 0.95)
	if movement_animations.has(unit_id):
		var current: Dictionary = movement_animations[unit_id]
		var queued: Array = current.get("queue", [])
		if queued.is_empty():
			start = current["to"]
		else:
			var last: Dictionary = queued.back()
			start = last["to"]
		queued.append({"from": start, "to": finish, "elapsed": 0.0, "duration": duration})
		current["queue"] = queued
		movement_animations[unit_id] = current
	else:
		movement_animations[unit_id] = {"from": start, "to": finish, "elapsed": 0.0, "duration": duration, "queue": []}


func _schedule_impact(event: Dictionary, target, delay: float) -> void:
	var target_id: int = target.get_instance_id()
	var position: Vector2 = _unit_position(target)
	if bool(event.get("hit", false)):
		impact_animations[target_id] = {"elapsed": -delay, "duration": 0.32}
		if target.is_hero:
			portrait_reactions[target_id] = {"frame": 4, "before": 0, "elapsed": -delay, "duration": 0.55}
		visual_effects.append({"kind": "burst", "position": position, "elapsed": -delay, "duration": 0.27})
		var damage: int = int(event.get("damage", 0))
		if damage > 0:
			visual_effects.append({"kind": "text", "position": position, "label": "−%d" % damage, "color": Color("ffaaaa"), "elapsed": -delay, "duration": 0.75})
		if target.health <= 0:
			if target.is_hero:
				fall_animations[target_id] = {"elapsed": -delay, "duration": 0.5}
			else:
				death_animations[target_id] = {"elapsed": -delay, "duration": 0.65}
	else:
		visual_effects.append({"kind": "text", "position": position, "label": "ПРОМАХ", "color": Color("eeeece"), "elapsed": -delay, "duration": 0.65})


func _advance_animations(delta: float) -> void:
	animation_time += delta
	for key in movement_animations.keys():
		var motion: Dictionary = movement_animations[key]
		var queued: Array = motion.get("queue", [])
		var remaining := delta
		var finished := false
		while remaining > 0.0:
			var time_left: float = maxf(0.0, float(motion["duration"]) - float(motion["elapsed"]))
			if remaining < time_left:
				motion["elapsed"] = float(motion["elapsed"]) + remaining
				break
			remaining -= time_left
			if queued.is_empty():
				finished = true
				break
			motion = queued.pop_front()
			motion["queue"] = queued
		if finished:
			movement_animations.erase(key)
		else:
			movement_animations[key] = motion
	_advance_timed_animations(action_animations, delta)
	_advance_timed_animations(impact_animations, delta)
	_advance_timed_animations(spawn_animations, delta)
	_advance_timed_animations(fall_animations, delta)
	_advance_timed_animations(death_animations, delta)
	_advance_timed_animations(portrait_reactions, delta)
	for index in range(visual_effects.size() - 1, -1, -1):
		var effect: Dictionary = visual_effects[index]
		effect["elapsed"] = float(effect["elapsed"]) + delta
		if float(effect["elapsed"]) >= float(effect["duration"]):
			visual_effects.remove_at(index)
		else:
			visual_effects[index] = effect


func _advance_timed_animations(animations: Dictionary, delta: float) -> void:
	for key in animations.keys():
		var state: Dictionary = animations[key]
		state["elapsed"] = float(state["elapsed"]) + delta
		if float(state["elapsed"]) >= float(state["duration"]):
			animations.erase(key)
		else:
			animations[key] = state
