extends CanvasLayer

## Atölye sahnesi — UI tamamen kodla oluşturulur.

var _gold_label: Label
var _upgrade_rows: Array = []


func _ready() -> void:
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.10, 0.20, 1.0)
	add_child(bg)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var title := Label.new()
	title.set_position(Vector2(0.0, 60.0))
	title.set_size(Vector2(540.0, 72.0))
	title.text = "⚒  ATÖLYE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.30, 0.85, 0.55))
	root.add_child(title)

	_gold_label = Label.new()
	_gold_label.set_position(Vector2(0.0, 148.0))
	_gold_label.set_size(Vector2(540.0, 44.0))
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 26)
	_gold_label.add_theme_color_override("font_color", Color(0.95, 0.80, 0.20))
	root.add_child(_gold_label)

	var defs := [
		{"key": "speed",   "icon": "⚡", "name": "HIZ",      "desc": "İleri / geri hareket hızı"},
		{"key": "agility", "icon": "↔",  "name": "ÇEVİKLİK", "desc": "Sağ / sol hareket hızı"},
		{"key": "armor",   "icon": "⬡",  "name": "ZIRH",     "desc": "Oyuna +1 ekstra can ile başla"},
	]
	for i in defs.size():
		_upgrade_rows.append(_build_upgrade_row(root, defs[i], 230.0 + i * 155.0))

	var back := _make_button("← GERİ")
	back.set_position(Vector2(145.0, 720.0))
	back.set_size(Vector2(250.0, 70.0))
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	root.add_child(back)


func _build_upgrade_row(root: Control, data: Dictionary, y: float) -> Dictionary:
	var panel := Panel.new()
	panel.set_position(Vector2(40.0, y))
	panel.set_size(Vector2(460.0, 130.0))
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.08, 0.18, 0.28, 0.95)
	style.corner_radius_top_left     = 14
	style.corner_radius_top_right    = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left  = 14
	style.border_width_left          = 2
	style.border_width_top           = 2
	style.border_width_right         = 2
	style.border_width_bottom        = 2
	style.border_color               = Color(0.20, 0.45, 0.65)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var name_lbl := Label.new()
	name_lbl.set_position(Vector2(16.0, 8.0))
	name_lbl.set_size(Vector2(220.0, 38.0))
	name_lbl.text = data["icon"] + "  " + data["name"]
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(0.90, 0.90, 1.00))
	panel.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.set_position(Vector2(16.0, 50.0))
	desc_lbl.set_size(Vector2(240.0, 30.0))
	desc_lbl.text = data["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", Color(0.60, 0.78, 0.72))
	panel.add_child(desc_lbl)

	var level_lbl := Label.new()
	level_lbl.set_position(Vector2(16.0, 88.0))
	level_lbl.set_size(Vector2(200.0, 30.0))
	level_lbl.add_theme_font_size_override("font_size", 22)
	level_lbl.add_theme_color_override("font_color", Color(1.00, 0.85, 0.20))
	panel.add_child(level_lbl)

	var buy_btn := _make_button("")
	buy_btn.set_position(Vector2(288.0, 26.0))
	buy_btn.set_size(Vector2(155.0, 72.0))
	buy_btn.pressed.connect(_on_buy_pressed.bind(data["key"]))
	panel.add_child(buy_btn)

	return {"key": data["key"], "level_lbl": level_lbl, "buy_btn": buy_btn}


func _make_button(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.20, 0.38, 0.18), Color(0.35, 0.65, 0.30)))
	btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.30, 0.50, 0.25), Color(0.45, 0.72, 0.38)))
	btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.12, 0.26, 0.10), Color(0.25, 0.50, 0.22)))
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.80))
	return btn


func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color                   = bg
	s.corner_radius_top_left     = 10
	s.corner_radius_top_right    = 10
	s.corner_radius_bottom_right = 10
	s.corner_radius_bottom_left  = 10
	s.border_width_left          = 2
	s.border_width_top           = 2
	s.border_width_right         = 2
	s.border_width_bottom        = 2
	s.border_color               = border
	return s


func _refresh() -> void:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return
	_gold_label.text = "⚓ Altın: %d" % pd.gold
	for row in _upgrade_rows:
		var key: String = row["key"]
		var level: int  = pd.get_upgrade_level(key)
		row["level_lbl"].text = "★".repeat(level) + "☆".repeat(pd.MAX_UPGRADE_LEVEL - level)
		if level >= pd.MAX_UPGRADE_LEVEL:
			row["buy_btn"].text     = "MAX"
			row["buy_btn"].disabled = true
		else:
			var cost: int           = pd.get_upgrade_cost(key)
			row["buy_btn"].text     = "%d ⚓" % cost
			row["buy_btn"].disabled = pd.gold < cost


func _on_buy_pressed(key: String) -> void:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return
	if pd.buy_upgrade(key):
		_refresh()
		_play_buy_sound()


func _play_buy_sound() -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	var stream := AudioStreamWAV.new()
	stream.format   = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var n := int(22050 * 0.18)
	var data := PackedByteArray()
	for i in n:
		var t   := float(i) / 22050.0
		var env := exp(-t * 5.0)
		var val := int((sin(TAU * 523.0 * t) * 0.6 + sin(TAU * 659.0 * t) * 0.4) * env * 18000.0)
		val = clamp(val, -32768, 32767)
		data.append(val & 0xFF)
		data.append((val >> 8) & 0xFF)
	stream.data      = data
	player.stream    = stream
	player.volume_db = -8.0
	player.play()
	player.finished.connect(player.queue_free)
