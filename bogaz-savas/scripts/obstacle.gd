extends Area2D

const EXPLOSION_SCENE = preload("res://scenes/explosion.tscn")

@export var speed: float = 300.0
@export var damage: int = 1

func _ready():
	add_to_group("mine")
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	get_parent().position.y += speed * delta
	if get_parent().position.y > get_viewport().get_visible_rect().size.y + 100:
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
