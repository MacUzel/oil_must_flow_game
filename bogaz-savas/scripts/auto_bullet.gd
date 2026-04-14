extends Area2D

## Amerikan savaş gemisinin otomatik mermisi.
## Yalnızca "targetable" gruptaki düşmanlara (drone, füze) kilitlenir.
## Çarptığında patlama oluşturur ve düşmanı yok eder.

const SPEED: float = 650.0
const AIR_EXPLOSION_SCENE = preload("res://scenes/air_explosion.tscn")

var target: Node2D = null
var _velocity: Vector2 = Vector2(0.0, -SPEED)

var _trail: Array[Vector2] = []
const _TRAIL_LEN: int = 10


func _ready() -> void:
	add_to_group("bullet")
	collision_layer = 0
	collision_mask  = 0x7FFFFFFF
	monitoring      = true
	monitorable     = false

	var col   := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	col.shape    = shape
	add_child(col)

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	get_tree().create_timer(4.0).timeout.connect(
		func():
			if is_instance_valid(self):
				queue_free()
	)


func _process(delta: float) -> void:
	if is_instance_valid(target):
		_velocity = (target.global_position - global_position).normalized() * SPEED
	_trail.push_front(global_position)
	if _trail.size() > _TRAIL_LEN:
		_trail.pop_back()
	position += _velocity * delta
	queue_redraw()


func _draw() -> void:
	# Ateşli kuyruk izi
	for i in _trail.size():
		var t := 1.0 - float(i) / float(_TRAIL_LEN)
		var local_pos := _trail[i] - global_position
		var r: float = lerp(1.5, 7.5, t)
		draw_circle(local_pos, r, Color(1.0, 0.52 + t * 0.33, 0.05, t * 0.55))
	# Ana mermi katmanları
	draw_circle(Vector2.ZERO, 9.0, Color(1.00, 0.85, 0.10))
	draw_circle(Vector2.ZERO, 5.5, Color(1.00, 1.00, 0.60))
	draw_circle(Vector2.ZERO, 2.5, Color(1.00, 1.00, 1.00, 0.95))


func _on_body_entered(body: Node) -> void:
	_hit(body)


func _on_area_entered(area: Node) -> void:
	_hit(area)


func _hit(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.is_in_group("player") or node.is_in_group("bullet"):
		return
	# Mayınlara mermi geçmez
	if node.is_in_group("mine"):
		return

	# Düşman kök node'unu bul (Area2D child → root Node2D "enemy" grubunda)
	var enemy_root: Node = null
	if node.is_in_group("enemy"):
		enemy_root = node
	elif is_instance_valid(node.get_parent()) and node.get_parent().is_in_group("enemy"):
		enemy_root = node.get_parent()

	if enemy_root != null:
		var hit_pos: Vector2 = (node as Node2D).global_position if node is Node2D else global_position
		var exp := AIR_EXPLOSION_SCENE.instantiate()
		exp.global_position = hit_pos
		get_parent().add_child(exp)
		enemy_root.queue_free()
	elif node.has_method("take_damage"):
		node.take_damage()

	queue_free()
