class_name RoomScene
extends Control
## A wide banner illustration of the room the crew is standing in.
##
## Same approach as the portraits: modular drawn pieces rather than art files.
## Each room is a handful of rectangles and lines assembled in a 400x130 virtual
## space, tinted by the room's own colour from rooms.json.

const VW := 400.0
const VH := 130.0

var room_id: String = "cell_block"
var _sx := 1.0
var _sy := 1.0
var _unit := 1.0
var _tint := Palette.PANEL
var _time := 0.0


func _init(id: String = "cell_block") -> void:
	room_id = id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The banner is a wide strip of any aspect ratio, so it stretches to fill
	# rather than letterboxing, and clips in case a piece of scenery overruns.
	clip_contents = true
	custom_minimum_size = Vector2(0, 130)


func _ready() -> void:
	_tint = Palette.of(str(Content.get_room(room_id).get("color", "#5b6478")))
	resized.connect(queue_redraw)
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	if fmod(_time, 0.2) < delta:
		queue_redraw()


func _v(x: float, y: float) -> Vector2:
	return Vector2(x * _sx, y * _sy)


## Line widths and radii use a single unit so they stay even when the banner is
## stretched more in one axis than the other.
func _u(n: float) -> float:
	return n * _unit


func _rect(x: float, y: float, w: float, h: float, color: Color, filled: bool = true, width: float = 2.0) -> void:
	draw_rect(Rect2(_v(x, y), Vector2(w * _sx, h * _sy)), color, filled, -1.0 if filled else _u(width))


func _line(x1: float, y1: float, x2: float, y2: float, color: Color, width: float = 2.0) -> void:
	draw_line(_v(x1, y1), _v(x2, y2), color, _u(width), true)


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	_sx = size.x / VW
	_sy = size.y / VH
	_unit = minf(_sx, _sy)

	var wall := Palette.darken(_tint, 0.55)
	var floor_color := Palette.darken(_tint, 0.72)
	var detail := Palette.lighten(_tint, 0.10)
	var floor_y := VH * 0.74

	_rect(0, 0, VW, floor_y, wall)
	_rect(0, floor_y, VW, VH - floor_y, floor_color)
	_line(0, floor_y, VW, floor_y, Palette.darken(_tint, 0.3), 2.0)

	match room_id:
		"cell_block": _draw_cells(detail, floor_y)
		"cafeteria": _draw_cafeteria(detail, floor_y)
		"yard": _draw_yard(detail, floor_y)
		"laundry": _draw_laundry(detail, floor_y)
		"workshop": _draw_workshop(detail, floor_y)
		"medical": _draw_medical(detail, floor_y)
		"guard_station": _draw_guard_station(detail, floor_y)
		"security": _draw_security(detail, floor_y)
		"maintenance": _draw_maintenance(detail, floor_y)
		"sewer": _draw_sewer(detail, floor_y)
		"library": _draw_library(detail, floor_y)
		"chapel": _draw_chapel(detail, floor_y)
		"outer_wall": _draw_outer_wall(detail, floor_y)
		_: _draw_cells(detail, floor_y)

	# A vignette so the banner sits into the page rather than on top of it.
	for i in range(6):
		var a := 0.05 - i * 0.008
		draw_rect(Rect2(_v(0, 0), Vector2(size.x, _u(2 + i * 3))), Palette.with_alpha(Palette.BG_DEEP, a), true)


func _draw_cells(detail: Color, floor_y: float) -> void:
	for cell in range(3):
		var x := 18.0 + cell * 130.0
		_rect(x, 16, 108, floor_y - 16, Palette.darken(_tint, 0.72))
		for bar in range(7):
			_line(x + 8 + bar * 15.0, 16, x + 8 + bar * 15.0, floor_y, detail, 3.0)
		_rect(x + 14, floor_y - 34, 46, 12, Palette.darken(detail, 0.2))
		_rect(x + 14, floor_y - 22, 46, 10, Palette.darken(detail, 0.45))


func _draw_cafeteria(detail: Color, floor_y: float) -> void:
	for t in range(3):
		var x := 34.0 + t * 124.0
		_rect(x, floor_y - 28, 92, 7, detail)
		_line(x + 12, floor_y - 21, x + 12, floor_y, detail, 3.0)
		_line(x + 80, floor_y - 21, x + 80, floor_y, detail, 3.0)
		_rect(x + 26, floor_y - 35, 26, 7, Palette.ACCENT)
	_rect(0, 12, VW, 22, Palette.darken(_tint, 0.68))
	for i in range(12):
		_line(i * 34.0, 12, i * 34.0, 34, Palette.with_alpha(detail, 0.5), 2.0)


func _draw_yard(detail: Color, floor_y: float) -> void:
	draw_circle(_v(330, 26), _u(18.0), Palette.with_alpha(Palette.ACCENT, 0.6))
	for i in range(28):
		_line(i * 15.0, 20, i * 15.0, floor_y, Palette.with_alpha(detail, 0.55), 2.0)
	for i in range(4):
		_line(0, 24 + i * 16.0, VW, 24 + i * 16.0, Palette.with_alpha(detail, 0.35), 2.0)
	_line(0, 16, VW, 16, Palette.with_alpha(Palette.DANGER, 0.7), 3.0)
	_rect(20, floor_y - 8, 60, 8, Palette.darken(detail, 0.3))


func _draw_laundry(detail: Color, floor_y: float) -> void:
	for m in range(4):
		var x := 24.0 + m * 92.0
		_rect(x, floor_y - 64, 72, 64, Palette.darken(detail, 0.25))
		draw_circle(_v(x + 36, floor_y - 34), _u(20.0), Palette.darken(_tint, 0.8))
		var spin: float = _time * (1.4 + m * 0.3)
		draw_arc(_v(x + 36, floor_y - 34), _u(14.0), spin, spin + 2.4, 12, Palette.with_alpha(Palette.TEXT, 0.45), _u(3.0), true)
	for p in range(5):
		draw_circle(_v(60 + p * 70.0, 20 + sin(_time + p) * 5.0), _u(7.0 + p % 3), Palette.with_alpha(Palette.TEXT, 0.08))


func _draw_workshop(detail: Color, floor_y: float) -> void:
	_rect(20, 20, 150, 56, Palette.darken(_tint, 0.7))
	for i in range(6):
		_line(30 + i * 24.0, 26, 30 + i * 24.0, 46, detail, 3.0)
		draw_circle(_v(30 + i * 24.0, 52), _u(4.0), Palette.with_alpha(detail, 0.8))
	_rect(200, floor_y - 30, 170, 10, detail)
	_line(212, floor_y - 20, 212, floor_y, detail, 4.0)
	_line(356, floor_y - 20, 356, floor_y, detail, 4.0)
	_rect(240, floor_y - 44, 34, 14, Palette.ACCENT)


func _draw_medical(detail: Color, floor_y: float) -> void:
	_rect(30, floor_y - 36, 130, 12, Color("#dfe6ef"))
	_line(36, floor_y - 24, 36, floor_y, detail, 4.0)
	_line(152, floor_y - 24, 152, floor_y, detail, 4.0)
	_rect(250, 18, 90, 62, Palette.darken(detail, 0.2))
	_line(295, 28, 295, 70, Palette.DANGER, 5.0)
	_line(274, 49, 316, 49, Palette.DANGER, 5.0)
	for i in range(3):
		_rect(252, 26 + i * 20.0, 86, 2, Palette.with_alpha(Palette.TEXT, 0.2))


func _draw_guard_station(detail: Color, floor_y: float) -> void:
	_rect(40, floor_y - 40, 180, 40, Palette.darken(detail, 0.2))
	_rect(56, floor_y - 58, 52, 18, Palette.darken(_tint, 0.8))
	draw_circle(_v(140, floor_y - 48), _u(7.0), Palette.ACCENT)
	_rect(262, 20, 106, 52, Palette.darken(_tint, 0.75))
	for i in range(4):
		_line(268, 28 + i * 12.0, 362, 28 + i * 12.0, Palette.with_alpha(detail, 0.6), 3.0)
	var blink: float = 0.4 + 0.5 * absf(sin(_time * 2.0))
	draw_circle(_v(378, 26), _u(5.0), Palette.with_alpha(Palette.DANGER, blink))


func _draw_security(detail: Color, floor_y: float) -> void:
	for row in range(2):
		for col in range(6):
			var x := 22.0 + col * 62.0
			var y := 14.0 + row * 42.0
			_rect(x, y, 52, 34, Palette.darken(_tint, 0.82))
			_rect(x + 3, y + 3, 46, 28, Palette.with_alpha(Palette.TEAL, 0.10 + 0.10 * absf(sin(_time * 1.3 + col + row * 2))))
			_line(x + 3, y + 10 + fmod(_time * 22.0 + col * 9.0, 22.0), x + 49, y + 10 + fmod(_time * 22.0 + col * 9.0, 22.0), Palette.with_alpha(Palette.TEAL, 0.35), 2.0)
	_rect(150, floor_y - 22, 110, 22, Palette.darken(detail, 0.25))


func _draw_maintenance(detail: Color, floor_y: float) -> void:
	for i in range(3):
		var y := 20.0 + i * 22.0
		_line(0, y, VW, y, Palette.darken(detail, 0.1), 8.0)
		_rect(70 + i * 90.0, y - 6, 16, 12, Palette.darken(detail, 0.35))
	_rect(280, floor_y - 54, 80, 54, Palette.darken(_tint, 0.78))
	for i in range(4):
		_line(288, floor_y - 46 + i * 11.0, 352, floor_y - 46 + i * 11.0, Palette.with_alpha(detail, 0.55), 3.0)
	_rect(40, floor_y - 26, 40, 26, Palette.darken(detail, 0.4))


func _draw_sewer(detail: Color, floor_y: float) -> void:
	draw_arc(_v(200, floor_y + 6), _u(130.0), PI, TAU, 28, Palette.darken(detail, 0.15), _u(8.0), true)
	draw_arc(_v(200, floor_y + 6), _u(96.0), PI, TAU, 24, Palette.with_alpha(detail, 0.4), _u(4.0), true)
	var water := Palette.with_alpha(Palette.TEAL, 0.22)
	_rect(0, floor_y - 10, VW, VH - floor_y + 10, water)
	for i in range(9):
		var wy: float = floor_y - 6 + sin(_time * 1.6 + i) * 3.0
		_line(i * 45.0, wy, i * 45.0 + 34.0, wy, Palette.with_alpha(Palette.TEXT, 0.12), 2.0)


func _draw_library(detail: Color, floor_y: float) -> void:
	for shelf in range(2):
		var y := 16.0 + shelf * 44.0
		_rect(24, y, 150, 38, Palette.darken(detail, 0.3))
		_rect(226, y, 150, 38, Palette.darken(detail, 0.3))
		for b in range(12):
			var h := 22.0 + float((b * 7) % 3) * 5.0
			_rect(28 + b * 12.0, y + 38 - h, 9, h, Palette.with_alpha(Palette.ACCENT if b % 3 == 0 else Palette.TEAL, 0.45))
			_rect(230 + b * 12.0, y + 38 - h, 9, h, Palette.with_alpha(Palette.PURPLE if b % 4 == 0 else Palette.TEXT_DIM, 0.35))
	_rect(182, floor_y - 22, 36, 22, Palette.darken(detail, 0.35))


func _draw_chapel(detail: Color, floor_y: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		_v(200, 8), _v(238, 46), _v(238, 82), _v(162, 82), _v(162, 46)]),
		Palette.with_alpha(Palette.ACCENT, 0.22))
	_line(200, 18, 200, 76, Palette.with_alpha(Palette.ACCENT, 0.5), 3.0)
	_line(178, 40, 222, 40, Palette.with_alpha(Palette.ACCENT, 0.5), 3.0)
	for pew in range(3):
		var y := floor_y - 34 + pew * 12.0
		_rect(60, y, 90, 5, Palette.darken(detail, 0.25))
		_rect(250, y, 90, 5, Palette.darken(detail, 0.25))
	var flicker: float = 0.5 + 0.4 * absf(sin(_time * 3.4))
	draw_circle(_v(322, floor_y - 44), _u(6.0), Palette.with_alpha(Palette.ACCENT, flicker))


func _draw_outer_wall(detail: Color, floor_y: float) -> void:
	_rect(0, 0, VW, floor_y, Palette.darken(_tint, 0.4))
	for row in range(7):
		var y := 6.0 + row * 14.0
		_line(0, y, VW, y, Palette.with_alpha(Palette.BG_DEEP, 0.3), 2.0)
		var offset: float = 0.0 if row % 2 == 0 else 20.0
		for b in range(11):
			_line(b * 40.0 + offset, y, b * 40.0 + offset, y + 14.0, Palette.with_alpha(Palette.BG_DEEP, 0.25), 2.0)
	_rect(300, 0, 56, 46, Palette.darken(_tint, 0.7))
	var sweep: float = 200.0 + sin(_time * 0.8) * 150.0
	draw_colored_polygon(PackedVector2Array([
		_v(328, 40), _v(sweep + 40.0, floor_y + 24.0), _v(sweep - 40.0, floor_y + 24.0)]),
		Palette.with_alpha(Palette.ACCENT, 0.18))
	draw_circle(_v(328, 34), _u(6.0), Palette.ACCENT)
	_line(0, floor_y - 6, VW, floor_y - 6, Palette.with_alpha(Palette.DANGER, 0.5), 3.0)
