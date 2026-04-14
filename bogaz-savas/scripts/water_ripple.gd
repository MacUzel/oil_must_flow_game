extends Node2D

## Patlama sonrası yüzeyde yayılan perspektifli su dalgası.

var _time: float = 0.0
const _DURATION: float = 2.2
const _RING_COUNT: int  = 6
const _SEGMENTS: int    = 30


func _process(delta: float) -> void:
	_time += delta
	if _time >= _DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for i in _RING_COUNT:
		# Her halka biraz gecikmeli başlar
		var delay := float(i) / float(_RING_COUNT) * 0.45
		if _time < delay:
			continue

		var local_t: float = clamp((_time - delay) / (_DURATION - delay), 0.0, 1.0)

		# Perspektif elips: yatayda geniş, dikeyde dar (yukarıdan bakış hissi)
		var rx: float = lerp(4.0, 90.0 + float(i) * 22.0, local_t)
		var ry: float = rx * 0.36

		var alpha: float = (1.0 - local_t) * (0.70 - float(i) * 0.06)
		if alpha < 0.02:
			continue

		var width: float = maxf(0.4, 2.5 - local_t * 2.0)
		var color  := Color(0.52, 0.84, 1.00, alpha)

		# Dış halka biraz daha parlak beyaz
		if i == 0:
			color = Color(0.85, 0.96, 1.00, alpha * 1.2)

		var pts := PackedVector2Array()
		for j in _SEGMENTS + 1:
			var angle := float(j) / float(_SEGMENTS) * TAU
			pts.append(Vector2(cos(angle) * rx, sin(angle) * ry))
		draw_polyline(pts, color, width)
