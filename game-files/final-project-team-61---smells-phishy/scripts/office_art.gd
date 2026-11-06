extends Control
## Original, code-drawn low-resolution office illustration.
@export var portrait := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)

func draw_rain_pane(pane: Rect2, phase: int) -> void:
	var rain_color := Color("a9d5ed")
	var usable_width := maxi(1, int(pane.size.x) - 8)
	var usable_height := maxi(1, int(pane.size.y) - 10)
	for i in range(7):
		var x := pane.position.x + 4 + posmod(i * 11 + phase * 7, usable_width)
		var y := pane.position.y + 3 + posmod(i * 7 + phase * 5, usable_height)
		draw_line(Vector2(x, y), Vector2(x - 2, y + 6), rain_color, 1.5, false)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("172a3a"))
	var factor := maxf(size.x / 320.0, size.y / 180.0)
	draw_set_transform((size - Vector2(320, 180) * factor) / 2, 0, Vector2.ONE * factor)
	draw_rect(Rect2(0, 0, 320, 180), Color("172a3a"))
	for y in range(8, 140, 12):
		draw_rect(Rect2(0, y, 320, 5), Color("24425a"))
	draw_rect(Rect2(18, 18, 78, 77), Color("102131"))
	draw_rect(Rect2(22, 22, 70, 69), Color("41627a"))
	draw_rain_pane(Rect2(22, 22, 33, 30), 0)
	draw_rain_pane(Rect2(59, 22, 33, 30), 1)
	draw_rain_pane(Rect2(22, 56, 33, 35), 2)
	draw_rain_pane(Rect2(59, 56, 33, 35), 3)
	draw_rect(Rect2(55, 22, 4, 70), Color("172a3a"))
	draw_rect(Rect2(22, 52, 70, 4), Color("172a3a"))
	draw_rect(Rect2(242, 24, 58, 55), Color("c4bd91"))
	for y in range(34, 68, 8):
		draw_rect(Rect2(250, y, 40, 2), Color("625c46"))
	if portrait:
		# Morgan: a readable pixel-art supervisor portrait built from hard-edged shapes.
		var hair := Color("252b2c")
		var hair_highlight := Color("3b4342")
		var skin := Color("b9a77d")
		var skin_shadow := Color("8d7958")
		var face_ink := Color("303536")
		var jacket := Color("355f72")
		var jacket_shadow := Color("274a59")
		var shirt := Color("d8d5bd")
		# Shoulders, jacket, shirt, and neck.
		draw_rect(Rect2(108, 121, 104, 39), jacket_shadow)
		draw_rect(Rect2(118, 109, 84, 51), jacket)
		draw_rect(Rect2(148, 107, 25, 38), shirt)
		draw_rect(Rect2(151, 96, 20, 17), skin_shadow)
		# Ears and stepped face shape.
		draw_rect(Rect2(131, 63, 7, 21), skin_shadow)
		draw_rect(Rect2(185, 63, 7, 21), skin_shadow)
		draw_rect(Rect2(136, 48, 50, 49), skin)
		draw_rect(Rect2(141, 97, 40, 8), skin)
		draw_rect(Rect2(136, 80, 5, 17), skin_shadow)
		draw_rect(Rect2(181, 81, 5, 16), skin_shadow)
		# Asymmetrical hair, sideburns, and a few highlights.
		draw_rect(Rect2(132, 39, 58, 16), hair)
		draw_rect(Rect2(128, 46, 12, 31), hair)
		draw_rect(Rect2(137, 35, 40, 7), hair)
		draw_rect(Rect2(178, 42, 15, 21), hair)
		draw_rect(Rect2(137, 52, 18, 8), hair)
		draw_rect(Rect2(155, 48, 25, 7), hair)
		draw_rect(Rect2(132, 70, 7, 18), hair)
		draw_rect(Rect2(183, 68, 7, 19), hair)
		draw_rect(Rect2(143, 40, 21, 3), hair_highlight)
		draw_rect(Rect2(132, 51, 5, 12), hair_highlight)
		# Brows, eyes, nose, and mouth are separated so the face reads at small sizes.
		draw_rect(Rect2(143, 67, 12, 3), face_ink)
		draw_rect(Rect2(168, 67, 12, 3), face_ink)
		draw_rect(Rect2(145, 73, 9, 5), Color("e5dfc6"))
		draw_rect(Rect2(169, 73, 9, 5), Color("e5dfc6"))
		draw_rect(Rect2(149, 73, 3, 5), face_ink)
		draw_rect(Rect2(171, 73, 3, 5), face_ink)
		draw_rect(Rect2(159, 76, 4, 12), skin_shadow)
		draw_rect(Rect2(159, 86, 8, 3), skin_shadow)
		draw_rect(Rect2(151, 93, 20, 3), face_ink)
		draw_rect(Rect2(156, 97, 10, 2), Color("755f4d"))
		# Stepped collar, tie, and supervisor badge finish the uniform.
		draw_rect(Rect2(139, 110, 14, 6), shirt)
		draw_rect(Rect2(144, 116, 13, 6), shirt)
		draw_rect(Rect2(170, 110, 14, 6), shirt)
		draw_rect(Rect2(166, 116, 13, 6), shirt)
		draw_rect(Rect2(158, 112, 7, 8), Color("243b4a"))
		draw_rect(Rect2(156, 120, 11, 18), Color("243b4a"))
		draw_rect(Rect2(183, 125, 14, 10), Color("c8bd8c"))
		draw_rect(Rect2(186, 128, 8, 2), jacket_shadow)
	else:
		draw_rect(Rect2(121, 53, 104, 78), Color("8199a2"))
		draw_rect(Rect2(129, 61, 88, 58), Color("173d46"))
		for y in range(71, 111, 9):
			draw_rect(Rect2(138, y, 53 - y % 15, 3), Color("9cae7d"))
		draw_rect(Rect2(159, 131, 26, 12), Color("77795f"))
	draw_rect(Rect2(0, 146, 320, 34), Color("435865"))
	draw_rect(Rect2(0, 146, 320, 5), Color("90a8ad"))
	draw_rect(Rect2(20, 155, 61, 16), Color("d2cba4"))
	draw_rect(Rect2(251, 150, 22, 22), Color("4b5140"))
