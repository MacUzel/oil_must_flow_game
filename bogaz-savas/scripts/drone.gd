extends Area2D

const EXPLOSION_SCENE = preload("res://scenes/explosion.tscn")

@export var speed: float = 200.0
@export var damage: int = 1
var direction_x: float = 1.0

func _ready():
	add_to_group("targetable")
	body_entered.connect(_on_body_entered)

	var screen = get_viewport().get_visible_rect().size

	if randi() % 2 == 0:
		get_parent().position.x = -50
		direction_x = 1.0
	else:
		get_parent().position.x = screen.x + 50
		direction_x = -1.0

	get_parent().position.y = randf_range(100, screen.y - 200)

func _physics_process(delta):
	get_parent().position.x += direction_x * speed * delta

	var screen = get_viewport().get_visible_rect().size
	if get_parent().position.x < -100 or get_parent().position.x > screen.x + 100:
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
