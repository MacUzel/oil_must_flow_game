extends Node2D

## Havada patlama — drone ve füzeler vurulunca.
## Hafif, hızlı: flaş + kıvılcım. Su dalgası yok.

var _time: float = 0.0
const _DURATION: float  = 0.40
const _SPARK_COUNT: int = 14

var _sparks: Array = []


func _ready() -> void:
	_create_sparks()
	_play_sound()


func _create_sparks() -> void:
	for i in _SPARK_COUNT:
		var angle := float(i) / float(_SPARK_COUNT) * TAU + randf_range(-0.30, 0.30)
		var spd   := randf_range(90.0, 240.0)
		_sparks.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle) * spd, sin(angle) * spd * 0.48),
			"col": Color(1.0, randf_range(0.40, 0.92), 0.10, 1.0),
			"len": randf_range(3.0, 10.0),
		})


func _play_sound() -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	var stream := AudioStreamWAV.new()
	stream.format   = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var n    := int(22050 * 0.15)
	var data := PackedByteArray()
	for i in n:
		var t     := float(i) / 22050.0
		var noise := randf() * 2.0 - 1.0
		var env   := exp(-t * 20.0)
		var val   := int(noise * env * 18000.0)
		val = clamp(val, -32768, 32767)
		data.append(val & 0xFF)
		data.append((val >> 8) & 0xFF)
	stream.data      = data
	player.stream    = stream
	player.volume_db = -9.0
	player.play()


func _process(delta: float) -> void:
	_time += delta
	if _time >= _DURATION:
		queue_free()
		return
	for spark in _sparks:
		spark["pos"] += spark["vel"] * delta
		spark["vel"]  = (spark["vel"] as Vector2) * (1.0 - delta * 6.5)
	queue_redraw()


func _draw() -> void:
	var t := _time / _DURATION

	# Merkez flaşı — beyazdan turuncuya
	var flash_r: float = lerp(0.0, 26.0, minf(t * 6.0, 1.0)) * (1.0 - t)
	var flash_a: float = maxf(0.0, 1.0 - t * 2.8)
	if flash_r > 0.5:
		draw_circle(Vector2.ZERO, flash_r,
			Color(1.0, lerp(1.0, 0.55, t), 0.20, flash_a))

	# Kıvılcımlar
	for spark in _sparks:
		var alpha: float = maxf(0.0, 1.0 - t * 2.4)
		if alpha < 0.04:
			continue
		var vel   := spark["vel"] as Vector2
		var vlen  := vel.length()
		if vlen < 1.0:
			continue
		var dir  := vel / vlen
		var tip  := spark["pos"] as Vector2
		var tail := tip - dir * (spark["len"] as float) * (1.0 - t * 0.5)
		var c    := spark["col"] as Color
		c.a = alpha
		draw_line(tip, tail, c, 1.8)
