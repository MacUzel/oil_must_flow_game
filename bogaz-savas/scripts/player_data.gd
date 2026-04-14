extends Node

## Merkezi oyuncu verisi — Autoload olarak kayıtlı olmalı (PlayerData).
## Project > Project Settings > Autoload > scripts/player_data.gd

const SAVE_PATH = "user://save_data.cfg"
const MAX_UPGRADE_LEVEL = 3
const UPGRADE_COSTS: Dictionary = {
	"speed":   [100, 250, 500],
	"agility": [100, 250, 500],
	"armor":   [150, 350, 700],
}
const SHIP_DEFS: Array = [
	{"id": "default",    "name": "Balıkçı Teknesi", "price": 0,    "gem_price": 0,   "icon": "⛵"},
	{"id": "patrol",     "name": "Devriye Botu",     "price": 300,  "gem_price": 10,  "icon": "🚤"},
	{"id": "rescue",     "name": "Kurtarma Gemisi",  "price": 600,  "gem_price": 20,  "icon": "🔴"},
	{"id": "destroyer",  "name": "Muhrip",            "price": 1000, "gem_price": 35,  "icon": "⚔"},
	{"id": "cruiser",    "name": "Kruvazör",          "price": 1800, "gem_price": 59,  "icon": "🛡"},
	{"id": "submarine",  "name": "Denizaltı",         "price": 2500, "gem_price": 79,  "icon": "🌊"},
	{"id": "carrier",    "name": "Uçak Gemisi",       "price": 4000, "gem_price": 119, "icon": "✈"},
	{"id": "battleship", "name": "Savaş Gemisi",      "price": 6000, "gem_price": 149, "icon": "💥"},
]

const ACHIEVEMENT_DEFS: Array = [
	{"id": "first_pass",    "name": "İlk Geçiş",    "desc": "500m'ye ulaştın!",             "distance": 500},
	{"id": "canal_conq",    "name": "Kanal Aşıcı",   "desc": "1000m'ye ulaştın!",            "distance": 1000},
	{"id": "strait_master", "name": "Boğaz Ustası",  "desc": "2500m'ye ulaştın!",            "distance": 2500},
	{"id": "fleet_cmdr",    "name": "Filo Komutanı", "desc": "5000m - Savaş Gemisi açıldı!", "distance": 5000},
]

var gold: int = 0
var gems: int = 0
var upgrade_speed: int   = 0
var upgrade_agility: int = 0
var upgrade_armor: int   = 0
var selected_ship: String    = "default"
var unlocked_ships: Array    = ["default"]
var achievements: Dictionary = {}
## Kontrol şeması: "joystick" | "dpad" | "tilt"
var control_scheme: String = "joystick"


func _ready() -> void:
	load_data()


func load_data() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	gold            = config.get_value("economy",   "gold",          0)
	gems            = config.get_value("economy",   "gems",          0)
	upgrade_speed   = config.get_value("upgrades",  "speed",         0)
	upgrade_agility = config.get_value("upgrades",  "agility",       0)
	upgrade_armor   = config.get_value("upgrades",  "armor",         0)
	selected_ship   = config.get_value("ships",     "selected",      "default")
	unlocked_ships  = config.get_value("ships",     "unlocked",      ["default"])
	control_scheme  = config.get_value("settings",  "control_scheme","joystick")
	for def in ACHIEVEMENT_DEFS:
		achievements[def["id"]] = config.get_value("achievements", def["id"], false)


func save_data() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("economy",  "gold",           gold)
	config.set_value("economy",  "gems",           gems)
	config.set_value("upgrades", "speed",          upgrade_speed)
	config.set_value("upgrades", "agility",        upgrade_agility)
	config.set_value("upgrades", "armor",          upgrade_armor)
	config.set_value("ships",    "selected",       selected_ship)
	config.set_value("ships",    "unlocked",       unlocked_ships)
	config.set_value("settings", "control_scheme", control_scheme)
	for def in ACHIEVEMENT_DEFS:
		config.set_value("achievements", def["id"], achievements.get(def["id"], false))
	config.save(SAVE_PATH)


func add_gold(amount: int) -> void:
	gold += amount
	save_data()


## Elmas ekle — Google Play Billing'den gelen IAP ödülleri için.
func add_gems(amount: int) -> void:
	gems += amount
	save_data()


func get_upgrade_level(type: String) -> int:
	match type:
		"speed":   return upgrade_speed
		"agility": return upgrade_agility
		"armor":   return upgrade_armor
	return 0


func get_upgrade_cost(type: String) -> int:
	var level := get_upgrade_level(type)
	if level >= MAX_UPGRADE_LEVEL:
		return -1
	return UPGRADE_COSTS[type][level]


func buy_upgrade(type: String) -> bool:
	var cost := get_upgrade_cost(type)
	if cost < 0 or gold < cost:
		return false
	gold -= cost
	match type:
		"speed":   upgrade_speed   += 1
		"agility": upgrade_agility += 1
		"armor":   upgrade_armor   += 1
	save_data()
	return true


func unlock_ship(ship_id: String) -> void:
	if ship_id not in unlocked_ships:
		unlocked_ships.append(ship_id)
		save_data()


func buy_ship(ship_id: String) -> bool:
	if ship_id in unlocked_ships:
		return false
	for def in SHIP_DEFS:
		if def["id"] == ship_id:
			if gold < def["price"]:
				return false
			gold -= def["price"]
			unlock_ship(ship_id)
			save_data()
			return true
	return false


## Elmasla gemi satın alma — IAP sonrası çağrılır.
func buy_ship_with_gems(ship_id: String) -> bool:
	if ship_id in unlocked_ships:
		return false
	for def in SHIP_DEFS:
		if def["id"] == ship_id:
			var gem_price: int = def.get("gem_price", 0)
			if gem_price <= 0 or gems < gem_price:
				return false
			gems -= gem_price
			unlock_ship(ship_id)
			save_data()
			return true
	return false


func select_ship(ship_id: String) -> void:
	if ship_id in unlocked_ships:
		selected_ship = ship_id
		save_data()


func get_ship_def(ship_id: String) -> Dictionary:
	for def in SHIP_DEFS:
		if def["id"] == ship_id:
			return def
	return {}


func is_achievement_unlocked(id: String) -> bool:
	return achievements.get(id, false)


func unlock_achievement(id: String) -> void:
	if not achievements.get(id, false):
		achievements[id] = true
		save_data()
