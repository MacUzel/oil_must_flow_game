extends Node2D

const SAVE_PATH = "user://save_data.cfg"
const BG_SPEED = 150.0

# ── Sinematik kamera sabitleri ──────────────────────────────────────────────
const _CIN_ZOOM_START: float  = 2.20   # Menü açılış yakınlığı
const _CIN_SHIP_X: float      = 270.0
const _CIN_SHIP_Y: float      = 750.0
const _CIN_CAM_Y_START: float = 715.0  # Kamera başlangıç (gemi biraz altı)
const _CIN_CAM_Y_END: float   = 480.0  # Kamera bitiş (tam merkez)
const _CIN_DURATION: float    = 2.10   # Çekiliş süresi (sn)

const _MENU_SHIP_SPRITES: Dictionary = {
	"patrol":     "res://assets/sprites/PatrolBoat/ShipPatrolHull.png",
	"destroyer":  "res://assets/sprites/Destroyer/ShipDestroyerHull.png",
	"cruiser":    "res://assets/sprites/Cruiser/ShipCruiserHull.png",
	"battleship": "res://assets/sprites/Battleship/ShipBattleshipHull.png",
	"submarine":  "res://assets/sprites/Submarine/ShipSubMarineHull.png",
	"carrier":    "res://assets/sprites/Carrier/ShipCarrierHull.png",
	"rescue":     "res://assets/sprites/Rescue Ship/ShipRescue.png",
}

var sound_enabled := true
var vibration_enabled := true
var high_score := 0

var _ctrl_btns: Dictionary = {}  # scheme_id -> Button

# Sinematik çalışma zamanı
var _cam: Camera2D            = null
var _menu_ship_node: Node2D   = null
var _ship_bob_time: float     = 0.0
var _fade_rect: ColorRect     = null
var _cinematic_playing: bool  = false

@onready var bg1: ColorRect = $BG1
@onready var bg2: ColorRect = $BG2
@onready var settings_panel = $CanvasLayer/Control/SettingsPanel
@onready var high_score_label: Label = $CanvasLayer/Control/HighScoreLabel
@onready var sound_btn: Button = $CanvasLayer/Control/SettingsPanel/VBoxContainer/SoundButton
@onready var vibration_btn: Button = $CanvasLayer/Control/SettingsPanel/VBoxContainer/VibrationButton
@onready var music_player: AudioStreamPlayer = $MusicPlayer

const MENU_MUSIC_PATH := "res://assets/audio/menu_music.mp3"


func _ready() -> void:
	_enforce_display()
	_load_data()
	_apply_styles()
	_update_high_score_display()
	_update_button_labels()
	settings_panel.visible = false
	_play_music()
	_add_extra_buttons()
	_setup_control_options()
	_setup_cinematic()  # en son çağır — diğer nodelar hazır olsun


func _enforce_display() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_tree().root.content_scale_size = Vector2i(540, 960)


func _play_music() -> void:
	if ResourceLoader.exists(MENU_MUSIC_PATH):
		var stream := load(MENU_MUSIC_PATH) as AudioStreamMP3
		if stream:
			stream.loop = true
			music_player.stream = stream
			music_player.play()


func _process(delta: float) -> void:
	bg1.position.y += BG_SPEED * delta
	bg2.position.y += BG_SPEED * delta
	if bg1.position.y >= 960.0:
		bg1.position.y = bg2.position.y - 960.0
	if bg2.position.y >= 960.0:
		bg2.position.y = bg1.position.y - 960.0

	# Gemi sallanma animasyonu (menü close-up)
	if _menu_ship_node != null and not _cinematic_playing:
		_ship_bob_time += delta
		_menu_ship_node.position.y = _CIN_SHIP_Y + sin(_ship_bob_time * 1.30) * 5.0
		_menu_ship_node.rotation   = sin(_ship_bob_time * 0.85) * 0.028


func _load_data() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		sound_enabled = config.get_value("settings", "sound", true)
		vibration_enabled = config.get_value("settings", "vibration", true)
		high_score = config.get_value("game", "high_score", 0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), !sound_enabled)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("settings", "sound", sound_enabled)
	config.set_value("settings", "vibration", vibration_enabled)
	config.save(SAVE_PATH)


func _update_high_score_display() -> void:
	high_score_label.text = "En Yüksek: %dm" % high_score


func _update_button_labels() -> void:
	sound_btn.text = "Ses:  %s" % ("✓  Açık" if sound_enabled else "✗  Kapalı")
	vibration_btn.text = "Titreşim:  %s" % ("✓  Açık" if vibration_enabled else "✗  Kapalı")


func _make_btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_right = 14
	s.corner_radius_bottom_left = 14
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.border_color = border
	return s


func _apply_styles() -> void:
	var btn_normal  := _make_btn_style(Color(0.36, 0.22, 0.09), Color(0.60, 0.42, 0.18))
	var btn_hover   := _make_btn_style(Color(0.46, 0.30, 0.13), Color(0.70, 0.55, 0.25))
	var btn_pressed := _make_btn_style(Color(0.25, 0.15, 0.06), Color(0.50, 0.35, 0.12))

	var buttons: Array = [
		$CanvasLayer/Control/PlayButton,
		$CanvasLayer/Control/SettingsButton,
		$CanvasLayer/Control/SettingsPanel/VBoxContainer/SoundButton,
		$CanvasLayer/Control/SettingsPanel/VBoxContainer/VibrationButton,
		$CanvasLayer/Control/SettingsPanel/VBoxContainer/CloseButton,
	]
	for btn in buttons:
		btn.add_theme_stylebox_override("normal",  btn_normal.duplicate())
		btn.add_theme_stylebox_override("hover",   btn_hover.duplicate())
		btn.add_theme_stylebox_override("pressed", btn_pressed.duplicate())
		btn.add_theme_font_size_override("font_size", 26)
		btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.70))

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.10, 0.07, 0.96)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.20, 0.50, 0.30)
	$CanvasLayer/Control/SettingsPanel.add_theme_stylebox_override("panel", panel_style)


func _add_extra_buttons() -> void:
	var ctrl = $CanvasLayer/Control
	var pd   = get_node_or_null("/root/PlayerData")

	# Altın
	var gold_val: int = 0
	var gems_val: int = 0
	if pd:
		gold_val = pd.gold
		gems_val = pd.gems
	else:
		var cfg := ConfigFile.new()
		if cfg.load(SAVE_PATH) == OK:
			gold_val = cfg.get_value("economy", "gold", 0)
			gems_val = cfg.get_value("economy", "gems", 0)

	# Altın etiketi (sol)
	var gold_lbl := Label.new()
	gold_lbl.set_position(Vector2(40.0, 364.0))
	gold_lbl.set_size(Vector2(210.0, 44.0))
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_lbl.text = "⚓ %d" % gold_val
	gold_lbl.add_theme_font_size_override("font_size", 24)
	gold_lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.20))
	ctrl.add_child(gold_lbl)

	# Elmas etiketi (sağ)
	var gems_lbl := Label.new()
	gems_lbl.set_position(Vector2(290.0, 364.0))
	gems_lbl.set_size(Vector2(210.0, 44.0))
	gems_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gems_lbl.text = "💎 %d" % gems_val
	gems_lbl.add_theme_font_size_override("font_size", 24)
	gems_lbl.add_theme_color_override("font_color", Color(0.45, 0.92, 0.92))
	ctrl.add_child(gems_lbl)

	# Seçili gemi göstergesi
	var ship_name: String = "Balıkçı Teknesi"
	if pd:
		var def: Dictionary = pd.get_ship_def(pd.selected_ship)
		ship_name = def.get("name", "Balıkçı Teknesi")
	var ship_lbl := Label.new()
	ship_lbl.set_position(Vector2(40.0, 412.0))
	ship_lbl.set_size(Vector2(460.0, 34.0))
	ship_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ship_lbl.text = "Seçili Gemi: " + ship_name
	ship_lbl.add_theme_font_size_override("font_size", 17)
	ship_lbl.add_theme_color_override("font_color", Color(0.60, 0.80, 0.90))
	ctrl.add_child(ship_lbl)

	# Atölye butonu
	var workshop_btn := Button.new()
	workshop_btn.set_position(Vector2(145.0, 730.0))
	workshop_btn.set_size(Vector2(250.0, 75.0))
	workshop_btn.text = "⚒  ATÖLYE"
	_apply_btn_style(workshop_btn)
	workshop_btn.pressed.connect(_on_workshop_pressed)
	ctrl.add_child(workshop_btn)

	# Mağaza butonu
	var shop_btn := Button.new()
	shop_btn.set_position(Vector2(145.0, 820.0))
	shop_btn.set_size(Vector2(250.0, 75.0))
	shop_btn.text = "🛒  MAĞAZA"
	_apply_btn_style(shop_btn)
	shop_btn.pressed.connect(_on_shop_pressed)
	ctrl.add_child(shop_btn)

	# SettingsPanel'ı en üste taşı — dinamik node'ların arkasında kalmasın
	ctrl.move_child(settings_panel, ctrl.get_child_count() - 1)


func _apply_btn_style(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal",  _make_btn_style(Color(0.36, 0.22, 0.09), Color(0.60, 0.42, 0.18)))
	btn.add_theme_stylebox_override("hover",   _make_btn_style(Color(0.46, 0.30, 0.13), Color(0.70, 0.55, 0.25)))
	btn.add_theme_stylebox_override("pressed", _make_btn_style(Color(0.25, 0.15, 0.06), Color(0.50, 0.35, 0.12)))
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.70))


## Ayarlar paneline kontrol şeması seçici ekler.
func _setup_control_options() -> void:
	var vbox = $CanvasLayer/Control/SettingsPanel/VBoxContainer
	var close_btn = $CanvasLayer/Control/SettingsPanel/VBoxContainer/CloseButton
	var pd = get_node_or_null("/root/PlayerData")
	var current: String = pd.control_scheme if pd else "joystick"

	# Ayraç başlık
	var sep := Label.new()
	sep.text = "── Kontrol Şeması ──"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.add_theme_font_size_override("font_size", 16)
	sep.add_theme_color_override("font_color", Color(0.55, 0.80, 0.60))
	sep.custom_minimum_size = Vector2(0.0, 36.0)
	vbox.add_child(sep)
	vbox.move_child(sep, close_btn.get_index())

	# 3 kontrol butonu
	var options: Array = [
		["joystick", "🕹  Joystick"],
		["dpad",     "🎮  D-Pad"],
		["tilt",     "📱  Eğim (Jiroskop)"],
	]
	for opt in options:
		var scheme_id: String = opt[0]
		var label: String     = opt[1]
		var btn := Button.new()
		btn.text = label
		btn.custom_minimum_size = Vector2(0.0, 56.0)
		_apply_ctrl_btn_style(btn, scheme_id == current)
		btn.pressed.connect(_on_ctrl_scheme_pressed.bind(scheme_id))
		vbox.add_child(btn)
		vbox.move_child(btn, close_btn.get_index())
		_ctrl_btns[scheme_id] = btn


func _apply_ctrl_btn_style(btn: Button, active: bool) -> void:
	var bg:     Color = Color(0.10, 0.35, 0.18) if active else Color(0.22, 0.14, 0.06)
	var border: Color = Color(0.25, 0.75, 0.40) if active else Color(0.50, 0.36, 0.14)
	btn.add_theme_stylebox_override("normal",  _make_btn_style(bg, border))
	btn.add_theme_stylebox_override("hover",   _make_btn_style(bg.lightened(0.10), border))
	btn.add_theme_stylebox_override("pressed", _make_btn_style(bg.darkened(0.10),  border))
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.70))


func _on_ctrl_scheme_pressed(scheme: String) -> void:
	var pd = get_node_or_null("/root/PlayerData")
	if pd:
		pd.control_scheme = scheme
		pd.save_data()
	for id: String in _ctrl_btns:
		_apply_ctrl_btn_style(_ctrl_btns[id], id == scheme)


func _on_workshop_pressed() -> void:
	music_player.stop()
	get_tree().change_scene_to_file("res://scenes/workshop.tscn")


func _on_shop_pressed() -> void:
	music_player.stop()
	get_tree().change_scene_to_file("res://scenes/shop.tscn")


func _on_play_button_pressed() -> void:
	if _cinematic_playing:
		return
	_cinematic_playing = true
	music_player.stop()
	_play_cinematic()


func _play_cinematic() -> void:
	# 1. UI solar
	var ctrl_layer := $CanvasLayer/Control
	var ui_tw := create_tween()
	ui_tw.set_ease(Tween.EASE_IN)
	ui_tw.tween_property(ctrl_layer, "modulate:a", 0.0, 0.40)

	await get_tree().create_timer(0.18).timeout

	# 2. Kamera yavaşça çekilir (gemi küçülür, boğaz açılır)
	var cam_tw := create_tween()
	cam_tw.set_parallel(true)
	cam_tw.set_ease(Tween.EASE_IN_OUT)
	cam_tw.set_trans(Tween.TRANS_CUBIC)
	cam_tw.tween_property(_cam, "zoom",
		Vector2(1.0, 1.0), _CIN_DURATION)
	cam_tw.tween_property(_cam, "position",
		Vector2(_CIN_SHIP_X, _CIN_CAM_Y_END), _CIN_DURATION)
	await cam_tw.finished

	# 3. Siyaha geçiş
	var fade_tw := create_tween()
	fade_tw.set_ease(Tween.EASE_IN)
	fade_tw.tween_property(_fade_rect, "color:a", 1.0, 0.32)
	await fade_tw.finished

	get_tree().change_scene_to_file("res://scenes/game.tscn")


## ── Sinematik kurulum ──────────────────────────────────────────────────────

func _setup_cinematic() -> void:
	# Sol kıyı (boğaz duvarı)
	var left_wall := ColorRect.new()
	left_wall.position = Vector2(0.0, -300.0)
	left_wall.size     = Vector2(76.0, 1600.0)
	left_wall.color    = Color(0.12, 0.10, 0.07)
	add_child(left_wall)
	# Sol kıyı köpük çizgisi
	var lf := Line2D.new()
	lf.width = 3.5
	lf.default_color = Color(1.0, 1.0, 1.0, 0.26)
	lf.add_point(Vector2(76.0, -300.0))
	lf.add_point(Vector2(76.0, 1300.0))
	add_child(lf)

	# Sağ kıyı
	var right_wall := ColorRect.new()
	right_wall.position = Vector2(464.0, -300.0)
	right_wall.size     = Vector2(76.0, 1600.0)
	right_wall.color    = Color(0.12, 0.10, 0.07)
	add_child(right_wall)
	var rf := Line2D.new()
	rf.width = 3.5
	rf.default_color = Color(1.0, 1.0, 1.0, 0.26)
	rf.add_point(Vector2(464.0, -300.0))
	rf.add_point(Vector2(464.0, 1300.0))
	add_child(rf)

	# Su yüzeyine dağılmış ince dalgacıklar (close-up'ta belirgin görünür)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 12:
		var wy: float = 400.0 + float(i) * 55.0
		var wl := Line2D.new()
		wl.width = rng.randf_range(1.2, 2.6)
		wl.default_color = Color(1.0, 1.0, 1.0, rng.randf_range(0.05, 0.12))
		wl.add_point(Vector2(rng.randf_range(82.0, 200.0), wy))
		wl.add_point(Vector2(rng.randf_range(340.0, 458.0), wy))
		add_child(wl)

	# Seçili gemi sprite'ı
	_menu_ship_node = Node2D.new()
	_menu_ship_node.position = Vector2(_CIN_SHIP_X, _CIN_SHIP_Y)

	var pd := get_node_or_null("/root/PlayerData")
	var sel: String = "patrol"
	if pd != null and _MENU_SHIP_SPRITES.has(pd.selected_ship):
		sel = pd.selected_ship
	var tex_path: String = _MENU_SHIP_SPRITES.get(sel, _MENU_SHIP_SPRITES["patrol"])

	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		var spr := Sprite2D.new()
		spr.texture = tex
		var sf: float = 130.0 / float(tex.get_height())
		spr.scale = Vector2(sf, sf)
		_menu_ship_node.add_child(spr)

	# Kıç izi V-kolları
	_menu_ship_node.add_child(_make_menu_wake(Vector2(-14.0, 20.0), Vector2(-52.0, 90.0)))
	_menu_ship_node.add_child(_make_menu_wake(Vector2( 14.0, 20.0), Vector2( 52.0, 90.0)))

	add_child(_menu_ship_node)

	# Camera2D — menüde gemiye yakın başlar
	_cam = Camera2D.new()
	_cam.position = Vector2(_CIN_SHIP_X, _CIN_CAM_Y_START)
	_cam.zoom     = Vector2(_CIN_ZOOM_START, _CIN_ZOOM_START)
	add_child(_cam)
	_cam.make_current()

	# Siyah kararma overlay'i (en üstte)
	var fl := CanvasLayer.new()
	fl.layer = 50
	add_child(fl)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fl.add_child(_fade_rect)


func _make_menu_wake(from: Vector2, to: Vector2) -> Line2D:
	var l := Line2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.72, 0.90, 1.0, 0.52))
	grad.set_color(1, Color(0.72, 0.90, 1.0, 0.00))
	l.gradient = grad
	l.width = 3.8
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode   = Line2D.LINE_CAP_ROUND
	l.add_point(from)
	l.add_point(to)
	return l


func _on_settings_button_pressed() -> void:
	settings_panel.visible = true


func _on_close_button_pressed() -> void:
	settings_panel.visible = false


func _on_sound_button_pressed() -> void:
	sound_enabled = !sound_enabled
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), !sound_enabled)
	_update_button_labels()
	_save_settings()


func _on_vibration_button_pressed() -> void:
	vibration_enabled = !vibration_enabled
	_update_button_labels()
	_save_settings()
