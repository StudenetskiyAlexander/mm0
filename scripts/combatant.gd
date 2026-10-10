extends RefCounted

const SKILLS = preload("res://scripts/skill_catalog.gd")

var profile: Dictionary = {}
var is_hero := false
var cell := Vector2i.ZERO
var health := 0
var mana := 0
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


func skill_points() -> int:
	return int(profile.get("unspent_skill_points", 0))


func skill_upgrade_cost(key: String) -> int:
	if not SKILLS.ALL_IDS.has(key):
		return 0
	return skill(key) + 1


func can_upgrade_skill(key: String) -> bool:
	var cost: int = skill_upgrade_cost(key)
	return is_hero and cost > 0 and skill_points() >= cost


func spend_skill_points(key: String) -> bool:
	if not can_upgrade_skill(key):
		return false
	var cost: int = skill_upgrade_cost(key)
	var skills: Dictionary = profile.get("skills", {})
	skills[key] = skill(key) + 1
	profile["skills"] = skills
	profile["unspent_skill_points"] = skill_points() - cost
	return true


func max_health() -> int:
	return 5 * attribute("endurance")


func max_mana() -> int:
	return 5 * attribute("intelligence")


func attribute_points() -> int:
	return int(profile.get("unspent_attribute_points", 0))


func spend_attribute_point(key: String) -> bool:
	if not is_hero or attribute_points() <= 0 or not ["strength", "dexterity", "endurance", "intelligence"].has(key):
		return false
	var points_before := attribute_points()
	var old_max_health := max_health()
	var old_max_mana := max_mana()
	var attributes: Dictionary = profile.get("attributes", {})
	attributes[key] = int(attributes.get(key, 0)) + 1
	profile["attributes"] = attributes
	var allocations: Dictionary = profile.get("level_up_attribute_allocations", {})
	allocations[key] = int(allocations.get(key, 0)) + 1
	profile["level_up_attribute_allocations"] = allocations
	profile["unspent_attribute_points"] = points_before - 1
	if health > 0:
		health += max_health() - old_max_health
	mana += max_mana() - old_max_mana
	return true


func accuracy(ranged: bool = false) -> int:
	var attribute_key := "dexterity" if ranged else "strength"
	return attribute(attribute_key) + weapon_skill_bonus(ranged) + weapon_accuracy_bonus(ranged)


func weapon_skill_bonus(ranged: bool = false) -> int:
	if is_hero:
		return 0 # Heroes have no equipped items until the inventory is implemented.
	return skill(str(weapon(ranged).get("skill_id", "")))


func weapon_accuracy_bonus(ranged: bool = false) -> int:
	if is_hero:
		return 0
	return int(weapon(ranged).get("accuracy_bonus", 0))


func armor_skill_bonus() -> int:
	if is_hero:
		return 0
	var armor_value: Variant = profile.get("armor", null)
	if armor_value is Dictionary:
		return skill(str(armor_value.get("skill_id", "")))
	return 0


func defense() -> int:
	return 10 + attribute("dexterity") + armor_skill_bonus()


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
