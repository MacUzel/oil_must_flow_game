extends CanvasLayer

## Mağaza sahnesi — gemi satın alma ve seçim ekranı.
## Mobil uyumlu ScrollContainer layout, gold + gem fiyat desteği.

const SHIP_SPRITES: Dictionary = {
	"patrol":     "res://assets/sprites/PatrolBoat/ShipPatrolHull.png",
	"destroyer":  "res://assets/sprites/Destroyer/ShipDestroyerHull.png",
	"cruiser":    "res://assets/sprites/Cruiser/ShipCruiserHull.png",
	"battleship": "res://assets/sprites/Battleship/ShipBattleshipHull.png",
	"submarine":  "res://assets/sprites/Submarine/ShipSubMarineHull.png",
	"carrier":    "res://assets/sprites/Carrier/ShipCarrierHull.png",
	"rescue":     "res://assets/sprites/Rescue Ship/ShipRescue.png",
}

const CARD_W: float  = 220.0
const CARD_H: float  = 308.0
const COLS: int      = 2
const GAP_X: float   = 18.0
const GAP_Y: float   = 18.0
const GRID_PAD: float = 12.0
const HEADER_H: float = 164.0
const FOOTER_H: float = 72.0

var _gold_label: Label
var _gems_label: Label
var _status_label: Label
var _card_list: Array = []


func _ready() -> void:
	_build_ui()
	_refresh()


func _build_ui() -> void:
	# Arka plan
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.10, 0.20, 1.0)
	add_child(bg)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# ── Başlık ──────────────────────────────────────────────────
	var title := Label.new()
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top  = 18.0
	title.offset_bottom = 64.0
	title.text = "⚓  GEMİ SEÇİMİ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.30, 0.85, 0.55))
	root.add_child(title)

	# ── Para göstergesi (altın | elmas) ─────────────────────────
	var currency_row := HBoxContainer.new()
	currency_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	currency_row.offset_top    = 72.0
	currency_row.offset_bottom = 110.0
	currency_row.offset_left   = 20.0
	currency_row.offset_right  = -20.0
	currency_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(currency_row)

	_gold_label = Label.new()
	_gold_label.custom_minimum_size = Vector2(220.0, 0.0)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 22)
	_gold_label.add_theme_color_override("font_color", Color(0.95, 0.80, 0.20))
	currency_row.add_child(_gold_label)

	var divider := Label.new()
	divider.text = "│"
	divider.add_theme_font_size_override("font_size", 22)
	divider.add_theme_color_override("font_color", Color(0.30, 0.40, 0.55))
	currency_row.add_child(divider)

	_gems_label = Label.new()
	_gems_label.custom_minimum_size = Vector2(220.0, 0.0)
	_gems_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gems_label.add_theme_font_size_override("font_size", 22)
	_gems_label.add_theme_color_override("font_color", Color(0.45, 0.92, 0.92))
	currency_row.add_child(_gems_label)

	# ── Durum mesajı ────────────────────────────────────────────
	_status_label = Label.new()
	_status_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status_label.offset_top    = 118.0
	_status_label.offset_bottom = 144.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color(0.60, 0.95, 0.60))
	root.add_child(_status_label)

	# ── Kart grid'i için boyutları hesapla ──────────────────────
	var pd := get_node_or_null("/root/PlayerData")
	var ship_count: int = pd.SHIP_DEFS.size() if pd != null else 8
	var rows: int = ceili(float(ship_count) / float(COLS))
	var grid_w: float = COLS * CARD_W + (COLS - 1) * GAP_X + GRID_PAD * 2
	var grid_h: float = rows * CARD_H + (rows - 1) * GAP_Y + GRID_PAD * 2

	# Kartları yatay ortala
	var screen_w: float = 540.0
	var total_cards_w: float = COLS * CARD_W + (COLS - 1) * GAP_X
	var x_start: float = (screen_w - total_cards_w) / 2.0

	# ── ScrollContainer ─────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.anchor_left   = 0.0
	scroll.anchor_top    = 0.0
	scroll.anchor_right  = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_top    = HEADER_H
	scroll.offset_bottom = -FOOTER_H
	scroll.offset_left   = 0.0
	scroll.offset_right  = 0.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var grid_holder := Control.new()
	grid_holder.custom_minimum_size = Vector2(screen_w, grid_h)
	scroll.add_child(grid_holder)

	if pd != null:
		for i in pd.SHIP_DEFS.size():
			var def: Dictionary = pd.SHIP_DEFS[i]
			var col: int = i % COLS
			var row: int = i / COLS
			var x: float = x_start + col * (CARD_W + GAP_X)
			var y: float = GRID_PAD + row * (CARD_H + GAP_Y)
			_card_list.append(_build_card(grid_holder, def, x, y))

	# ── Geri butonu (altta sabit) ────────────────────────────────
	var back := _make_button("← GERİ", Color(0.36, 0.22, 0.09), Color(0.60, 0.42, 0.18))
	back.anchor_left   = 0.0
	back.anchor_right  = 1.0
	back.anchor_top    = 1.0
	back.anchor_bottom = 1.0
	back.offset_left   = 20.0
	back.offset_right  = -20.0
	back.offset_top    = -FOOTER_H + 6.0
	back.offset_bottom = -6.0
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	root.add_child(back)


func _build_card(parent: Control, def: Dictionary, x: float, y: float) -> Dictionary:
	var panel := Panel.new()
	panel.set_position(Vector2(x, y))
	panel.set_size(Vector2(CARD_W, CARD_H))
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.08, 0.16, 0.28, 0.95)
	style.corner_radius_top_left     = 14
	style.corner_radius_top_right    = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left  = 14
	style.border_width_left          = 2
	style.border_width_top           = 2
	style.border_width_right         = 2
	style.border_width_bottom        = 2
	style.border_color               = Color(0.22, 0.38, 0.58)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var ship_id: String = def["id"]

	# Gemi görseli
	if SHIP_SPRITES.has(ship_id) and ResourceLoader.exists(SHIP_SPRITES[ship_id]):
		var tex_rect := TextureRect.new()
		tex_rect.set_position(Vector2(28.0, 8.0))
		tex_rect.set_size(Vector2(CARD_W - 56.0, 130.0))
		tex_rect.texture = load(SHIP_SPRITES[ship_id]) as Texture2D
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(tex_rect)
	else:
		var icon_lbl := Label.new()
		icon_lbl.set_position(Vector2(0.0, 18.0))
		icon_lbl.set_size(Vector2(CARD_W, 90.0))
		icon_lbl.text = def.get("icon", "⛵")
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 64)
		panel.add_child(icon_lbl)

	# Gemi adı
	var name_lbl := Label.new()
	name_lbl.set_position(Vector2(6.0, 142.0))
	name_lbl.set_size(Vector2(CARD_W - 12.0, 30.0))
	name_lbl.text = def["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	panel.add_child(name_lbl)

	# Altın fiyat etiketi
	var price_lbl := Label.new()
	price_lbl.set_position(Vector2(6.0, 174.0))
	price_lbl.set_size(Vector2(CARD_W - 12.0, 24.0))
	if def["price"] == 0:
		price_lbl.text = "Ücretsiz"
		price_lbl.add_theme_color_override("font_color", Color(0.50, 0.90, 0.50))
	else:
		price_lbl.text = "%d ⚓ Altın" % def["price"]
		price_lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.20))
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.add_theme_font_size_override("font_size", 15)
	panel.add_child(price_lbl)

	# Altın satın al butonu
	var gold_btn := _make_button("", Color(0.18, 0.35, 0.18), Color(0.32, 0.58, 0.28))
	gold_btn.set_position(Vector2(10.0, 200.0))
	gold_btn.set_size(Vector2(CARD_W - 20.0, 46.0))
	gold_btn.pressed.connect(_on_gold_pressed.bind(def["id"]))
	panel.add_child(gold_btn)

	# Elmas fiyat butonu (IAP placeholder)
	var gem_price: int = def.get("gem_price", 0)
	var gem_btn := _make_button("", Color(0.10, 0.20, 0.36), Color(0.20, 0.48, 0.72))
	gem_btn.set_position(Vector2(10.0, 252.0))
	gem_btn.set_size(Vector2(CARD_W - 20.0, 44.0))
	gem_btn.add_theme_font_size_override("font_size", 14)
	if gem_price > 0:
		gem_btn.text = "💎 %d Elmas — Yakında!" % gem_price
	else:
		gem_btn.text = "💎 Ücretsiz"
	gem_btn.disabled = true
	panel.add_child(gem_btn)

	return {
		"id":        def["id"],
		"panel":     panel,
		"price_lbl": price_lbl,
		"gold_btn":  gold_btn,
		"gem_btn":   gem_btn,
		"name_lbl":  name_lbl,
		"style":     style,
	}


func _refresh() -> void:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return
	_gold_label.text = "⚓ %d Altın" % pd.gold
	_gems_label.text = "💎 %d Elmas" % pd.gems
	_status_label.text = ""

	for card in _card_list:
		var ship_id: String  = card["id"]
		var owned: bool      = ship_id in pd.unlocked_ships
		var selected: bool   = pd.selected_ship == ship_id
		var def: Dictionary  = pd.get_ship_def(ship_id)
		var price: int       = def.get("price", 0)
		var can_buy: bool    = pd.gold >= price and not owned and price > 0

		var gold_btn: Button    = card["gold_btn"]
		var gem_btn: Button     = card["gem_btn"]
		var style: StyleBoxFlat = card["style"]

		if selected:
			gold_btn.text     = "✔ SEÇİLİ"
			gold_btn.disabled = true
			gem_btn.visible   = false
			style.border_color = Color(0.20, 0.75, 0.40)
			style.border_width_left   = 3
			style.border_width_top    = 3
			style.border_width_right  = 3
			style.border_width_bottom = 3
		elif owned:
			gold_btn.text     = "SEÇ"
			gold_btn.disabled = false
			gem_btn.visible   = false
			style.border_color = Color(0.22, 0.38, 0.58)
			style.border_width_left   = 2
			style.border_width_top    = 2
			style.border_width_right  = 2
			style.border_width_bottom = 2
		elif price == 0:
			gold_btn.text     = "SEÇ"
			gold_btn.disabled = false
			gem_btn.visible   = false
		elif can_buy:
			gold_btn.text     = "⚓ SATIN AL"
			gold_btn.disabled = false
			gem_btn.visible   = true
			style.border_color = Color(0.22, 0.38, 0.58)
			style.border_width_left   = 2
			style.border_width_top    = 2
			style.border_width_right  = 2
			style.border_width_bottom = 2
		else:
			gold_btn.text     = "🔒 %d ⚓" % price
			gold_btn.disabled = true
			gem_btn.visible   = true
			style.border_color = Color(0.22, 0.38, 0.58)
			style.border_width_left   = 2
			style.border_width_top    = 2
			style.border_width_right  = 2
			style.border_width_bottom = 2

		card["panel"].add_theme_stylebox_override("panel", style)


func _on_gold_pressed(ship_id: String) -> void:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return

	var def: Dictionary = pd.get_ship_def(ship_id)

	if ship_id in pd.unlocked_ships:
		pd.select_ship(ship_id)
		_set_status(def.get("name", "") + " seçildi!", false)
	elif def.get("price", 0) == 0:
		pd.unlock_ship(ship_id)
		pd.select_ship(ship_id)
		_set_status(def.get("name", "") + " seçildi!", false)
	elif pd.buy_ship(ship_id):
		pd.select_ship(ship_id)
		_set_status(def.get("name", "") + " satın alındı ve seçildi!", false)
	else:
		_set_status("Yeterli altın yok!", true)

	_refresh()


func _set_status(msg: String, is_error: bool) -> void:
	_status_label.text = msg
	if is_error:
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.40, 0.40))
	else:
		_status_label.add_theme_color_override("font_color", Color(0.60, 0.95, 0.60))


func _make_button(txt: String, bg: Color, border: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
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
	btn.add_theme_stylebox_override("normal", s)
	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color = bg.lightened(0.15)
	btn.add_theme_stylebox_override("hover", sh)
	var sp := s.duplicate() as StyleBoxFlat
	sp.bg_color = bg.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.95, 0.92, 0.80))
	return btn
