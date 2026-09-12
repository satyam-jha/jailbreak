class_name Backdrop
extends Control
## The drifting prison-block backdrop that sits behind every screen.
##
## Drawn rather than tiled: a few dozen lines and rectangles, re-tinted per
## screen, which costs nothing and means the game never shows a flat grey void.

var mood: String = "main_menu"
var _time := 0.0
var _tint := Palette.PANEL


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_process(true)
	resized.connect(queue_redraw)


func set_mood(screen_name: String) -> void:
	mood = screen_name
	match screen_name:
		"encounter": _tint = Color("#233043")
		"map": _tint = Color("#1d2736")
		"powerup": _tint = Color("#2a2740")
		"escape": _tint = Color("#33242a")
		"summary": _tint = Color("#242b3a")
		_: _tint = Color("#1e2534")
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if fmod(_time, 0.12) < delta:
		queue_redraw()


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return

	# A soft vertical wash so the top of the screen reads darker than the floor.
	for i in range(14):
		var t := float(i) / 13.0
		var band := Rect2(0, size.y * t, size.x, size.y / 13.0 + 1.0)
		draw_rect(band, Palette.with_alpha(_tint, 0.10 + 0.05 * t), true)

	# Cell bars, drifting very slowly sideways.
	var drift: float = fmod(_time * 5.0, 90.0)
	var bar_color := Palette.with_alpha(Palette.BORDER, 0.16)
	var x := -90.0 + drift
	while x < size.x + 90.0:
		draw_line(Vector2(x, 0), Vector2(x, size.y), bar_color, 7.0)
		x += 90.0

	# Floor line and a couple of pipes along the top.
	var floor_y := size.y * 0.82
	draw_line(Vector2(0, floor_y), Vector2(size.x, floor_y), Palette.with_alpha(Palette.BORDER_HI, 0.18), 3.0)
	for i in range(2):
		var y := 26.0 + i * 18.0
		draw_line(Vector2(0, y), Vector2(size.x, y), Palette.with_alpha(Palette.BORDER, 0.22), 6.0)

	# A slow sweeping searchlight, brighter when the prison is agitated.
	var intensity := 0.03
	if not Game.party.is_empty():
		intensity = lerpf(0.02, 0.10, clampf(float(Game.heat) / 100.0, 0.0, 1.0))
	var sweep: float = (sin(_time * 0.35) * 0.5 + 0.5) * size.x
	var light := PackedVector2Array([
		Vector2(sweep, -20.0),
		Vector2(sweep + 150.0, size.y),
		Vector2(sweep - 150.0, size.y),
	])
	draw_colored_polygon(light, Palette.with_alpha(Palette.ACCENT, intensity))
