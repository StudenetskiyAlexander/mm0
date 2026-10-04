extends RefCounted

var profile: Dictionary = {}
var is_hero := false
var cell := Vector2i.ZERO
var health := 0
var mana := 0
var cooldown := 0.0
var movement_progress := 0.0
var health_potions := 0
var mana_potions := 0


func initialize(source: Dictionary, hero: bool, starting_cell: Vector2i) -> void:
	profile = source.duplicate(true)
	is_hero = hero
	cell = starting_cell
	health = max_health()
	mana = max_mana()
	if hero:
		var potions: Dictionary = profile.get("potions", {})
		health_potions = int(potions.get("health", 0))
		mana_potions = int(potions.get("mana", 0))


func name() -> String:
	return str(profile.get("name", "Неизвестный"))


func id() -> String:
	return str(profile.get("id", ""))


func class_id() -> String:
	return str(profile.get("class_id", ""))


func attribute(key: String) -> int:
	var attributes: Dictionary = profile.get("attributes", {})
	return int(attributes.get(key, 0))


func skill(key: String) -> int:
	var skills: Dictionary = profile.get("skills", {})
	return int(skills.get(key, 0))


func max_health() -> int:
	return 5 * attribute("endurance")


func max_mana() -> int:
	return 5 * attribute("intelligence")


func defense() -> int:
	var armor_value: Variant = profile.get("armor", null)
	var armor_skill := 0
	if armor_value is Dictionary:
		armor_skill = skill(str(armor_value.get("skill_id", "")))
	return 10 + attribute("dexterity") + armor_skill + int(profile.get("defense_equipment_bonus", 0))


func weapon(ranged: bool = false) -> Dictionary:
	if ranged:
		return profile.get("ranged_weapon", {})
	return profile.get("weapon", {})


func has_action(action_id: String) -> bool:
	var actions: Array = profile.get("actions", [])
	return actions.has(action_id)


func alive() -> bool:
	return health >= -10


func conscious() -> bool:
	return health > 0


func ready() -> bool:
	return conscious() and cooldown <= 0.0


func restore_health(amount: int) -> int:
	if not alive():
		return 0
	var previous := health
	health = mini(max_health(), health + amount)
	return health - previous


func restore_mana(amount: int) -> int:
	var previous := mana
	mana = mini(max_mana(), mana + amount)
	return mana - previous
