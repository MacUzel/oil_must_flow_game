extends Node2D

@export var game_over_scene: PackedScene
@export var mine_scene: PackedScene
@export var drone_scene: PackedScene
@export var missile_scene: PackedScene
@export var powerup_scene: PackedScene

var spawn_timer: float = 0.0
var spawn_interval: float = 2.0
var distance: float = 0.0
var bg_speed: float = 150.0
var game_active: bool = true

var powerup_timer: float = 12.0

# Başarım takibi (bu oturumda gösterilenleri tekrar gösterme)
var _shown_achievements: Dictionary = {}

# Kamera sarsıntısı
var shake_time: float = 0.0
const SHAKE_STRENGTH: float = 9.0

@onready var ui = $Ui
@onready var ship = $CharacterBody2D2
@onready var full_bg = $FullBG
@onready var bg1 = $BG1
@onready var bg2 = $BG2
@onready var deep_water = $DeepWater
@onready var camera = $Camera2D
@onready var left_wall = $LeftWall
@onready var right_wall = $RightWall
@onready var left_foam: Line2D = $LeftWall/LeftFoam
@onready var right_foam: Line2D = $RightWall/RightFoam
@onready var music_player: AudioStreamPlayer = $MusicPlayer

var foam_time: float = 0.0

# Dalga animasyonu
var _wave_lines: Array = []
var _wave_base_pts: Array = []
var _wave_phases: Array = []
var _wave_freqs: Array = []

# Deniz parıltısı (güneş yansıması hissi)
var _glints: Array = []
var _glint_timer: float = 0.0

const GAME_MUSIC_PATH := "res://assets/audio/game_music.mp3"

const WATER_GRADIENT := [
	[0.0,    Color(0.18, 0.55, 0.85, 1.0)],   # açık mavi
	[1000.0, Color(0.04, 0.20, 0.55, 1.0)],   # orta mavi
	[2000.0, Color(0.05, 0.03, 0.30, 1.0)],   # koyu mavi-mor
	[3500.0, Color(0.55, 0.20, 0.05, 1.0)],   # turuncu
	[5000.0, Color(0.65, 0.03, 0.03, 1.0)],   # kırmızı
]


func _ready():
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	ship.hp_changed.connect(_on_hp_changed)
	ship.ship_destroyed.connect(_on_ship_destroyed)
	ui.update_hp(ship.hp, ship.max_hp)
	_setup_water_surface()
	_play_music()
	_add_depth_overlay()


func _play_music() -> void:
	if ResourceLoader.exists(GAME_MUSIC_PATH):
		var stream := load(GAME_MUSIC_PATH) as AudioStreamMP3
		if stream:
			stream.loop = true
			music_player.stream = stream
			music_player.play()


func _setup_water_surface() -> void:
	var wave_ys := [70, 170, 290, 410, 530, 650, 770, 880]
	for tile in [bg1, bg2]:
		for y in wave_ys:
			var wave := Line2D.new()
			wave.width = randf_range(1.2, 2.8)
			wave.default_color = Color(1.0, 1.0, 1.0, randf_range(0.04, 0.09))
			var x1 := randf_range(75.0, 160.0)
			var x2 := randf_range(370.0, 455.0)
			wave.add_point(Vector2(x1, float(y)))
			wave.add_point(Vector2(x2, float(y)))
			tile.add_child(wave)
			_wave_lines.append(wave)
			_wave_base_pts.append(PackedVector2Array([Vector2(x1, float(y)), Vector2(x2, float(y))]))
			_wave_phases.append(randf_range(0.0, TAU))
			_wave_freqs.append(randf_range(0.5, 1.6))


func _process(delta):
	if not game_active:
		return

	# Kamera sarsıntısı
	if shake_time > 0.0:
		shake_time -= delta
		camera.offset = Vector2(
			randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH),
			randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH)
		)
	else:
		camera.offset = Vector2.ZERO
	camera.position = Vector2(270, 480)

	distance += delta * 50
	# Spawn aralığı: 2.2s'den başlayıp 1200m'de 0.7s'ye iner (daha yumuşak eğri)
	spawn_interval = max(0.7, 2.2 - distance / 800.0)
	# Arkaplan hızı mesafeyle artar: 150 → 240 px/s (5000m'de)
	bg_speed = clamp(150.0 + distance * 0.018, 150.0, 240.0)

	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_obstacle()
		spawn_timer = spawn_interval

	ui.update_distance(distance)
	_update_water_color(distance)
	_check_achievements()
	_update_depth_scale()

	foam_time += delta
	var foam_alpha := 0.12 + 0.18 * (0.5 + 0.5 * sin(foam_time * 1.3))
	left_foam.default_color = Color(1.0, 1.0, 1.0, foam_alpha)
	right_foam.default_color = Color(1.0, 1.0, 1.0, foam_alpha)
	_animate_waves()
	_update_glints(delta)

	powerup_timer -= delta
	if powerup_timer <= 0.0:
		_spawn_powerup()
		powerup_timer = randf_range(10.0, 18.0)

	bg1.position.y += bg_speed * delta
	bg2.position.y += bg_speed * delta
	if bg1.position.y >= 960:
		bg1.position.y = bg2.position.y - 960
	if bg2.position.y >= 960:
		bg2.position.y = bg1.position.y - 960


func spawn_obstacle() -> void:
	# Mesafeye göre kaç düşman çıkacak
	var count := 1
	if distance > 2500:
		count = 1 + (randi() % 2)   # 1-2
	if distance > 4500:
		count = 2 + (randi() % 2)   # 2-3

	for _i in count:
		_spawn_single_obstacle()


func _spawn_single_obstacle() -> void:
	# Mesafeye göre ağırlıklı seçim
	var mine_w    := 1.0
	var drone_w   := clampf(distance / 600.0,  0.4, 3.5)
	var missile_w := clampf(distance / 1200.0, 0.1, 3.5)

	var total := mine_w + drone_w + missile_w
	var roll  := randf() * total

	var scene: PackedScene
	if roll < mine_w:
		scene = mine_scene
	elif roll < mine_w + drone_w:
		scene = drone_scene
	else:
		scene = missile_scene

	if scene == null:
		return

	var obstacle := scene.instantiate()
	obstacle.add_to_group("enemy")

	if scene == drone_scene or scene == missile_scene:
		add_child(obstacle)
		return

	var screen_width := get_viewport().get_visible_rect().size.x
	obstacle.position.x = randf_range(76.0, screen_width - 76.0)
	obstacle.position.y = -50.0
	add_child(obstacle)


func _spawn_powerup() -> void:
	if powerup_scene == null:
		return
	var pu = powerup_scene.instantiate()
	pu.type = randi() % 3
	var screen_width := get_viewport().get_visible_rect().size.x
	pu.position.x = randf_range(76.0, screen_width - 76.0)
	pu.position.y = -50.0
	add_child(pu)


func _update_water_color(dist: float) -> void:
	var color := WATER_GRADIENT[0][1] as Color
	for i in range(WATER_GRADIENT.size() - 1):
		var from_dist: float = WATER_GRADIENT[i][0]
		var to_dist: float   = WATER_GRADIENT[i + 1][0]
		if dist <= to_dist:
			var t := (dist - from_dist) / (to_dist - from_dist)
			color = (WATER_GRADIENT[i][1] as Color).lerp(WATER_GRADIENT[i + 1][1], t)
			break
		color = WATER_GRADIENT[i + 1][1]
	full_bg.color = color
	bg1.color = color
	bg2.color = color
	deep_water.color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.55, 0.45)


func _on_hp_changed(new_hp: int) -> void:
	shake_time = 0.45
	var max_hp: int = ship.max_hp if is_instance_valid(ship) else 3
	ui.update_hp(new_hp, max_hp)


func _check_achievements() -> void:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return
	for def in pd.ACHIEVEMENT_DEFS:
		var id: String = def["id"]
		if distance >= float(def["distance"]) and not _shown_achievements.get(id, false):
			_shown_achievements[id] = true
			if not pd.is_achievement_unlocked(id):
				pd.unlock_achievement(id)
				if id == "fleet_cmdr":
					pd.unlock_ship("battleship")
				_show_achievement_banner(def["name"], def["desc"])


func _show_achievement_banner(aname: String, adesc: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var panel := Panel.new()
	panel.set_position(Vector2(40.0, 90.0))
	panel.set_size(Vector2(460.0, 100.0))
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.05, 0.25, 0.12, 0.96)
	style.corner_radius_top_left     = 14
	style.corner_radius_top_right    = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left  = 14
	style.border_width_left          = 2
	style.border_width_top           = 2
	style.border_width_right         = 2
	style.border_width_bottom        = 2
	style.border_color               = Color(0.30, 0.80, 0.45)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var title_lbl := Label.new()
	title_lbl.set_position(Vector2(14.0, 8.0))
	title_lbl.set_size(Vector2(432.0, 38.0))
	title_lbl.text = "🏆  BAŞARIM: " + aname
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.20))
	panel.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.set_position(Vector2(14.0, 52.0))
	desc_lbl.set_size(Vector2(432.0, 34.0))
	desc_lbl.text = adesc
	desc_lbl.add_theme_font_size_override("font_size", 17)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 0.75))
	panel.add_child(desc_lbl)

	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(layer):
		layer.queue_free()


func _on_ship_destroyed():
	game_active = false
	music_player.stop()
	ui.disable_pause_button()
	var game_over = game_over_scene.instantiate()
	get_tree().current_scene.add_child(game_over)
	game_over.setup(distance)


func _update_depth_scale() -> void:
	# Üstteki düşmanlar küçük (uzak), alttakiler büyük (yakın) — perspektif illüzyonu
	var screen_h: float = get_viewport().get_visible_rect().size.y
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		var depth: float = clamp(enemy.global_position.y / screen_h, 0.0, 1.0)
		var s: float     = lerp(0.55, 1.05, depth)
		enemy.scale = Vector2(s, s)


func _animate_waves() -> void:
	var t := foam_time
	for i in _wave_lines.size():
		if not is_instance_valid(_wave_lines[i]):
			continue
		var wave: Line2D = _wave_lines[i]
		var phase: float  = _wave_phases[i]
		var freq: float   = _wave_freqs[i]
		var base: PackedVector2Array = _wave_base_pts[i]
		var shift_x := sin(t * freq + phase) * 7.5
		var shift_y := cos(t * freq * 0.6 + phase) * 1.4
		wave.points = PackedVector2Array([
			base[0] + Vector2(shift_x, shift_y),
			base[1] + Vector2(shift_x * 0.55, shift_y),
		])
		wave.modulate.a = 0.55 + 0.45 * abs(sin(t * freq * 0.4 + phase))


func _update_glints(delta: float) -> void:
	_glint_timer -= delta
	if _glint_timer <= 0.0:
		_glint_timer = randf_range(0.10, 0.30)
		var screen := get_viewport().get_visible_rect().size
		_glints.append({
			"pos":  Vector2(randf_range(82.0, screen.x - 82.0), randf_range(85.0, screen.y - 85.0)),
			"t":    0.0,
			"dur":  randf_range(0.35, 1.05),
			"size": randf_range(1.0, 3.2),
		})
	var i := _glints.size() - 1
	while i >= 0:
		_glints[i]["t"] += delta
		if _glints[i]["t"] >= _glints[i]["dur"]:
			_glints.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	for g in _glints:
		var t: float = g["t"] / g["dur"]
		var alpha := sin(t * PI) * 0.28
		draw_circle(g["pos"], g["size"], Color(0.82, 0.96, 1.0, alpha))


func _add_depth_overlay() -> void:
	# Gradient Polygon2D'ler — yukarıdan bakış kamera hissi yaratır.
	# Regular Node2D olarak eklendi → kameradan etkilenmez (camera fixed),
	# CanvasLayer değil → UI'ın altında kalır.

	# Ufuk pusluluğu: üstten orta ekrana doğru açık mavi silinir
	var haze := Polygon2D.new()
	haze.polygon = PackedVector2Array([
		Vector2(0.0,   0.0), Vector2(540.0,   0.0),
		Vector2(540.0, 310.0), Vector2(0.0, 310.0),
	])
	haze.vertex_colors = PackedColorArray([
		Color(0.52, 0.74, 0.92, 0.24),
		Color(0.52, 0.74, 0.92, 0.24),
		Color(0.52, 0.74, 0.92, 0.00),
		Color(0.52, 0.74, 0.92, 0.00),
	])
	haze.z_index = 90
	add_child(haze)

	# Alt koyulaşma: yakın su daha koyu/derin
	var dark := Polygon2D.new()
	dark.polygon = PackedVector2Array([
		Vector2(0.0,   660.0), Vector2(540.0,   660.0),
		Vector2(540.0, 960.0), Vector2(0.0, 960.0),
	])
	dark.vertex_colors = PackedColorArray([
		Color(0.0, 0.01, 0.06, 0.00),
		Color(0.0, 0.01, 0.06, 0.00),
		Color(0.0, 0.01, 0.06, 0.16),
		Color(0.0, 0.01, 0.06, 0.16),
	])
	dark.z_index = 90
	add_child(dark)

	# Sol vignette
	var lv := Polygon2D.new()
	lv.polygon = PackedVector2Array([
		Vector2(0.0,  0.0), Vector2(65.0,  0.0),
		Vector2(65.0, 960.0), Vector2(0.0, 960.0),
	])
	lv.vertex_colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.20), Color(0.0, 0.0, 0.0, 0.00),
		Color(0.0, 0.0, 0.0, 0.00), Color(0.0, 0.0, 0.0, 0.20),
	])
	lv.z_index = 90
	add_child(lv)

	# Sağ vignette
	var rv := Polygon2D.new()
	rv.polygon = PackedVector2Array([
		Vector2(475.0, 0.0), Vector2(540.0,   0.0),
		Vector2(540.0, 960.0), Vector2(475.0, 960.0),
	])
	rv.vertex_colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.00), Color(0.0, 0.0, 0.0, 0.20),
		Color(0.0, 0.0, 0.0, 0.20), Color(0.0, 0.0, 0.0, 0.00),
	])
	rv.z_index = 90
	add_child(rv)
