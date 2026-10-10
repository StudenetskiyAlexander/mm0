extends RefCounted

const WEAPON_IDS := ["sword", "dagger", "mace", "staff", "bow"]
const ARMOR_IDS := ["chain_armor", "leather_armor", "cloth_armor"]
const MAGIC_IDS := ["fire_magic", "body_magic"]
const OTHER_IDS := []
const ALL_IDS := ["sword", "dagger", "mace", "staff", "bow", "chain_armor", "leather_armor", "cloth_armor", "fire_magic", "body_magic"]

const NAMES := {
	"sword": "Меч",
	"dagger": "Кинжал",
	"mace": "Булава",
	"staff": "Посох",
	"bow": "Лук",
	"chain_armor": "Кольчуга",
	"leather_armor": "Кожаная броня",
	"cloth_armor": "Тканевая броня",
	"fire_magic": "Магия огня",
	"body_magic": "Магия тела"
}

const DESCRIPTIONS := {
	"sword": "Каждый ранг прибавляется к точности удара мечом, если герой им вооружён.",
	"dagger": "Каждый ранг прибавляется к точности удара кинжалом, если герой им вооружён.",
	"mace": "Каждый ранг прибавляется к точности удара булавой, если герой ею вооружён.",
	"staff": "Каждый ранг прибавляется к точности удара посохом, если герой им вооружён.",
	"bow": "Каждый ранг прибавляется к точности выстрела из лука, если герой им вооружён.",
	"chain_armor": "Каждый ранг прибавляется к защите героя в кольчуге.",
	"leather_armor": "Каждый ранг прибавляется к защите героя в кожаной броне.",
	"cloth_armor": "Каждый ранг прибавляется к защите героя в тканевой броне.",
	"fire_magic": "Навык магии огня. В текущей версии пока не усиливает Огненную стрелу.",
	"body_magic": "Навык магии тела. В текущей версии пока не усиливает Быстрое лечение."
}
