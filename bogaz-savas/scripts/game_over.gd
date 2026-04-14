extends CanvasLayer

const SAVE_PATH = "user://save_data.cfg"

func setup(distance: float) -> void:
	var earned_gold := int(distance / 10)
	$Container/ScoreLabel.text = "Mesafe: %dm  |  ⚓ +%d" % [int(distance), earned_gold]
	var pd := get_node_or_null("/root/PlayerData")
	if pd:
		pd.add_gold(earned_gold)
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	var current_best: int = config.get_value("game", "high_score", 0)
	if int(distance) > current_best:
		current_best = int(distance)
		config.set_value("game", "high_score", current_best)
		config.save(SAVE_PATH)
		$Container/NewRecordLabel.visible = true
	$Container/HighScoreLabel.text = "Rekor: " + str(current_best) + "m"

func _ready() -> void:
	$Container/RestartButton.pressed.connect(_on_restart_pressed)
	$Container/MainMenuButton.pressed.connect(_on_main_menu_pressed)
	_play_gameover_sound()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _play_gameover_sound() -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	# Üç azalan nota: sol-mi-do (üzücü akor)
	var freqs := [392.0, 330.0, 247.0]
	var note_samples := int(22050 * 0.42)
	var data := PackedByteArray()
	for fi in freqs.size():
		for i in note_samples:
			var t := float(i) / 22050.0
			var env := exp(-t * 2.2) * (1.0 - float(fi) * 0.12)
			var val := int(sin(TAU * freqs[fi] * t) * env * 20000.0)
			val = clamp(val, -32768, 32767)
			data.append(val & 0xFF)
			data.append((val >> 8) & 0xFF)
	stream.data = data
	player.stream = stream
	player.volume_db = -6.0
	player.play()
