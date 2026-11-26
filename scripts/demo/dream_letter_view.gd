extends Control

const INVITATION := ["amigo...", "venha nos conhecer..."]

func _ready() -> void:
	custom_minimum_size.y = 235
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x < 20:
		return
	var paper := Rect2(Vector2(10, 9), size - Vector2(20, 18))
	var edge := PackedVector2Array([
		paper.position, Vector2(paper.end.x, paper.position.y + 3),
		paper.end - Vector2(2, 13), paper.end - Vector2(94, 4),
		paper.end - Vector2(154, 14), Vector2(105, paper.end.y - 1),
		Vector2(paper.position.x + 4, paper.end.y - 8), Vector2(paper.position.x + 8, 74)
	])
	draw_colored_polygon(edge, Color("c5b08b"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3481
	for i in range(120):
		var point := Vector2(rng.randf_range(24, paper.end.x - 13), rng.randf_range(17, paper.end.y - 21))
		draw_line(point, point + Vector2(rng.randf_range(2, 11), 0), Color(0.20, 0.13, 0.08, 0.09))
	for i in range(22):
		var point := paper.end - Vector2(rng.randf_range(28, 127), rng.randf_range(23, 50))
		draw_circle(point, rng.randf_range(1.0, 6.0), Color(0.43, 0.13, 0.11, 0.15))
	var font := ThemeDB.fallback_font
	var line: String = INVITATION[1]
	var scale_factor := minf(1.0, (paper.size.x - 33) / font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 37).x)
	for row in range(INVITATION.size()):
		var words: String = INVITATION[row]
		var cursor := Vector2(28, 81 + row * 65)
		for glyph in words:
			var lettersize := maxi(11, int(rng.randi_range(29, 37) * scale_factor))
			draw_set_transform(cursor + Vector2(0, rng.randf_range(-4.0, 4.0)), rng.randf_range(-0.10, 0.10))
			draw_string(font, Vector2.ZERO, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, lettersize, Color("631e23"))
			cursor.x += font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, lettersize).x
	draw_set_transform(Vector2.ZERO)
