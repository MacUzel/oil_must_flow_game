extends Control

const DEAD_ZONE: float = 18.0
const STICK_RADIUS: float = 55.0
const BASE_RADIUS: float = 75.0

var _touch_index: int = -1
var _base_pos: Vector2 = Vector2.ZERO
var _raw_stick: Vector2 = Vector2.ZERO
var _active: bool = false

var _pressed := {
	"move_left": false,
	"move_right": false,
	"move_up": false,
	"move_down": false,
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed and _touch_index == -1:
		# Sadece ekranın alt %60'ına dokunuşu kabul et
		if event.position.y > get_viewport_rect().size.y * 0.40:
			_touch_index = event.index
			_base_pos = event.position
			_raw_stick = event.position
			_active = true
			queue_redraw()
	elif not event.pressed and event.index == _touch_index:
		_release_all()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_index:
		return
	_raw_stick = event.position
	_update_dirs()
	queue_redraw()


func _update_dirs() -> void:
	var delta := _raw_stick - _base_pos
	var len := delta.length()
	var norm: Vector2 = delta / max(len, 0.001)

	var want := {
		"move_left":  len > DEAD_ZONE and norm.x < -0.30,
		"move_right": len > DEAD_ZONE and norm.x >  0.30,
		"move_up":    len > DEAD_ZONE and norm.y < -0.30,
		"move_down":  len > DEAD_ZONE and norm.y >  0.30,
	}
	for action: String in want:
		if want[action] and not _pressed[action]:
			Input.action_press(action)
		elif not want[action] and _pressed[action]:
			Input.action_release(action)
		_pressed[action] = want[action]


func _release_all() -> void:
	_touch_index = -1
	_active = false
	for action: String in _pressed:
		if _pressed[action]:
			Input.action_release(action)
		_pressed[action] = false
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var base: Vector2 = _base_pos
	var delta: Vector2 = _raw_stick - _base_pos
	if delta.length() > STICK_RADIUS:
		delta = delta.normalized() * STICK_RADIUS
	var stick: Vector2 = base + delta

	# Dış halka
	draw_circle(base, BASE_RADIUS, Color(1, 1, 1, 0.10))
	draw_arc(base, BASE_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.32), 2.5)

	# İç nokta (stick)
	draw_circle(stick, 32.0, Color(1, 1, 1, 0.28))
	draw_arc(stick, 32.0, 0, TAU, 32, Color(1, 1, 1, 0.60), 2.0)
