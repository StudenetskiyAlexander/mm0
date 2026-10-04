extends RefCounted

const HERO_DIRECTORY := "res://outputs/game-data/heroes"
const ENEMY_DIRECTORY := "res://outputs/game-data/enemies"

var heroes: Array[Dictionary] = []
var enemies: Array[Dictionary] = []


func load_all() -> void:
	heroes = _load_folder(HERO_DIRECTORY)
	enemies = _load_folder(ENEMY_DIRECTORY)


func _load_folder(folder: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for filename in DirAccess.get_files_at(folder):
		if not filename.ends_with(".json"):
			continue
		var file := FileAccess.open(folder.path_join(filename), FileAccess.READ)
		if file == null:
			push_error("Не удалось открыть " + folder.path_join(filename))
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			result.append(parsed)
		else:
			push_error("Некорректный JSON: " + folder.path_join(filename))
	return result


func hero_profile(class_id: String, level: int) -> Dictionary:
	for profile in heroes:
		if str(profile.get("class_id", "")) == class_id and int(profile.get("level", 0)) == level:
			return profile
	return {}


func enemy_profile(enemy_id: String) -> Dictionary:
	for profile in enemies:
		if str(profile.get("id", "")) == enemy_id:
			return profile
	return {}
