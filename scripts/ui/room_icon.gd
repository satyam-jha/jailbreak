class_name RoomIcon
extends Control
## A tiny drawn glyph per room type. Keeps the map readable at a glance without
## shipping an icon atlas.

var icon: String = "bars"
var color: Color = Palette.TEXT_DIM


func _init(icon_name: String = "bars", tint: Color = Palette.TEXT_DIM) -> void:
	icon = icon_name
	color = tint
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(26, 26)


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	if s < 4.0:
		return
	var o := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5)
	var w: float = maxf(1.5, s * 0.10)

	match icon:
		"bars":
			for i in range(4):
				var x := o.x + s * (0.18 + 0.21 * i)
				draw_line(Vector2(x, o.y + s * 0.12), Vector2(x, o.y + s * 0.88), color, w)
		"tray":
			draw_rect(Rect2(o + Vector2(s * 0.12, s * 0.30), Vector2(s * 0.76, s * 0.42)), color, false, w)
			draw_line(o + Vector2(s * 0.38, s * 0.30), o + Vector2(s * 0.38, s * 0.72), color, w * 0.7)
		"sun":
			draw_arc(o + Vector2(s * 0.5, s * 0.5), s * 0.22, 0, TAU, 18, color, w, true)
			for i in range(8):
				var a := TAU * float(i) / 8.0
				var dir := Vector2(cos(a), sin(a))
				draw_line(o + Vector2(s * 0.5, s * 0.5) + dir * s * 0.30,
					o + Vector2(s * 0.5, s * 0.5) + dir * s * 0.42, color, w * 0.8)
		"shirt":
			draw_line(o + Vector2(s * 0.20, s * 0.24), o + Vector2(s * 0.36, s * 0.16), color, w)
			draw_line(o + Vector2(s * 0.80, s * 0.24), o + Vector2(s * 0.64, s * 0.16), color, w)
			draw_rect(Rect2(o + Vector2(s * 0.24, s * 0.24), Vector2(s * 0.52, s * 0.58)), color, false, w)
		"wrench":
			draw_line(o + Vector2(s * 0.24, s * 0.78), o + Vector2(s * 0.70, s * 0.30), color, w * 1.4)
			draw_arc(o + Vector2(s * 0.74, s * 0.26), s * 0.14, 0.6, 5.4, 14, color, w, true)
		"cross":
			draw_line(o + Vector2(s * 0.5, s * 0.16), o + Vector2(s * 0.5, s * 0.84), color, w * 1.5)
			draw_line(o + Vector2(s * 0.16, s * 0.5), o + Vector2(s * 0.84, s * 0.5), color, w * 1.5)
		"badge":
			draw_colored_polygon(PackedVector2Array([
				o + Vector2(s * 0.5, s * 0.12), o + Vector2(s * 0.86, s * 0.34),
				o + Vector2(s * 0.72, s * 0.86), o + Vector2(s * 0.28, s * 0.86),
				o + Vector2(s * 0.14, s * 0.34)]), Palette.with_alpha(color, 0.35))
			draw_arc(o + Vector2(s * 0.5, s * 0.5), s * 0.16, 0, TAU, 14, color, w, true)
		"screen":
			draw_rect(Rect2(o + Vector2(s * 0.12, s * 0.20), Vector2(s * 0.76, s * 0.48)), color, false, w)
			draw_line(o + Vector2(s * 0.5, s * 0.68), o + Vector2(s * 0.5, s * 0.84), color, w)
			draw_line(o + Vector2(s * 0.30, s * 0.84), o + Vector2(s * 0.70, s * 0.84), color, w)
		"gear":
			draw_arc(o + Vector2(s * 0.5, s * 0.5), s * 0.24, 0, TAU, 20, color, w, true)
			for i in range(6):
				var ga := TAU * float(i) / 6.0
				var gd := Vector2(cos(ga), sin(ga))
				draw_line(o + Vector2(s * 0.5, s * 0.5) + gd * s * 0.26,
					o + Vector2(s * 0.5, s * 0.5) + gd * s * 0.42, color, w * 1.1)
		"pipe":
			draw_line(o + Vector2(s * 0.10, s * 0.34), o + Vector2(s * 0.58, s * 0.34), color, w * 1.6)
			draw_line(o + Vector2(s * 0.58, s * 0.34), o + Vector2(s * 0.58, s * 0.86), color, w * 1.6)
			draw_rect(Rect2(o + Vector2(s * 0.46, s * 0.26), Vector2(s * 0.24, s * 0.16)), color, false, w * 0.7)
		"book":
			draw_rect(Rect2(o + Vector2(s * 0.16, s * 0.18), Vector2(s * 0.68, s * 0.64)), color, false, w)
			draw_line(o + Vector2(s * 0.5, s * 0.18), o + Vector2(s * 0.5, s * 0.82), color, w * 0.8)
		"candle":
			draw_rect(Rect2(o + Vector2(s * 0.40, s * 0.40), Vector2(s * 0.20, s * 0.44)), color, false, w)
			draw_colored_polygon(PackedVector2Array([
				o + Vector2(s * 0.50, s * 0.12), o + Vector2(s * 0.60, s * 0.34),
				o + Vector2(s * 0.40, s * 0.34)]), Palette.with_alpha(Palette.ACCENT, 0.85))
		"wall":
			for row in range(3):
				var y := o.y + s * (0.24 + 0.22 * row)
				draw_line(Vector2(o.x + s * 0.10, y), Vector2(o.x + s * 0.90, y), color, w)
				var offset: float = 0.0 if row % 2 == 0 else s * 0.16
				draw_line(Vector2(o.x + s * 0.32 + offset, y), Vector2(o.x + s * 0.32 + offset, y + s * 0.22), color, w * 0.7)
		"flame":
			draw_colored_polygon(PackedVector2Array([
				o + Vector2(s * 0.50, s * 0.10), o + Vector2(s * 0.78, s * 0.54),
				o + Vector2(s * 0.62, s * 0.88), o + Vector2(s * 0.38, s * 0.88),
				o + Vector2(s * 0.22, s * 0.54)]), Palette.with_alpha(color, 0.75))
		"star":
			var pts := PackedVector2Array()
			for i in range(10):
				var sa := -PI * 0.5 + TAU * float(i) / 10.0
				var r: float = s * (0.42 if i % 2 == 0 else 0.18)
				pts.append(o + Vector2(s * 0.5, s * 0.5) + Vector2(cos(sa), sin(sa)) * r)
			draw_colored_polygon(pts, Palette.with_alpha(color, 0.8))
		_:
			draw_arc(o + Vector2(s * 0.5, s * 0.5), s * 0.30, 0, TAU, 18, color, w, true)
