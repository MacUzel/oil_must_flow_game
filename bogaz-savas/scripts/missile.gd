extends Area2D

const EXPLOSION_SCENE = preload("res://scenes/explosion.tscn")

@export var speed: float = 350.0
@export var damage: int = 1
@export var lifetime: float = 4.0
var direction: Vector2 = Vector2.ZERO
var ship: Node2D = null
var spawned: bool = false
var timer: float = 0.0

func _ready():
	add_to_group("targetable")
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	if not spawned:
		spawned = true
		var screen = get_viewport().get_visible_rect().size
		if randi() % 2 == 0:
			get_parent().position.x = -50
		else:
			get_parent().position.x = screen.x + 50
		get_parent().position.y = randf_range(100, 600)

		ship = get_tree().current_scene.get_node_or_null("CharacterBody2D2")
		if ship:
			direction = (ship.global_position - global_position).normalized()
		else:
			direction = Vector2(0, 1)
		return

	timer += delta
	if timer >= lifetime:
		_spawn_explosion()
		get_parent().queue_free()

	if ship and is_instance_valid(ship):
		var desired = (ship.global_position - global_position).normalized()
		direction = direction.lerp(desired, 3.0 * delta).normalized()

	get_parent().position += direction * speed * delta
	rotation = direction.angle() + PI / 2

	var screen = get_viewport().get_visible_rect()
	if get_parent().position.y > screen.size.y + 100 or get_parent().position.x < -200 or get_parent().position.x > screen.size.x + 200:
		get_parent().queue_free()

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage()
		_spawn_explosion()
		get_parent().queue_free()

func _spawn_explosion() -> void:
	var exp := EXPLOSION_SCENE.instantiate()
	exp.global_position = global_position
	get_parent().add_child(exp)
