class_name CharacterPortrait
extends Control
## Draws a prisoner entirely in code, from the `visual` block in characters.json.
##
## There are no image files in this project. A character is a handful of named
## choices - body, hair, beard, glasses, hat, an extra - and this composes them
## into a chunky, thick-outlined cartoon. Adding a new hairstyle means adding a
## branch to _draw_hair() and a string to a character's JSON; every portrait in
## the game picks it up immediately.
##
## Everything is drawn in a 200x240 virtual space and scaled to fit the control,
## so the same portrait works as a 64px list thumbnail and a 320px hero image.

const VW := 200.0
const VH := 240.0

## Facial expressions. Statuses map onto these via expression_for_status().
const EXPRESSIONS := ["idle", "happy", "sad", "scared", "angry", "hurt", "tired", "worried", "out"]

var visual: Dictionary = {}
var expression: String = "idle":
	set(value):
		expression = value
		queue_redraw()
var show_body: bool = true
var show_background: bool = true
var animate: bool = false

var _time := 0.0
var _bob := 0.0
var _scale := 1.0
var _origin := Vector2.ZERO
var _ink := Palette.INK


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(90, 108)


func setup(p: Prisoner, expr: String = "") -> void:
	if p == null:
		return
	visual = p.visual
	expression = expr if not expr.is_empty() else expression_for_status(p.status)
	queue_redraw()


static func expression_for_status(status: String) -> String:
	match status:
		"injured": return "hurt"
		"scared": return "scared"
		"angry": return "angry"
		"exhausted": return "tired"
		"suspicious": return "worried"
		"unconscious": return "out"
		_: return "idle"


func _process(delta: float) -> void:
	if not animate:
		set_process(false)
		return
	_time += delta
	var next_bob := sin(_time * 1.7) * 2.4
	if absf(next_bob - _bob) > 0.08:
		_bob = next_bob
		queue_redraw()


func _ready() -> void:
	set_process(animate)
	resized.connect(queue_redraw)


## --- Virtual space helpers -----------------------------------------------

func _v(x: float, y: float) -> Vector2:
	return _origin + Vector2(x * _scale, (y + _bob) * _scale)


func _u(n: float) -> float:
	return n * _scale


func _ellipse(cx: float, cy: float, rx: float, ry: float, segments: int = 26) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(_v(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts


func _rounded(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	r = minf(r, minf(w, h) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		Vector2(x + w - r, y + r), Vector2(x + w - r, y + h - r),
		Vector2(x + r, y + h - r), Vector2(x + r, y + r),
	]
	var start_angles := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c in 4:
		for i in range(7):
			var a: float = start_angles[c] + (PI * 0.5) * (float(i) / 6.0)
			var p: Vector2 = corners[c]
			pts.append(_v(p.x + cos(a) * r, p.y + sin(a) * r))
	return pts


func _poly(points: PackedVector2Array, fill: Color, outline: bool = true, width: float = 3.0) -> void:
	if points.size() < 3:
		return
	draw_colored_polygon(points, fill)
	if outline:
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, _ink, _u(width), true)


func _stroke(points: PackedVector2Array, color: Color, width: float = 3.0) -> void:
	if points.size() < 2:
		return
	draw_polyline(points, color, _u(width), true)


func _line(x1: float, y1: float, x2: float, y2: float, color: Color, width: float = 3.0) -> void:
	draw_line(_v(x1, y1), _v(x2, y2), color, _u(width), true)


func _dot(cx: float, cy: float, r: float, color: Color) -> void:
	draw_circle(_v(cx, cy), _u(r), color)


## --- Look-up of the character's chosen parts -----------------------------

func _part(key: String, fallback: String) -> String:
	var value := str(visual.get(key, fallback))
	return fallback if value.is_empty() else value


func _skin() -> Color:
	return Palette.of(_part("skin", "#d8a878"), Color("#d8a878"))


func _hair_color() -> Color:
	return Palette.of(_part("hair_color", "#3a2a1c"), Color("#3a2a1c"))


func _uniform() -> Color:
	return Palette.of(_part("uniform", "#e2761f"), Palette.UNIFORM)


## Body proportions, chosen by the `body` field.
##
## Silhouette does nearly all the work of telling characters apart at thumbnail
## size, so shoulder width varies by more than a factor of two across the set,
## and heads are deliberately oversized - these are cartoons, not figures.
func _build() -> Dictionary:
	match _part("body", "normal"):
		"huge":   return {"head_r": 40.0, "head_y": 62.0, "shoulder": 104.0, "torso": 92.0, "neck": 30.0, "neck_len": 8.0}
		"wide":   return {"head_r": 37.0, "head_y": 66.0, "shoulder": 90.0,  "torso": 80.0, "neck": 25.0, "neck_len": 9.0}
		"thin":   return {"head_r": 33.0, "head_y": 70.0, "shoulder": 50.0,  "torso": 42.0, "neck": 13.0, "neck_len": 16.0}
		"short":  return {"head_r": 42.0, "head_y": 82.0, "shoulder": 66.0,  "torso": 60.0, "neck": 20.0, "neck_len": 6.0}
		_:        return {"head_r": 36.0, "head_y": 68.0, "shoulder": 70.0,  "torso": 62.0, "neck": 19.0, "neck_len": 12.0}


## --- Drawing -------------------------------------------------------------

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	_scale = minf(size.x / VW, size.y / VH)
	_origin = Vector2((size.x - VW * _scale) * 0.5, (size.y - VH * _scale) * 0.5)

	var build := _build()
	var head_y: float = build["head_y"]
	var head_r: float = build["head_r"]

	if show_background:
		_draw_background()
	if show_body:
		_draw_body(build)
	_draw_hair_back(head_y, head_r)
	_draw_head(head_y, head_r)
	_draw_beard(head_y, head_r)
	_draw_face(head_y, head_r)
	_draw_glasses(head_y, head_r)
	_draw_hair(head_y, head_r)
	_draw_hat(head_y, head_r)
	_draw_extra(head_y, head_r)


## A cell-wall backdrop: flat panel, subtle brick seam, and bars behind the head.
func _draw_background() -> void:
	_poly(_rounded(4, 4, VW - 8, VH - 8, 14), Palette.PANEL_DARK, false)
	var seam := Palette.with_alpha(Palette.BORDER, 0.30)
	for i in range(3):
		var y := 40.0 + i * 46.0
		draw_line(_v(10, y), _v(VW - 10, y), seam, _u(2.0), true)
	var bar := Palette.with_alpha(Palette.BORDER_HI, 0.35)
	for i in range(5):
		var x := 22.0 + i * 39.0
		draw_line(_v(x, 10), _v(x, VH - 10), bar, _u(5.0), true)


func _draw_body(build: Dictionary) -> void:
	var head_y: float = build["head_y"]
	var head_r: float = build["head_r"]
	var shoulder: float = build["shoulder"]
	var torso: float = build["torso"]
	var neck_w: float = build["neck"]
	var neck_len: float = build["neck_len"]

	var uniform := _uniform()
	var shade := Palette.darken(uniform, 0.30)
	var skin := _skin()

	var neck_top := head_y + head_r * 0.66
	var shoulder_y := neck_top + neck_len
	var body_top := shoulder_y + 12.0

	# Neck, drawn first so the torso and jaw both overlap it.
	_poly(_rounded(100 - neck_w * 0.5, neck_top, neck_w, neck_len + 12.0, neck_w * 0.30),
		Palette.darken(skin, 0.16), true, 2.6)

	# Torso: narrow at the collar, widest at the shoulders, tapering slightly in.
	var body := PackedVector2Array([
		_v(100 - torso * 0.30, shoulder_y - 2.0),
		_v(100 - shoulder * 0.50, body_top),
		_v(100 - torso * 0.52, VH - 2.0),
		_v(100 + torso * 0.52, VH - 2.0),
		_v(100 + shoulder * 0.50, body_top),
		_v(100 + torso * 0.30, shoulder_y - 2.0),
	])
	_poly(body, uniform, true, 3.4)

	# Prison stripes, inset to the body's half-width at each row so they never
	# spill past the outline.
	var stripe := Palette.with_alpha(shade, 0.70)
	var stripe_y := body_top + 20.0
	while stripe_y < VH - 10.0:
		var t: float = (stripe_y - body_top) / maxf(1.0, VH - body_top)
		var half: float = lerpf(shoulder * 0.50, torso * 0.52, t) - 6.0
		if half > 4.0:
			draw_line(_v(100 - half, stripe_y), _v(100 + half, stripe_y), stripe, _u(7.0), true)
		stripe_y += 19.0

	# Arms sit outside the torso silhouette with their own outlines, which is
	# what stops a character reading as a head balanced on a slab.
	var arm_w: float = maxf(11.0, shoulder * 0.21)
	var arm_top := body_top + 4.0
	var arm_len := VH - arm_top - 16.0
	for side_index in 2:
		var side := 1.0 if side_index == 1 else -1.0
		var arm_x := 100.0 + side * (shoulder * 0.50 - arm_w * 0.28)
		_poly(_rounded(arm_x - arm_w * 0.5, arm_top, arm_w, arm_len, arm_w * 0.45), shade, true, 3.0)
		_poly(_ellipse(arm_x, arm_top + arm_len, arm_w * 0.46, arm_w * 0.46, 14), skin, true, 2.6)

	# Collar and the prison number tag.
	_poly(PackedVector2Array([
		_v(100 - neck_w * 0.95, shoulder_y - 2.0),
		_v(100, shoulder_y + 18.0),
		_v(100 + neck_w * 0.95, shoulder_y - 2.0),
	]), Palette.darken(uniform, 0.22), true, 2.6)

	var tag_x := 100.0 + torso * 0.10
	var tag_y := body_top + 30.0
	_poly(_rounded(tag_x, tag_y, 32.0, 15.0, 3.0), Palette.of("#efe6d2"), true, 2.2)
	draw_line(_v(tag_x + 6, tag_y + 7.5), _v(tag_x + 26, tag_y + 7.5), _ink, _u(2.0), true)


func _draw_head(head_y: float, head_r: float) -> void:
	var skin := _skin()
	# Ears first, so the head outline overlaps them slightly.
	_poly(_ellipse(100 - head_r * 0.96, head_y + head_r * 0.12, head_r * 0.20, head_r * 0.28, 14), Palette.darken(skin, 0.10), true, 2.5)
	_poly(_ellipse(100 + head_r * 0.96, head_y + head_r * 0.12, head_r * 0.20, head_r * 0.28, 14), Palette.darken(skin, 0.10), true, 2.5)
	# The head is slightly taller than wide, with a rounded jaw.
	_poly(_ellipse(100, head_y, head_r, head_r * 1.10, 30), skin)


func _draw_face(head_y: float, head_r: float) -> void:
	var eye_y := head_y - head_r * 0.10
	var eye_dx := head_r * 0.40
	var eye_style := _part("eyes", "normal")
	var skin := _skin()

	# Eyes
	if expression == "out":
		for side_index in 2:
			var side := 1.0 if side_index == 1 else -1.0
			var cx := 100.0 + side * eye_dx
			_line(cx - 6, eye_y - 6, cx + 6, eye_y + 6, _ink, 3.0)
			_line(cx + 6, eye_y - 6, cx - 6, eye_y + 6, _ink, 3.0)
	else:
		var eye_rx := head_r * 0.22
		var eye_ry := head_r * 0.24
		match eye_style:
			"beady":
				eye_rx = head_r * 0.15
				eye_ry = head_r * 0.16
			"wide":
				eye_rx = head_r * 0.27
				eye_ry = head_r * 0.30
			"sharp":
				eye_rx = head_r * 0.25
				eye_ry = head_r * 0.16
			"tired":
				eye_rx = head_r * 0.23
				eye_ry = head_r * 0.18
			"dot":
				eye_rx = head_r * 0.10
				eye_ry = head_r * 0.10
		if expression == "scared":
			eye_rx *= 1.25
			eye_ry *= 1.35
		elif expression == "tired":
			eye_ry *= 0.6

		for side_index in 2:
			var side := 1.0 if side_index == 1 else -1.0
			var cx := 100.0 + side * eye_dx
			_poly(_ellipse(cx, eye_y, eye_rx, eye_ry, 16), Color("#fdfdfd"), true, 2.0)
			var pupil_dx := 0.0
			var pupil_dy := 0.0
			if expression == "worried":
				pupil_dx = side * eye_rx * 0.35
			elif expression == "happy":
				pupil_dy = -eye_ry * 0.15
			elif expression == "sad" or expression == "hurt":
				pupil_dy = eye_ry * 0.25
			_dot(cx + pupil_dx, eye_y + pupil_dy, maxf(1.2, eye_ry * 0.52), _ink)
			if eye_style == "tired" or expression == "tired":
				_line(cx - eye_rx, eye_y - eye_ry * 0.4, cx + eye_rx, eye_y - eye_ry * 0.6, _ink, 2.0)

	# Brows - the single biggest contributor to a readable expression.
	var brow_y := eye_y - head_r * 0.40
	var brow_style := _part("brow", "normal")
	if expression == "angry":
		brow_style = "angry"
	elif expression == "scared" or expression == "worried" or expression == "hurt":
		brow_style = "worried"
	elif expression == "happy":
		brow_style = "raised"

	for side_index in 2:
		var side := 1.0 if side_index == 1 else -1.0
		var cx := 100.0 + side * eye_dx
		var inner := cx - side * head_r * 0.20
		var outer := cx + side * head_r * 0.22
		var inner_y := brow_y
		var outer_y := brow_y
		match brow_style:
			"angry":
				inner_y = brow_y + head_r * 0.14
				outer_y = brow_y - head_r * 0.08
			"worried":
				inner_y = brow_y - head_r * 0.12
				outer_y = brow_y + head_r * 0.10
			"raised":
				inner_y = brow_y - head_r * 0.10
				outer_y = brow_y - head_r * 0.12
		_line(inner, inner_y, outer, outer_y, _hair_color(), 3.4)

	# Nose
	var nose_y := head_y + head_r * 0.22
	_stroke(PackedVector2Array([
		_v(100 - head_r * 0.06, nose_y - head_r * 0.12),
		_v(100 - head_r * 0.12, nose_y + head_r * 0.10),
		_v(100 + head_r * 0.06, nose_y + head_r * 0.12),
	]), Palette.darken(skin, 0.35), 2.6)

	_draw_mouth(head_y, head_r)


func _draw_mouth(head_y: float, head_r: float) -> void:
	var my := head_y + head_r * 0.58
	var w := head_r * 0.42
	match expression:
		"happy":
			var pts := PackedVector2Array()
			for i in range(11):
				var t := float(i) / 10.0
				pts.append(_v(100 - w + 2 * w * t, my + sin(t * PI) * head_r * 0.30))
			_poly(_append_mirror(pts, my), Palette.of("#8e3b3b"), true, 2.6)
		"sad", "hurt":
			var pts2 := PackedVector2Array()
			for i in range(11):
				var t2 := float(i) / 10.0
				pts2.append(_v(100 - w + 2 * w * t2, my + head_r * 0.12 - sin(t2 * PI) * head_r * 0.20))
			_stroke(pts2, _ink, 3.0)
		"scared":
			_poly(_ellipse(100, my + head_r * 0.06, head_r * 0.17, head_r * 0.22, 16), Palette.of("#6e2e2e"))
		"angry":
			var jag := PackedVector2Array()
			for i in range(7):
				var t3 := float(i) / 6.0
				jag.append(_v(100 - w + 2 * w * t3, my + (head_r * 0.10 if i % 2 == 0 else -head_r * 0.06)))
			_stroke(jag, _ink, 3.0)
		"out":
			_poly(_ellipse(100, my + head_r * 0.06, head_r * 0.22, head_r * 0.16, 16), Palette.of("#6e2e2e"))
		"tired":
			_line(100 - w * 0.7, my, 100 + w * 0.7, my + head_r * 0.06, _ink, 3.0)
		"worried":
			var sq := PackedVector2Array()
			for i in range(9):
				var t4 := float(i) / 8.0
				sq.append(_v(100 - w + 2 * w * t4, my + sin(t4 * TAU) * head_r * 0.06))
			_stroke(sq, _ink, 2.8)
		_:
			var pts3 := PackedVector2Array()
			for i in range(9):
				var t5 := float(i) / 8.0
				pts3.append(_v(100 - w * 0.8 + 1.6 * w * t5, my + sin(t5 * PI) * head_r * 0.12))
			_stroke(pts3, _ink, 3.0)

	if _part("extra", "none") == "tooth_gap" and (expression == "happy" or expression == "idle"):
		_poly(_rounded(97.0, my - 1.0, 6.0, 8.0, 1.0), Color("#fdfdfd"), true, 1.6)


## Closes an open arc into a filled lens shape (used for the open smile).
func _append_mirror(pts: PackedVector2Array, baseline_y: float) -> PackedVector2Array:
	var out := pts.duplicate()
	for i in range(pts.size() - 1, -1, -1):
		var p: Vector2 = pts[i]
		out.append(Vector2(p.x, _v(0, baseline_y).y))
	return out


func _draw_hair_back(head_y: float, head_r: float) -> void:
	var style := _part("hair", "short")
	var hc := _hair_color()
	match style:
		"afro":
			_poly(_ellipse(100, head_y - head_r * 0.22, head_r * 1.38, head_r * 1.26, 26), hc)
		"long":
			_poly(_rounded(100 - head_r * 1.16, head_y - head_r * 0.55, head_r * 2.32, head_r * 2.05, head_r * 0.7), hc)
		"braids":
			for side_index in 2:
				var side := 1.0 if side_index == 1 else -1.0
				_poly(_rounded(100 + side * head_r * 1.02 - head_r * 0.16, head_y - head_r * 0.1, head_r * 0.32, head_r * 1.5, head_r * 0.16), hc)
				_dot(100 + side * head_r * 1.02, head_y + head_r * 1.42, head_r * 0.16, Palette.ACCENT)


func _draw_hair(head_y: float, head_r: float) -> void:
	var style := _part("hair", "short")
	var hc := _hair_color()
	var cap_y := head_y - head_r * 0.36

	match style:
		"none", "bald":
			var shine := Palette.with_alpha(Palette.lighten(_skin(), 0.5), 0.5)
			draw_arc(_v(100 - head_r * 0.22, head_y - head_r * 0.42), _u(head_r * 0.26), -2.4, -0.9, 10, shine, _u(3.0), true)
		"buzz":
			_poly(_cap(head_y, head_r, 0.52), Palette.with_alpha(hc, 0.85), true, 2.2)
		"short":
			_poly(_cap(head_y, head_r, 0.72), hc)
		"receding":
			var pts := PackedVector2Array()
			for i in range(15):
				var a := PI + PI * float(i) / 14.0
				pts.append(_v(100 + cos(a) * head_r * 1.03, head_y + sin(a) * head_r * 1.03))
			pts.append(_v(100 + head_r * 0.60, head_y - head_r * 0.42))
			pts.append(_v(100 + head_r * 0.30, head_y - head_r * 0.78))
			pts.append(_v(100, head_y - head_r * 0.46))
			pts.append(_v(100 - head_r * 0.30, head_y - head_r * 0.78))
			pts.append(_v(100 - head_r * 0.60, head_y - head_r * 0.42))
			_poly(pts, hc)
		"messy":
			_poly(_cap(head_y, head_r, 0.80), hc)
			for i in range(6):
				var x := 100 - head_r * 0.9 + head_r * 0.36 * i
				var h := head_r * (0.30 + 0.18 * ((i * 7) % 3))
				_poly(PackedVector2Array([
					_v(x - head_r * 0.13, cap_y - head_r * 0.42),
					_v(x + head_r * 0.05, cap_y - head_r * 0.42 - h),
					_v(x + head_r * 0.20, cap_y - head_r * 0.36),
				]), hc, true, 2.0)
		"spiky":
			_poly(_cap(head_y, head_r, 0.66), hc)
			for i in range(5):
				var x2 := 100 - head_r * 0.78 + head_r * 0.39 * i
				_poly(PackedVector2Array([
					_v(x2 - head_r * 0.19, cap_y - head_r * 0.30),
					_v(x2, cap_y - head_r * 0.98),
					_v(x2 + head_r * 0.19, cap_y - head_r * 0.30),
				]), hc, true, 2.2)
		"mohawk":
			for i in range(5):
				var y := head_y - head_r * (1.02 - 0.02 * i)
				_poly(PackedVector2Array([
					_v(100 - head_r * 0.17, y + head_r * 0.20),
					_v(100 - head_r * 0.05, y - head_r * (0.30 + 0.10 * abs(2 - i))),
					_v(100 + head_r * 0.17, y + head_r * 0.20),
				]), hc, true, 2.0)
			_poly(_rounded(100 - head_r * 0.18, head_y - head_r * 1.05, head_r * 0.36, head_r * 0.7, head_r * 0.1), hc)
		"slick":
			_poly(_cap(head_y, head_r, 0.74), hc)
			_stroke(PackedVector2Array([
				_v(100 - head_r * 0.76, head_y - head_r * 0.62),
				_v(100 - head_r * 0.10, head_y - head_r * 0.92),
				_v(100 + head_r * 0.72, head_y - head_r * 0.58),
			]), Palette.lighten(hc, 0.35), 3.0)
		"bun":
			_poly(_cap(head_y, head_r, 0.78), hc)
			_poly(_ellipse(100, head_y - head_r * 1.24, head_r * 0.40, head_r * 0.36, 18), hc)
		"long", "braids", "afro":
			_poly(_cap(head_y, head_r, 0.80), hc)
		_:
			_poly(_cap(head_y, head_r, 0.72), hc)


## The top-of-head skullcap shared by most hairstyles.
func _cap(head_y: float, head_r: float, depth: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := head_r * 1.04
	for i in range(19):
		var a := PI + PI * float(i) / 18.0
		pts.append(_v(100 + cos(a) * r, head_y + sin(a) * r * 1.06))
	pts.append(_v(100 + r * 0.98, head_y + head_r * (depth - 0.55)))
	pts.append(_v(100, head_y - head_r * (0.20 - depth * 0.30)))
	pts.append(_v(100 - r * 0.98, head_y + head_r * (depth - 0.55)))
	return pts


func _draw_beard(head_y: float, head_r: float) -> void:
	var style := _part("beard", "none")
	if style == "none":
		return
	var hc := Palette.darken(_hair_color(), 0.08)
	var jaw_y := head_y + head_r * 0.48

	match style:
		"stubble":
			var shade := Palette.with_alpha(hc, 0.28)
			for row in range(3):
				for col in range(9):
					var x := 100 - head_r * 0.64 + head_r * 0.16 * col
					var y := jaw_y + head_r * 0.10 * row
					if absf(x - 100) < head_r * 0.72:
						_dot(x, y, head_r * 0.045, shade)
		"mustache":
			_poly(PackedVector2Array([
				_v(100 - head_r * 0.40, jaw_y - head_r * 0.24),
				_v(100, jaw_y - head_r * 0.34),
				_v(100 + head_r * 0.40, jaw_y - head_r * 0.24),
				_v(100 + head_r * 0.30, jaw_y - head_r * 0.06),
				_v(100, jaw_y - head_r * 0.14),
				_v(100 - head_r * 0.30, jaw_y - head_r * 0.06),
			]), hc, true, 2.2)
		"goatee":
			_poly(_rounded(100 - head_r * 0.22, jaw_y + head_r * 0.02, head_r * 0.44, head_r * 0.60, head_r * 0.18), hc, true, 2.2)
		"full":
			_poly(PackedVector2Array([
				_v(100 - head_r * 0.94, jaw_y - head_r * 0.34),
				_v(100 - head_r * 0.78, jaw_y + head_r * 0.62),
				_v(100, jaw_y + head_r * 0.86),
				_v(100 + head_r * 0.78, jaw_y + head_r * 0.62),
				_v(100 + head_r * 0.94, jaw_y - head_r * 0.34),
				_v(100 + head_r * 0.40, jaw_y - head_r * 0.10),
				_v(100, jaw_y - head_r * 0.20),
				_v(100 - head_r * 0.40, jaw_y - head_r * 0.10),
			]), hc)
		"long":
			_poly(PackedVector2Array([
				_v(100 - head_r * 0.92, jaw_y - head_r * 0.30),
				_v(100 - head_r * 0.58, jaw_y + head_r * 1.15),
				_v(100, jaw_y + head_r * 1.45),
				_v(100 + head_r * 0.58, jaw_y + head_r * 1.15),
				_v(100 + head_r * 0.92, jaw_y - head_r * 0.30),
				_v(100, jaw_y - head_r * 0.16),
			]), hc)


func _draw_glasses(head_y: float, head_r: float) -> void:
	var style := _part("glasses", "none")
	if style == "none":
		return
	var eye_y := head_y - head_r * 0.10
	var dx := head_r * 0.40
	var frame := Palette.of("#2b3140")

	match style:
		"round":
			for side_index in 2:
				var side := 1.0 if side_index == 1 else -1.0
				draw_arc(_v(100 + side * dx, eye_y), _u(head_r * 0.33), 0, TAU, 22, frame, _u(3.0), true)
			_line(100 - dx * 0.36, eye_y, 100 + dx * 0.36, eye_y, frame, 3.0)
		"square":
			for side_index in 2:
				var side2 := 1.0 if side_index == 1 else -1.0
				_stroke(_close(_rounded(100 + side2 * dx - head_r * 0.32, eye_y - head_r * 0.26, head_r * 0.64, head_r * 0.52, head_r * 0.08)), frame, 3.0)
			_line(100 - dx * 0.34, eye_y, 100 + dx * 0.34, eye_y, frame, 3.0)
		"shades":
			for side_index in 2:
				var side3 := 1.0 if side_index == 1 else -1.0
				_poly(_rounded(100 + side3 * dx - head_r * 0.36, eye_y - head_r * 0.26, head_r * 0.72, head_r * 0.50, head_r * 0.10), Palette.of("#1b1f2a"), true, 2.4)
			_line(100 - dx * 0.34, eye_y - head_r * 0.06, 100 + dx * 0.34, eye_y - head_r * 0.06, frame, 3.0)
		"monocle":
			draw_arc(_v(100 + dx, eye_y), _u(head_r * 0.34), 0, TAU, 22, Palette.ACCENT, _u(3.0), true)
			_line(100 + dx, eye_y + head_r * 0.34, 100 + dx * 1.5, eye_y + head_r * 0.9, Palette.ACCENT, 2.0)

	# Arms of the glasses, back toward the ears.
	for side_index in 2:
		var side4 := 1.0 if side_index == 1 else -1.0
		_line(100 + side4 * head_r * 0.72, eye_y - head_r * 0.06, 100 + side4 * head_r * 0.98, eye_y - head_r * 0.02, frame, 2.4)


func _close(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out


func _draw_hat(head_y: float, head_r: float) -> void:
	var style := _part("hat", "none")
	if style == "none":
		return
	var top := head_y - head_r * 1.02

	match style:
		"beanie":
			_poly(_rounded(100 - head_r * 1.08, top - head_r * 0.34, head_r * 2.16, head_r * 0.86, head_r * 0.36), Palette.of("#4f5f8a"))
			_poly(_rounded(100 - head_r * 1.12, top + head_r * 0.30, head_r * 2.24, head_r * 0.28, head_r * 0.10), Palette.of("#39456a"))
		"cap":
			_poly(_rounded(100 - head_r * 1.02, top - head_r * 0.26, head_r * 2.04, head_r * 0.72, head_r * 0.34), Palette.of("#3f6b57"))
			_poly(_rounded(100 - head_r * 0.10, top + head_r * 0.28, head_r * 1.50, head_r * 0.22, head_r * 0.10), Palette.of("#2f5443"))
		"hardhat":
			_poly(_ellipse(100, top + head_r * 0.20, head_r * 1.04, head_r * 0.64, 22), Palette.of("#e3c13a"))
			_poly(_rounded(100 - head_r * 1.26, top + head_r * 0.14, head_r * 2.52, head_r * 0.24, head_r * 0.10), Palette.of("#c9a72c"))
			_line(100, top - head_r * 0.34, 100, top + head_r * 0.18, Palette.of("#a98d22"), 2.4)
		"bandana":
			_poly(_rounded(100 - head_r * 1.06, top + head_r * 0.06, head_r * 2.12, head_r * 0.46, head_r * 0.10), Palette.of("#8f4a5c"))
			_poly(PackedVector2Array([
				_v(100 + head_r * 1.02, top + head_r * 0.18),
				_v(100 + head_r * 1.50, top + head_r * 0.46),
				_v(100 + head_r * 1.02, top + head_r * 0.54),
			]), Palette.of("#7a3b4c"), true, 2.2)
		"headband":
			_poly(_rounded(100 - head_r * 1.06, head_y - head_r * 0.82, head_r * 2.12, head_r * 0.30, head_r * 0.08), Palette.of("#d9534f"))
		"chef":
			_poly(_rounded(100 - head_r * 0.86, top - head_r * 0.94, head_r * 1.72, head_r * 1.10, head_r * 0.42), Palette.of("#f2f1ea"))
			_poly(_rounded(100 - head_r * 0.94, top + head_r * 0.04, head_r * 1.88, head_r * 0.32, head_r * 0.08), Palette.of("#dedcd2"))
		"visor":
			_poly(_rounded(100 - head_r * 1.06, top + head_r * 0.16, head_r * 2.12, head_r * 0.28, head_r * 0.08), Palette.of("#2f3a52"))
			_poly(_rounded(100 - head_r * 1.24, top + head_r * 0.36, head_r * 2.48, head_r * 0.42, head_r * 0.18), Palette.with_alpha(Palette.TEAL, 0.55), true, 2.2)


func _draw_extra(head_y: float, head_r: float) -> void:
	match _part("extra", "none"):
		"scar":
			_line(100 + head_r * 0.52, head_y - head_r * 0.52, 100 + head_r * 0.74, head_y + head_r * 0.10, Palette.of("#a8574f"), 2.6)
			_line(100 + head_r * 0.50, head_y - head_r * 0.26, 100 + head_r * 0.78, head_y - head_r * 0.20, Palette.of("#a8574f"), 2.0)
		"earring":
			_dot(100 + head_r * 1.00, head_y + head_r * 0.36, head_r * 0.10, Palette.ACCENT)
		"bandage":
			_poly(_rounded(100 - head_r * 0.70, head_y - head_r * 0.92, head_r * 1.10, head_r * 0.26, head_r * 0.06), Palette.of("#efe6d2"), true, 2.0)
			_line(100 - head_r * 0.56, head_y - head_r * 0.86, 100 + head_r * 0.30, head_y - head_r * 0.74, Palette.of("#cfc5b0"), 1.8)
		"freckles":
			for i in range(6):
				var side: float = -1.0 if i < 3 else 1.0
				var x := 100 + side * (head_r * 0.52 + (i % 3) * head_r * 0.12)
				_dot(x, head_y + head_r * 0.26 + (i % 2) * head_r * 0.10, head_r * 0.045, Palette.darken(_skin(), 0.30))
		"tattoo":
			if show_body:
				var build := _build()
				var shoulder: float = build["shoulder"]
				var arm_w: float = maxf(11.0, shoulder * 0.21)
				var arm_x: float = 100.0 - (shoulder * 0.50 - arm_w * 0.28)
				var ink := Palette.with_alpha(Palette.of("#2f4a6b"), 0.85)
				draw_arc(_v(arm_x, 186), _u(arm_w * 0.30), 0, TAU, 14, ink, _u(2.2), true)
				_line(arm_x - arm_w * 0.26, 178, arm_x + arm_w * 0.26, 194, ink, 2.2)
