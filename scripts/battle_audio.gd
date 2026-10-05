extends Node

const BOARD = preload("res://scripts/hex_board.gd")
const BATTLE_THEME: AudioStreamWAV = preload("res://assets/audio/battle-theme.wav")
const SOUNDS := {
	"sword_swing": preload("res://assets/audio/sword_swing.wav"),
	"hit": preload("res://assets/audio/hit.wav"),
	"miss": preload("res://assets/audio/miss.wav"),
	"bow": preload("res://assets/audio/bow.wav"),
	"fire_cast": preload("res://assets/audio/fire_cast.wav"),
	"fire_hit": preload("res://assets/audio/fire_hit.wav"),
	"heal": preload("res://assets/audio/heal.wav"),
	"potion": preload("res://assets/audio/potion.wav"),
	"spawn": preload("res://assets/audio/spawn.wav"),
	"fall": preload("res://assets/audio/fall.wav"),
	"step": preload("res://assets/audio/step.wav"),
	"bite": preload("res://assets/audio/bite.wav"),
	"axe_swing": preload("res://assets/audio/axe_swing.wav"),
	"magic_miss": preload("res://assets/audio/magic_miss.wav"),
}

var music_player: AudioStreamPlayer
var active_players: Array[AudioStreamPlayer] = []
var queued_sounds: Array[Dictionary] = []
var paused := false
var music_enabled := false
var step_cooldown := 0.0


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.stream = BATTLE_THEME
	music_player.volume_db = -4.0
	add_child(music_player)


func _process(delta: float) -> void:
	if paused:
		return
	if music_enabled and not music_player.playing:
		music_player.play()
	step_cooldown = maxf(0.0, step_cooldown - delta)
	for index in range(queued_sounds.size() - 1, -1, -1):
		var sound: Dictionary = queued_sounds[index]
		sound["delay"] = float(sound["delay"]) - delta
		if float(sound["delay"]) <= 0.0:
			_play_sound(str(sound["name"]), float(sound["volume_db"]))
			queued_sounds.remove_at(index)
		else:
			queued_sounds[index] = sound


func start_battle() -> void:
	stop_battle()
	music_enabled = true
	paused = false
	music_player.stream_paused = false
	music_player.play()


func finish_battle() -> void:
	music_enabled = false
	music_player.stop()
	# Let the final hit and fall finish even though the battle state has ended.


func stop_battle() -> void:
	music_enabled = false
	music_player.stop()
	queued_sounds.clear()
	step_cooldown = 0.0
	for player in active_players:
		player.stop()
		player.queue_free()
	active_players.clear()


func set_audio_paused(value: bool) -> void:
	paused = value
	music_player.stream_paused = value
	for player in active_players:
		player.stream_paused = value


func handle_visual_event(event: Dictionary) -> void:
	var kind: String = str(event.get("kind", ""))
	if kind == "move":
		if step_cooldown <= 0.0:
			_schedule("step", 0.0, -19.0)
			step_cooldown = 0.18
		return
	if kind == "spawn":
		_schedule("spawn", 0.0, -11.0)
		return
	var target = event.get("target", null)
	var unit = event.get("unit", null)
	if kind == "projectile_impact":
		_schedule_impact(event, target, 0.0, str(event.get("projectile_kind", "")) == "fire_arrow")
		return
	match kind:
		"melee":
			var swing := "sword_swing"
			if unit != null and not unit.is_hero:
				if unit.id() == "forest_wolf":
					swing = "bite"
				elif unit.id() == "armored_goblin":
					swing = "axe_swing"
			_schedule(swing, 0.0, -7.0)
			_schedule_impact(event, target, 0.22, false)
		"shoot", "fire_arrow":
			var launch_delay: float = float(event.get("launch_delay", 0.32))
			if unit == null:
				return
			var origin: Vector2 = BOARD.center(unit.cell)
			var destination: Vector2 = origin + Vector2(260.0, 0.0)
			if target != null:
				destination = BOARD.center(target.cell)
			var speed := 650.0 if kind == "shoot" else 570.0
			var travel_time: float = float(event.get("travel_time", clampf(origin.distance_to(destination) / speed, 0.2, 0.72)))
			_schedule("bow" if kind == "shoot" else "fire_cast", launch_delay, -7.0)
			if target == null:
				_schedule_impact(event, target, launch_delay + travel_time, kind == "fire_arrow")
		"quick_heal":
			_schedule("heal", 0.24, -5.0)
		"health_potion", "mana_potion":
			_schedule("potion", 0.0, -6.0)


func _schedule_impact(event: Dictionary, target, delay: float, magical: bool) -> void:
	if target == null or not bool(event.get("hit", false)):
		_schedule("magic_miss" if magical else "miss", delay, -10.0)
		return
	_schedule("fire_hit" if magical else "hit", delay, -5.0)
	if target.health <= 0:
		_schedule("fall", delay + 0.12, -9.0)


func _schedule(name: String, delay: float, volume_db: float) -> void:
	queued_sounds.append({"name": name, "delay": delay, "volume_db": volume_db})


func _play_sound(name: String, volume_db: float) -> void:
	if active_players.size() >= 16:
		return
	var player := AudioStreamPlayer.new()
	player.stream = SOUNDS[name]
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.95, 1.05)
	add_child(player)
	active_players.append(player)
	player.finished.connect(func() -> void:
		active_players.erase(player)
		player.queue_free()
	)
	player.play()
