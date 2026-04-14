extends Node

## Eğim (jiroskop/ivmeölçer) tabanlı gemi kontrolü.
## Portrait modda: X ekseni sola/sağa, Y ekseni ileri/geri eğimi okur.

const DEAD_ZONE: float    = 0.55   # Bu değerin altındaki eğimler görmezden gelinir
const TILT_MAX: float     = 4.0    # Bu değerde tam hız
const SMOOTH_FACTOR: float = 8.0   # Giriş yumuşatma (yüksek = daha hızlı yanıt)

var _smoothed: Vector2 = Vector2.ZERO

var _pressed := {
	"move_left":  false,
	"move_right": false,
	"move_up":    false,
	"move_down":  false,
}


func _process(delta: float) -> void:
	if get_tree().paused:
		return

	var raw: Vector3  = Input.get_accelerometer()
	# Portrait modda: raw.x = sol/sağ eğim, raw.y = öne/arkaya eğim
	var target := Vector2(raw.x, -raw.y)  # Y ekseni ters (öne eğ = yukarı git)

	# Yumuşatma — ani sarsıntılardan kaynaklı titreme engellenir
	_smoothed = _smoothed.lerp(target, SMOOTH_FACTOR * delta)

	var tilt_x: float = clamp(_smoothed.x / TILT_MAX, -1.0, 1.0)
	var tilt_y: float = clamp(_smoothed.y / TILT_MAX, -1.0, 1.0)

	var norm_dead: float = DEAD_ZONE / TILT_MAX

	_set_action("move_left",  tilt_x < -norm_dead)
	_set_action("move_right", tilt_x >  norm_dead)
	_set_action("move_up",    tilt_y < -norm_dead)
	_set_action("move_down",  tilt_y >  norm_dead)


func _set_action(action: String, want: bool) -> void:
	if want and not _pressed[action]:
		Input.action_press(action)
	elif not want and _pressed[action]:
		Input.action_release(action)
	_pressed[action] = want


func _notification(what: int) -> void:
	# Node silinirken tüm giriş aksiyonlarını serbest bırak
	if what == NOTIFICATION_PREDELETE:
		for action: String in _pressed:
			if _pressed[action]:
				Input.action_release(action)
