extends Control

const DEAD_ZONE: float = 30.0

var _touches: Dictionary = {}
var _active_dirs := {"move_up": 0, "move_right": 0, "move_down": 0, "move_left": 0}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	var grect: Rect2 = get_global_rect()
	if event is InputEventScreenTouch:
		if event.pressed:
			if grect.has_point(event.position):
				_touches[event.index] = event.position - grect.position
				_update_dirs()
				queue_redraw()
		else:
			if _touches.has(event.index):
				_touches.erase(event.index)
				_update_dirs()
				queue_redraw()
	elif event is InputEventScreenDrag:
		if _touches.has(event.index):
			_touches[event.index] = event.position - grect.position
			_update_dirs()
			queue_redraw()


func _dirs_for_pos(local: Vector2) -> Dictionary:
	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.5
	var dx: float = local.x - cx
	var dy: float = local.y - cy
	return {
		"move_up":    dy < -DEAD_ZONE,
		"move_down":  dy >  DEAD_ZONE,
		"move_left":  dx < -DEAD_ZONE,
		"move_right": dx >  DEAD_ZONE,
	}


func _update_dirs() -> void:
	var want := {"move_up": 0, "move_right": 0, "move_down": 0, "move_left": 0}
	for idx: int in _touches:
		var dirs: Dictionary = _dirs_for_pos(_touches[idx])
		for action: String in dirs:
			if dirs[action]:
				want[action] += 1
	for action: String in want:
		var was: bool = _active_dirs[action] > 0
		var now: bool = want[action] > 0
		if now and not was:
			Input.action_press(action)
		elif not now and was:
			Input.action_release(action)
		_active_dirs[action] = want[action]


func _draw() -> void:
	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.5
	var arm: float = min(cx, cy) * 0.60
	var btn_r: float = min(cx, cy) * 0.36

	_draw_btn(Vector2(cx, cy - arm), Vector2(0, -1), btn_r, _active_dirs["move_up"] > 0)
	_draw_btn(Vector2(cx, cy + arm), Vector2(0,  1), btn_r, _active_dirs["move_down"] > 0)
	_draw_btn(Vector2(cx - arm, cy), Vector2(-1,  0), btn_r, _active_dirs["move_left"] > 0)
	_draw_btn(Vector2(cx + arm, cy), Vector2( 1,  0), btn_r, _active_dirs["move_right"] > 0)


func _draw_btn(center: Vector2, dir: Vector2, r: float, active: bool) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var bg_color: Color     = Color(0.12, 0.22, 0.15, 0.55 if active else 0.28)
	var border_color: Color = Color(0.35, 0.70, 0.45, 0.90 if active else 0.48)
	var arrow_color: Color  = Color(0.85, 1.00, 0.88, 0.95 if active else 0.65)
	draw_circle(center, r, bg_color)
	draw_arc(center, r, 0.0, TAU, 36, border_color, 2.5)
	var tip: Vector2 = center + dir * r * 0.52
	var bl: Vector2  = center - dir * r * 0.30 + perp * r * 0.44
	var br: Vector2  = center - dir * r * 0.30 - perp * r * 0.44
	draw_colored_polygon(PackedVector2Array([tip, bl, br]), arrow_color)
