class_name RoomScene
extends Control
## Living room banner: environment + the current five prisoners.
## Everything is drawn/generated at runtime so no external art pipeline is needed.

const VW := 400.0
const VH := 180.0
const ACTOR_SIZE := Vector2(52, 68)

var room_id := "cell_block"
var _sx := 1.0
var _sy := 1.0
var _unit := 1.0
var _tint := Palette.PANEL
var _time := 0.0
var _actors: Array[CharacterPortrait] = []
var _actor_bases: Array[Vector2] = []
var _actor_tags: Array[Label] = []

var _idle_actions := ["LOOKOUT", "CHECKING WALL", "KEEPING QUIET", "WATCHING GUARD", "PRETENDING TO WORK"]

func _init(id: String = "cell_block") -> void:
	room_id = id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size = Vector2(0, VH)

func _ready() -> void:
	_tint = Palette.of(str(Content.get_room(room_id).get("color", "#5b6478")))
	_build_crew()
	resized.connect(_layout_crew)
	set_process(true)

func _build_crew() -> void:
	for child in _actors:
		child.queue_free()
	for tag in _actor_tags:
		tag.queue_free()
	_actors.clear()
	_actor_tags.clear()
	_actor_bases.clear()

	if not is_instance_valid(Game) or Game.party.is_empty():
		return

	var count := mini(5, Game.party.size())
	for i in range(count):
		var prisoner: Prisoner = Game.party[i]
		var portrait := CharacterPortrait.new()
		portrait.setup(prisoner, "idle")
		portrait.show_background = false
		portrait.animate = true
		portrait.custom_minimum_size = ACTOR_SIZE
		add_child(portrait)
		_actors.append(portrait)

		var tag := Label.new()
		tag.text = _idle_actions[i % _idle_actions.size()]
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 8)
		tag.add_theme_color_override("font_color", Palette.TEXT_FAINT)
		tag.size = Vector2(82, 14)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tag)
		_actor_tags.append(tag)

func _layout_crew() -> void:
	if _actors.is_empty() or size.x < 20.0:
		return
	var count := _actors.size()
	var spacing := minf(76.0, (size.x - 28.0) / maxf(1.0, float(count)))
	var total := spacing * count
	var start := (size.x - total) * 0.5 + (spacing - ACTOR_SIZE.x) * 0.5
	_actor_bases.clear()
	for i in range(count):
		var p := Vector2(start + i * spacing, size.y * 0.45)
		_actor_bases.append(p)
		_actors[i].position = p
		_actor_tags[i].position = Vector2(p.x - 15, p.y + ACTOR_SIZE.y - 1)

func _process(delta: float) -> void:
	_time += delta
	if fmod(_time, 0.2) < delta:
		queue_redraw()
	for i in range(_actors.size()):
		if i >= _actor_bases.size():
			continue
		var bob := sin(_time * (1.35 + i * 0.17) + i) * 1.8
		var sway := sin(_time * 0.7 + i * 1.8) * 1.2
		_actors[i].position = _actors[i].position.lerp(_actor_bases[i] + Vector2(sway, bob), minf(1.0, delta * 7.0))
		_actors[i].rotation = sin(_time * 0.75 + i) * 0.012

func _v(x: float, y: float) -> Vector2:
	return Vector2(x * _sx, y * _sy)

func _u(n: float) -> float:
	return n * _unit

func _rect(x: float, y: float, w: float, h: float, color: Color, filled := true, width := 2.0) -> void:
	draw_rect(Rect2(_v(x, y), Vector2(w * _sx, h * _sy)), color, filled, -1.0 if filled else _u(width))

func _line(x1: float, y1: float, x2: float, y2: float, color: Color, width := 2.0) -> void:
	draw_line(_v(x1, y1), _v(x2, y2), color, _u(width), true)

func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	_sx = size.x / VW
	_sy = size.y / VH
	_unit = minf(_sx, _sy)

	var wall := Palette.darken(_tint, 0.52)
	var floor := Palette.darken(_tint, 0.73)
	var detail := Palette.lighten(_tint, 0.12)
	var floor_y := 135.0
	_rect(0, 0, VW, floor_y, wall)
	_rect(0, floor_y, VW, VH - floor_y, floor)
	_line(0, floor_y, VW, floor_y, Palette.darken(_tint, 0.25), 3.0)

	_draw_room_decor(detail, floor_y)

	# Overhead light / searchlight sells the room as a place rather than a card.
	var pulse := 0.08 + 0.035 * absf(sin(_time * 1.8))
	draw_circle(_v(200, 22), _u(32), Palette.with_alpha(Palette.TEXT, pulse))
	draw_circle(_v(200, 22), _u(7), Palette.with_alpha(Palette.ACCENT, 0.7))

	# Floor shadows are deliberately beneath the portrait controls.
	for p in _actor_bases:
		_draw_ellipse(_v(p.x + 26, 132), Vector2(_u(23), _u(5)), Palette.with_alpha(Palette.BG_DEEP, 0.45))

	# Vignette.
	for i in range(5):
		draw_rect(Rect2(0, 0, size.x, _u(3 + i * 4)), Palette.with_alpha(Palette.BG_DEEP, 0.035), true)

func _draw_room_decor(detail: Color, floor_y: float) -> void:
	match room_id:
		"cell_block": _draw_cells(detail, floor_y)
		"cafeteria": _draw_tables(detail, floor_y)
		"yard": _draw_yard(detail, floor_y)
		"laundry": _draw_machines(detail, floor_y)
		"workshop": _draw_workshop(detail, floor_y)
		"medical": _draw_medical(detail, floor_y)
		"guard_station", "security": _draw_security(detail, floor_y)
		"maintenance": _draw_pipes(detail, floor_y)
		"sewer": _draw_sewer(detail, floor_y)
		"library": _draw_library(detail, floor_y)
		"chapel": _draw_chapel(detail, floor_y)
		"outer_wall": _draw_outer_wall(detail, floor_y)
		_: _draw_cells(detail, floor_y)

func _draw_cells(detail: Color, floor_y: float) -> void:
	for c in range(3):
		var x := 16.0 + c * 132.0
		_rect(x, 28, 112, floor_y - 28, Palette.darken(_tint, 0.68))
		for b in range(7):
			_line(x + 8 + b * 15.5, 28, x + 8 + b * 15.5, floor_y, detail, 3.0)
		_rect(x + 14, floor_y - 25, 50, 8, Palette.darken(detail, 0.25))

func _draw_tables(detail: Color, floor_y: float) -> void:
	for i in range(3):
		var x := 32.0 + i * 125.0
		_rect(x, floor_y - 28, 92, 7, detail)
		_line(x + 12, floor_y - 21, x + 12, floor_y, detail, 3.0)
		_line(x + 80, floor_y - 21, x + 80, floor_y, detail, 3.0)
		_rect(x + 29, floor_y - 37, 28, 7, Palette.ACCENT)

func _draw_yard(detail: Color, floor_y: float) -> void:
	for i in range(12):
		_line(i * 34.0, 28, i * 34.0, floor_y, Palette.with_alpha(detail, 0.5), 2.0)
	_line(0, 31, VW, 31, Palette.with_alpha(Palette.DANGER, 0.65), 3.0)
	draw_circle(_v(335, 45), _u(14), Palette.with_alpha(Palette.ACCENT, 0.55))

func _draw_machines(detail: Color, floor_y: float) -> void:
	for i in range(4):
		var x := 20.0 + i * 94.0
		_rect(x, floor_y - 68, 74, 68, Palette.darken(detail, 0.28))
		draw_circle(_v(x + 37, floor_y - 36), _u(22), Palette.darken(_tint, 0.78))
		var a := _time * (1.2 + i * 0.15)
		draw_arc(_v(x + 37, floor_y - 36), _u(15), a, a + 2.2, 14, Palette.with_alpha(Palette.TEXT, 0.45), _u(3), true)

func _draw_workshop(detail: Color, floor_y: float) -> void:
	_rect(20, 32, 148, 48, Palette.darken(_tint, 0.67))
	for i in range(6):
		draw_circle(_v(32 + i * 24, 55), _u(5), Palette.with_alpha(detail, 0.75))
	_rect(205, floor_y - 28, 160, 10, detail)
	_line(218, floor_y - 18, 218, floor_y, detail, 4)
	_line(350, floor_y - 18, 350, floor_y, detail, 4)

func _draw_medical(detail: Color, floor_y: float) -> void:
	_rect(30, floor_y - 35, 130, 11, Color("#dfe6ef"))
	_line(38, floor_y - 24, 38, floor_y, detail, 4)
	_line(150, floor_y - 24, 150, floor_y, detail, 4)
	_rect(270, 34, 80, 58, Palette.darken(detail, 0.25))
	_line(310, 46, 310, 80, Palette.DANGER, 5)
	_line(292, 63, 328, 63, Palette.DANGER, 5)

func _draw_security(detail: Color, floor_y: float) -> void:
	for i in range(6):
		var x := 18.0 + i * 64.0
		_rect(x, 35, 54, 38, Palette.darken(_tint, 0.78))
		_rect(x + 4, 39, 46, 30, Palette.with_alpha(Palette.TEAL, 0.16))
		var scan := 41.0 + fmod(_time * 18.0 + i * 7.0, 24.0)
		_line(x + 5, scan, x + 49, scan, Palette.with_alpha(Palette.TEAL, 0.55), 2)
	_rect(135, floor_y - 24, 130, 24, Palette.darken(detail, 0.25))

func _draw_pipes(detail: Color, floor_y: float) -> void:
	for i in range(3):
		var y := 35.0 + i * 25.0
		_line(0, y, VW, y, Palette.darken(detail, 0.05), 8)
		_rect(70 + i * 90, y - 6, 16, 12, Palette.darken(detail, 0.35))

func _draw_sewer(detail: Color, floor_y: float) -> void:
	_rect(0, floor_y - 5, VW, VH - floor_y + 5, Palette.with_alpha(Palette.TEAL, 0.2))
	for i in range(9):
		var y := floor_y + sin(_time * 1.7 + i) * 3
		_line(i * 46.0, y, i * 46.0 + 30, y, Palette.with_alpha(Palette.TEXT, 0.14), 2)

func _draw_library(detail: Color, floor_y: float) -> void:
	for side in range(2):
		var x := 20.0 + side * 220.0
		_rect(x, 30, 155, 64, Palette.darken(detail, 0.3))
		for b in range(12):
			_rect(x + 5 + b * 12, 45 - (b % 3) * 3, 9, 49 + (b % 3) * 3, Palette.with_alpha(Palette.ACCENT if b % 3 == 0 else Palette.TEAL, 0.45))

func _draw_chapel(detail: Color, floor_y: float) -> void:
	_line(200, 28, 200, 84, Palette.with_alpha(Palette.ACCENT, 0.55), 3)
	_line(180, 48, 220, 48, Palette.with_alpha(Palette.ACCENT, 0.55), 3)
	for i in range(3):
		_rect(52, floor_y - 32 + i * 11, 92, 5, Palette.darken(detail, 0.2))
		_rect(256, floor_y - 32 + i * 11, 92, 5, Palette.darken(detail, 0.2))

func _draw_outer_wall(detail: Color, floor_y: float) -> void:
	_rect(25, 34, 350, 52, Palette.darken(_tint, 0.7))
	for i in range(11):
		_line(34 + i * 33, 34, 34 + i * 33, 86, detail, 4)
	_line(20, 29, 380, 29, Palette.DANGER, 3)
	var sweep := 200.0 + sin(_time * 1.2) * 140.0
	_line(sweep, 34, sweep + 32, 86, Palette.with_alpha(Palette.ACCENT, 0.25), 5)

func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(points, color)
