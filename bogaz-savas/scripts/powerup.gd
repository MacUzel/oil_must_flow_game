extends Area2D

enum Type { HEAL, SHIELD, SPEED }

@export var type: Type = Type.HEAL

const SPEED: float = 120.0

const COLORS := {
	Type.HEAL:   Color(0.20, 0.90, 0.30, 1.0),
	Type.SHIELD: Color(0.25, 0.55, 1.00, 1.0),
	Type.SPEED:  Color(1.00, 0.85, 0.10, 1.0),
}
const ICONS := {
	Type.HEAL:   "♥",
	Type.SHIELD: "◈",
	Type.SPEED:  "⚡",
}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_visual()


func _build_visual() -> void:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var angle := TAU * i / 16.0
		pts.append(Vector2(cos(angle), sin(angle)) * 18.0)
	poly.polygon = pts
	poly.color = COLORS[type]
	add_child(poly)

	var lbl := Label.new()
	lbl.text = ICONS[type]
	lbl.position = Vector2(-10.0, -13.0)
	lbl.add_theme_font_size_override("font_size", 18)
	add_child(lbl)


func _physics_process(delta: float) -> void:
	position.y += SPEED * delta
	if position.y > get_viewport().get_visible_rect().size.y + 60:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.has_method("apply_powerup"):
		body.apply_powerup(type)
		queue_free()
