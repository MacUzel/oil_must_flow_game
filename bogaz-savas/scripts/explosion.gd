extends Node2D

var _time: float = 0.0
const _DURATION: float  = 0.60
const _MAX_SCALE: float = 4.8
const _SPARK_COUNT: int = 16

var _rings:  Array = []
var _sparks: Array = []


func _ready() -> void:
	_create_rings()
	_create_sparks()
	_spawn_water_ripple()
	_play_sound()


func _create_rings() -> void:
	# Beyaz flaştan kırmızı-dumana doğru: gerçekçi patlama renk paleti
	var colors := [
		Color(1.00, 1.00, 0.96, 1.00),  # beyaz flaş
		Color(1.00, 0.92, 0.22, 1.00),  # parlak sarı
		Color(1.00, 0.48, 0.06, 1.00),  # turuncu
		Color(0.88, 0.12, 0.04, 0.90),  # kırmızı
		Color(0.28, 0.26, 0.30, 0.72),  # koyu duman
	]
	var sizes := [3.5, 7.0, 11.5, 17.0, 23.0]
	for i in colors.size():
		var ring := Polygon2D.new()
		var pts  := PackedVector2Array()
		for j in 16:
			var angle := float(j) / 16.0 * TAU
			pts.push_back(Vector2(cos(angle), sin(angle)) * sizes[i])
		ring.polygon = pts
		ring.color   = colors[i]
		add_child(ring)
		_rings.append(ring)


func _create_sparks() -> void:
	for i in _SPARK_COUNT:
		var angle := float(i) / float(_SPARK_COUNT) * TAU + randf_range(-0.22, 0.22)
		var spd   := randf_range(150.0, 340.0)
		_sparks.append({
			"pos": Vector2.ZERO,
			# Y * 0.50 — perspektif için kıvılcımlar yatay yayılır
			"vel": Vector2(cos(angle) * spd, sin(angle) * spd * 0.50),
			"col": Color(1.0, randf_range(0.30, 0.85), 0.06, 1.0),
			"len": randf_range(5.0, 14.0),
		})


func _spawn_water_ripple() -> void:
	if not ResourceLoader.exists("res://scenes/water_ripple.tscn"):
		return
	var scene := load("res://scenes/water_ripple.tscn") as PackedScene
	if scene == null:
		return
	var ripple := scene.instantiate()
	ripple.global_position = global_position
	get_parent().add_child(ripple)


func _play_sound() -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	var stream := AudioStreamWAV.new()
	stream.format   = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var n    := int(22050 * 0.32)
	var data := PackedByteArray()
	for i in n:
		var t     := float(i) / 22050.0
		var noise := randf() * 2.0 - 1.0
		var env   := exp(-t * 11.0)
		var low   := sin(TAU * 82.0 * t) * 0.40
		var val   := int((noise * 0.60 + low) * env * 28000.0)
		val = clamp(val, -32768, 32767)
		data.append(val & 0xFF)
		data.append((val >> 8) & 0xFF)
	stream.data      = data
	player.stream    = stream
	player.volume_db = -4.0
	player.play()


func _process(delta: float) -> void:
	_time += delta
	var t := _time / _DURATION
	if t >= 1.0:
		queue_free()
		return

	# Halkalar: Y ekseninde 0.50 squish → yukarıdan bakış perspektifi
	for i in _rings.size():
		var s := 1.0 + t * _MAX_SCALE * (0.36 + float(i) * 0.38)
		_rings[i].scale     = Vector2(s, s * 0.50)
		_rings[i].modulate.a = pow(1.0 - t, 1.25)

	# Kıvılcım fiziği: sürtünme ile yavaşlama
	for spark in _sparks:
		spark["pos"] += spark["vel"] * delta
		spark["vel"] *= (1.0 - delta * 5.2)

	queue_redraw()


func _draw() -> void:
	var t := _time / _DURATION
	for spark in _sparks:
		var alpha := maxf(0.0, 1.0 - t * 1.9)
		if alpha < 0.04:
			continue
		var vel_len := (spark["vel"] as Vector2).length()
		if vel_len < 1.0:
			continue
		var dir  := (spark["vel"] as Vector2) / vel_len
		var tip  := spark["pos"] as Vector2
		var tail := tip - dir * (spark["len"] as float) * (1.0 - t * 0.4)
		var c    := spark["col"] as Color
		c.a = alpha
		draw_line(tip, tail, c, 2.2)
