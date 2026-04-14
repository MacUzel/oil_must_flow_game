extends CanvasLayer

## Oyun içi HUD: can, mesafe, pause paneli ve dinamik kontrol şeması.

const _JOYSTICK_SCRIPT = preload("res://scripts/virtual_joystick.gd")
const _TILT_SCRIPT     = preload("res://scripts/tilt_control.gd")

@onready var hp_label       = $HpLabel
@onready var distance_label = $DistanceLabel
@onready var pause_panel    = $PausePanel
@onready var pause_button   = $PauseButton
@onready var streak_label   = $StreakLabel
@onready var _dpad: Control = $VirtualDpad


func _ready() -> void:
	_setup_controls()


## PlayerData'daki kontrol şemasına göre doğru kontrol nodeunu aktif eder.
func _setup_controls() -> void:
	var pd := get_node_or_null("/root/PlayerData")
	var scheme: String = pd.control_scheme if pd != null else "joystick"

	match scheme:
		"joystick":
			_dpad.queue_free()
			var joy := Control.new()
			joy.name = "VirtualJoystick"
			joy.set_anchors_preset(Control.PRESET_FULL_RECT)
			joy.mouse_filter = Control.MOUSE_FILTER_IGNORE
			joy.set_script(_JOYSTICK_SCRIPT)
			add_child(joy)

		"dpad":
			pass  # Mevcut VirtualDpad düğümü aktif kalır

		"tilt":
			_dpad.queue_free()
			var tilt := Node.new()
			tilt.name = "TiltControl"
			tilt.set_script(_TILT_SCRIPT)
			add_child(tilt)
			_show_tilt_hint()


## Eğim modunda kısa bir bilgi mesajı göster
func _show_tilt_hint() -> void:
	var hint := Label.new()
	hint.text = "📱 Telefonu eğerek yönlendir"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top    = -110.0
	hint.offset_bottom = -75.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0, 0.85))
	add_child(hint)

	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(hint, "modulate:a", 0.0, 1.0)
	tween.tween_callback(hint.queue_free)


func disable_pause_button() -> void:
	pause_button.visible = false


func _on_pause_pressed() -> void:
	pause_panel.visible = true
	get_tree().paused = true


func _on_resume_pressed() -> void:
	pause_panel.visible = false
	get_tree().paused = false


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func update_distance(dist: float) -> void:
	distance_label.text = str(int(dist)) + "m"


func update_hp(hp: int, max_hp: int = 3) -> void:
	hp_label.text = "♥ ".repeat(hp) + "♡ ".repeat(max(max_hp - hp, 0))
