extends CharacterBody2D

const EXPLOSION_SCENE = preload("res://scenes/explosion.tscn")

const SHIP_SPRITES: Dictionary = {
	"patrol":     "res://assets/sprites/PatrolBoat/ShipPatrolHull.png",
	"destroyer":  "res://assets/sprites/Destroyer/ShipDestroyerHull.png",
	"cruiser":    "res://assets/sprites/Cruiser/ShipCruiserHull.png",
	"battleship": "res://assets/sprites/Battleship/ShipBattleshipHull.png",
	"submarine":  "res://assets/sprites/Submarine/ShipSubMarineHull.png",
	"carrier":    "res://assets/sprites/Carrier/ShipCarrierHull.png",
	"rescue":     "res://assets/sprites/Rescue Ship/ShipRescue.png",
}

@export var move_speed: float = 400.0
@export var max_hp: int = 3

var hp: int = 3
var is_invincible: bool = false
var invincible_timer: float = 0.0
const INVINCIBLE_DURATION: float = 1.5

var has_shield: bool = false
var speed_boost_timer: float = 0.0
const SPEED_BOOST_DURATION: float = 4.0
const SPEED_BOOST_MULT: float = 1.6

var left_margin: float = 76.0
var right_margin: float = 464.0

var _forward_bonus: float = 0.0
var _lateral_bonus: float = 0.0

var _auto_fire_enabled: bool = false
var _auto_fire_timer: float  = 0.0
const _AUTO_FIRE_INTERVAL: float = 1.2
const _AUTO_BULLET_PATH: String  = "res://scenes/auto_bullet.tscn"

signal hp_changed(new_hp: int)
signal ship_destroyed()

@onready var trail: Line2D = $Trail
@onready var _ship_sprite: Sprite2D = $ShipSprite

var _trail_history: Array[Vector2] = []
const TRAIL_MAX: int = 22

# Kıç izi
var _wake_l: Line2D
var _wake_r: Line2D
var _wake_hist_l: Array[Vector2] = []
var _wake_hist_r: Array[Vector2] = []
const _WAKE_MAX: int = 16

# Kalkan çizimi
var _shield_time: float = 0.0

# Sabit gemi kıç dalgası
var _idle_wake_time: float = 0.0
const _IDLE_SPEED_THRESH: float = 8.0
const _IDLE_WAKE_PERIOD: float  = 1.5
const _IDLE_WAKE_STERN_Y: float = 30.0
const _IDLE_WAKE_MAX_RX: float  = 36.0
const _IDLE_WAKE_RINGS: int     = 3

# Banking'e dahil edilecek dinamik görsel nodelar (battleship detayları)
var _extra_visual_nodes: Array = []

var _hit_sound: AudioStreamWAV = null


func _ready() -> void:
	add_to_group("player")
	_apply_upgrades()
	hp = max_hp
	_setup_sounds()
	_setup_wake()


func _physics_process(delta: float) -> void:
	if speed_boost_timer > 0.0:
		speed_boost_timer -= delta
		if speed_boost_timer <= 0.0:
			_refresh_tint()
	_handle_movement()
	_handle_banking(delta)
	_handle_invincibility(delta)
	_update_trail()
	_update_wake()
	if _auto_fire_enabled:
		_handle_auto_fire(delta)
	# Kalkan animasyonu
	if has_shield:
		_shield_time += delta
	elif _shield_time > 0.0:
		_shield_time = 0.0

	# Sabit gemi kıç dalgası
	if velocity.length() < _IDLE_SPEED_THRESH:
		_idle_wake_time += delta
	else:
		_idle_wake_time = 0.0

	if has_shield or _shield_time > 0.0 or _idle_wake_time > 0.0:
		queue_redraw()


func _draw() -> void:
	# ── Kalkan ──────────────────────────────────────────────────
	if has_shield:
		var pulse := 0.88 + 0.12 * sin(_shield_time * 5.0)
		var rx: float = 40.0 * pulse
		var ry: float = 92.0 * pulse
		var pts := PackedVector2Array()
		for i in 37:
			var a := float(i) / 36.0 * TAU
			pts.append(Vector2(cos(a) * rx, sin(a) * ry))
		draw_polyline(pts, Color(0.25, 0.65, 1.0, 0.22 + 0.08 * sin(_shield_time * 4.0)), 10.0, true)
		draw_polyline(pts, Color(0.50, 0.82, 1.0, 0.55), 3.0, true)
		draw_polyline(pts, Color(0.85, 0.96, 1.0, 0.80), 1.2, true)

	# ── Sabit kıç dalgası ────────────────────────────────────────
	if _idle_wake_time > 0.0:
		for ring in _IDLE_WAKE_RINGS:
			var t_offset: float = float(ring) / float(_IDLE_WAKE_RINGS) * _IDLE_WAKE_PERIOD
			var t: float        = fmod(_idle_wake_time + t_offset, _IDLE_WAKE_PERIOD) / _IDLE_WAKE_PERIOD
			var rx: float       = lerp(0.0, _IDLE_WAKE_MAX_RX, t)
			var ry: float       = rx * 0.36
			var alpha: float    = (1.0 - t) * 0.55
			if alpha < 0.02:
				continue
			var pts2 := PackedVector2Array()
			for i in 25:
				var a: float = float(i) / 24.0 * TAU
				pts2.append(Vector2(cos(a) * rx, _IDLE_WAKE_STERN_Y + sin(a) * ry))
			draw_polyline(pts2, Color(0.65, 0.90, 1.0, alpha), 1.8)


func _handle_movement() -> void:
	var direction_x: float = 0.0
	var direction_y: float = 0.0
	if Input.is_action_pressed("move_left"):
		direction_x = -1.0
	elif Input.is_action_pressed("move_right"):
		direction_x = 1.0
	if Input.is_action_pressed("move_up"):
		direction_y = -1.0
	elif Input.is_action_pressed("move_down"):
		direction_y = 1.0
	var boost := SPEED_BOOST_MULT if speed_boost_timer > 0.0 else 1.0
	velocity.x = direction_x * (move_speed + _lateral_bonus) * boost
	velocity.y = direction_y * (move_speed * 0.6 + _forward_bonus) * boost
	move_and_slide()
	_clamp_position()


func _clamp_position() -> void:
	var screen := get_viewport().get_visible_rect().size
	position.x = clamp(position.x, left_margin, right_margin)
	position.y = clamp(position.y, 100.0, screen.y - 100.0)


func _handle_invincibility(delta: float) -> void:
	if is_invincible:
		invincible_timer -= delta
		var alpha := 0.3 if fmod(invincible_timer, 0.2) > 0.1 else 1.0
		if _ship_sprite.visible:
			_ship_sprite.modulate.a = alpha
		else:
			$Sprite2D.modulate.a = alpha
		if invincible_timer <= 0:
			is_invincible = false
			if _ship_sprite.visible:
				_ship_sprite.modulate.a = 1.0
			else:
				$Sprite2D.modulate.a = 1.0


func _update_trail() -> void:
	_trail_history.push_front(global_position + Vector2(0.0, 22.0))
	if _trail_history.size() > TRAIL_MAX:
		_trail_history.pop_back()
	var pts := PackedVector2Array()
	for pt: Vector2 in _trail_history:
		pts.push_back(pt - global_position)
	trail.points = pts


func _setup_sounds() -> void:
	_hit_sound = _build_hit_sound()
	_start_motor()


func _build_hit_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var n := int(22050 * 0.22)
	var data := PackedByteArray()
	for i in n:
		var t := float(i) / 22050.0
		var freq := 280.0 * exp(-t * 7.0) + 90.0
		var env := exp(-t * 9.0)
		var val := int(sin(TAU * freq * t) * env * 22000.0)
		val = clamp(val, -32768, 32767)
		data.append(val & 0xFF)
		data.append((val >> 8) & 0xFF)
	stream.data = data
	return stream


func _start_motor() -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	var n := 2205
	var data := PackedByteArray()
	for i in n:
		var t := float(i) / 22050.0
		var val := int(
			(sin(TAU * 82.0 * t) * 0.45 +
			 sin(TAU * 164.0 * t) * 0.20 +
			 sin(TAU * 246.0 * t) * 0.10) * 7000.0
		)
		val = clamp(val, -32768, 32767)
		data.append(val & 0xFF)
		data.append((val >> 8) & 0xFF)
	stream.data = data
	var player: AudioStreamPlayer2D = $AudioStreamPlayer2D
	player.stream = stream
	player.volume_db = -18.0
	player.play()


func take_damage() -> void:
	if is_invincible:
		return
	_spawn_hit_explosion()
	if has_shield:
		has_shield = false
		_play_hit_sound()
		is_invincible = true
		invincible_timer = INVINCIBLE_DURATION
		_refresh_tint()
		queue_redraw()
		return
	hp -= 1
	_play_hit_sound()
	is_invincible = true
	invincible_timer = INVINCIBLE_DURATION
	emit_signal("hp_changed", hp)
	if hp <= 0:
		emit_signal("ship_destroyed")
		queue_free()


func _spawn_hit_explosion() -> void:
	var exp := EXPLOSION_SCENE.instantiate()
	exp.global_position = global_position
	get_parent().add_child(exp)


func apply_powerup(type: int) -> void:
	match type:
		0: # HEAL
			hp = min(hp + 1, max_hp)
			emit_signal("hp_changed", hp)
		1: # SHIELD
			has_shield = true
			_refresh_tint()
		2: # SPEED
			speed_boost_timer = SPEED_BOOST_DURATION
			_refresh_tint()


func _refresh_tint() -> void:
	var visual: Node2D = _ship_sprite if _ship_sprite.visible else $Sprite2D
	if has_shield:
		visual.modulate = Color(0.70, 0.88, 1.00, visual.modulate.a)
	elif speed_boost_timer > 0.0:
		visual.modulate = Color(1.00, 0.90, 0.20, visual.modulate.a)
	else:
		visual.modulate = Color(1.00, 1.00, 1.00, visual.modulate.a)


func _apply_upgrades() -> void:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return
	_forward_bonus     = pd.upgrade_speed   * 60.0
	_lateral_bonus     = pd.upgrade_agility * 50.0
	max_hp             = max_hp + pd.upgrade_armor
	_auto_fire_enabled = (pd.selected_ship == "battleship")
	_apply_ship_sprite()
	if pd.selected_ship == "battleship" and not _ship_sprite.visible:
		_configure_battleship_visuals()


func _apply_ship_sprite() -> void:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return
	var ship_id: String = pd.selected_ship
	if not SHIP_SPRITES.has(ship_id):
		return
	var path: String = SHIP_SPRITES[ship_id]
	if not ResourceLoader.exists(path):
		return
	var tex := load(path) as Texture2D
	if tex == null:
		return
	_ship_sprite.texture = tex
	# Sprite yüksekliğini geminin boyutuna göre normalize et
	var target_height: float = 130.0
	var scale_factor: float = target_height / float(tex.get_height())
	_ship_sprite.scale = Vector2(scale_factor, scale_factor)
	_ship_sprite.visible = true
	# Polygon nodeları gizle
	$Sprite2D.visible        = false
	$CargoHold.visible       = false
	$WaterlineStripe.visible = false
	$Bridge.visible          = false
	$BridgeWindow.visible    = false


func _handle_auto_fire(delta: float) -> void:
	_auto_fire_timer -= delta
	if _auto_fire_timer > 0.0:
		return
	_auto_fire_timer = _AUTO_FIRE_INTERVAL
	if not ResourceLoader.exists(_AUTO_BULLET_PATH):
		return
	var scene := load(_AUTO_BULLET_PATH) as PackedScene
	if scene == null:
		return
	var bullet := scene.instantiate()
	bullet.global_position = global_position
	bullet.target = _find_nearest_enemy()
	get_parent().add_child(bullet)


func _setup_wake() -> void:
	_wake_l = _make_wake_line()
	_wake_r = _make_wake_line()
	add_child(_wake_l)
	add_child(_wake_r)


func _make_wake_line() -> Line2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 0.52))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.00))
	var l := Line2D.new()
	l.gradient = grad
	l.width = 3.2
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode   = Line2D.LINE_CAP_ROUND
	return l


func _update_wake() -> void:
	_wake_hist_l.push_front(global_position + Vector2(-15.0, 20.0))
	_wake_hist_r.push_front(global_position + Vector2( 15.0, 20.0))
	if _wake_hist_l.size() > _WAKE_MAX:
		_wake_hist_l.pop_back()
		_wake_hist_r.pop_back()
	var pts_l := PackedVector2Array()
	var pts_r := PackedVector2Array()
	for i in _wake_hist_l.size():
		var spread := float(i) * 1.6
		pts_l.append(_wake_hist_l[i] - global_position + Vector2(-spread, 0.0))
		pts_r.append(_wake_hist_r[i] - global_position + Vector2( spread, 0.0))
	_wake_l.points = pts_l
	_wake_r.points = pts_r


func _handle_banking(delta: float) -> void:
	var dir_x := Input.get_axis("move_left", "move_right")
	if _ship_sprite.visible:
		_ship_sprite.rotation = lerp(_ship_sprite.rotation, dir_x * 0.13, 12.0 * delta)
	else:
		var r: float = lerp($Sprite2D.rotation, dir_x * 0.13, 12.0 * delta)
		$Sprite2D.rotation        = r
		$CargoHold.rotation       = r
		$WaterlineStripe.rotation = r
		$Bridge.rotation          = r
		$BridgeWindow.rotation    = r
	for node in _extra_visual_nodes:
		if is_instance_valid(node):
			var pivot := _ship_sprite if _ship_sprite.visible else $Sprite2D
			(node as Node2D).rotation = pivot.rotation


func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("targetable")
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	return nearest


func _play_hit_sound() -> void:
	if _hit_sound == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = _hit_sound
	player.volume_db = -5.0
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


# ─── Savaş Gemisi Görseli ────────────────────────────────────────────────────

func _configure_battleship_visuals() -> void:
	# Hull → battleship gri
	$Sprite2D.color = Color(0.19, 0.21, 0.24)

	# Kargo bölümü → ön güverte zırh plakası
	$CargoHold.color   = Color(0.16, 0.18, 0.20)
	$CargoHold.polygon = PackedVector2Array([-13, -72, 13, -72, 13, -8, -13, -8])

	# Su hattı şeridi → ince siyah keel
	$WaterlineStripe.color   = Color(0.09, 0.09, 0.11)
	$WaterlineStripe.polygon = PackedVector2Array([-8, 2, 8, 2, 8, 6, -8, 6])

	# Köprü → üst yapı (superstructure)
	$Bridge.color   = Color(0.23, 0.25, 0.28)
	$Bridge.polygon = PackedVector2Array([-11, 10, 11, 10, 11, 42, -11, 42])

	# Köprü penceresi → muharebe bilgi merkezi camı
	$BridgeWindow.color   = Color(0.18, 0.48, 0.78, 0.88)
	$BridgeWindow.polygon = PackedVector2Array([-7, 14, 7, 14, 7, 23, -7, 23])

	# Ön top kulesi (A turret)
	_add_gun_turret(Vector2(0.0, -54.0), true)
	# Arka top kulesi (Y turret)
	_add_gun_turret(Vector2(0.0,  54.0), false)
	# Baca
	_add_funnel(Vector2(0.0, 30.0))
	# Radar direği
	_add_radar_mast(Vector2(0.0, 8.0))
	# Yan silah platformları
	_add_side_mount(Vector2(-13.0, -18.0))
	_add_side_mount(Vector2( 13.0, -18.0))
	# Kıç anten
	_add_antenna(Vector2(0.0, 68.0))


func _add_gun_turret(pos: Vector2, forward: bool) -> void:
	# Yuvarlak kule tabanı
	var base := Polygon2D.new()
	base.position = pos
	base.color    = Color(0.22, 0.24, 0.27)
	var base_pts := PackedVector2Array()
	for i in 16:
		var a := float(i) / 16.0 * TAU
		base_pts.append(Vector2(cos(a) * 10.0, sin(a) * 7.5))
	base.polygon = base_pts
	base.z_index  = 2
	add_child(base)
	_extra_visual_nodes.append(base)

	# İkiz namlu
	var barrel_offset: float = -11.0 if forward else 11.0
	for ox in [-3.2, 3.2]:
		var barrel := Polygon2D.new()
		barrel.position = pos + Vector2(ox, barrel_offset)
		if not forward:
			barrel.rotation = PI
		barrel.color   = Color(0.12, 0.13, 0.15)
		barrel.polygon = PackedVector2Array([
			Vector2(-1.8, 0.0), Vector2(1.8, 0.0),
			Vector2(1.5, -15.0), Vector2(-1.5, -15.0)
		])
		barrel.z_index = 3
		add_child(barrel)
		_extra_visual_nodes.append(barrel)

	# Kule üst detay
	var top := Polygon2D.new()
	top.position = pos
	top.color    = Color(0.30, 0.32, 0.36)
	top.polygon  = PackedVector2Array([Vector2(-4, -3), Vector2(4, -3), Vector2(4, 3), Vector2(-4, 3)])
	top.z_index  = 4
	add_child(top)
	_extra_visual_nodes.append(top)


func _add_funnel(pos: Vector2) -> void:
	var body := Polygon2D.new()
	body.position = pos
	body.color    = Color(0.14, 0.14, 0.16)
	body.polygon  = PackedVector2Array([
		Vector2(-5.5, -9.0), Vector2(5.5, -9.0),
		Vector2(4.5,  9.0),  Vector2(-4.5, 9.0)
	])
	body.z_index = 2
	add_child(body)
	_extra_visual_nodes.append(body)

	var rim := Polygon2D.new()
	rim.position = pos + Vector2(0.0, -9.0)
	rim.color    = Color(0.08, 0.08, 0.09)
	rim.polygon  = PackedVector2Array([
		Vector2(-6.5, -2.5), Vector2(6.5, -2.5),
		Vector2(5.5,  2.5),  Vector2(-5.5, 2.5)
	])
	rim.z_index = 3
	add_child(rim)
	_extra_visual_nodes.append(rim)


func _add_radar_mast(pos: Vector2) -> void:
	var mast := Polygon2D.new()
	mast.position = pos
	mast.color    = Color(0.52, 0.56, 0.60)
	mast.polygon  = PackedVector2Array([
		Vector2(-1.5, -14.0), Vector2(1.5, -14.0),
		Vector2(1.5,  14.0),  Vector2(-1.5, 14.0)
	])
	mast.z_index = 5
	add_child(mast)
	_extra_visual_nodes.append(mast)

	var dish_pts := PackedVector2Array()
	for i in 14:
		var a := float(i) / 14.0 * TAU
		dish_pts.append(Vector2(cos(a) * 7.0, sin(a) * 4.0))
	var dish := Polygon2D.new()
	dish.position = pos + Vector2(0.0, -16.0)
	dish.color    = Color(0.70, 0.74, 0.80)
	dish.polygon  = dish_pts
	dish.z_index  = 6
	add_child(dish)
	_extra_visual_nodes.append(dish)


func _add_side_mount(pos: Vector2) -> void:
	var mount := Polygon2D.new()
	mount.position = pos
	mount.color    = Color(0.20, 0.22, 0.25)
	mount.polygon  = PackedVector2Array([
		Vector2(-3.5, -5.0), Vector2(3.5, -5.0),
		Vector2(3.5,  5.0),  Vector2(-3.5, 5.0)
	])
	mount.z_index = 2
	add_child(mount)
	_extra_visual_nodes.append(mount)


func _add_antenna(pos: Vector2) -> void:
	var ant := Polygon2D.new()
	ant.position = pos
	ant.color    = Color(0.60, 0.62, 0.65)
	ant.polygon  = PackedVector2Array([
		Vector2(-1.0, -10.0), Vector2(1.0, -10.0),
		Vector2(1.0,  10.0),  Vector2(-1.0, 10.0)
	])
	ant.z_index = 2
	add_child(ant)
	_extra_visual_nodes.append(ant)
