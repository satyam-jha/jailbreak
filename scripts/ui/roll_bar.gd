class_name RollBar
extends Control
## The 1-100 strip under a check: critical success band, success band, failure
## band, critical failure band, and a marker where the die actually landed.

var result: CheckResult
var _reveal := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(queue_redraw)


func reveal() -> void:
	_reveal = true
	queue_redraw()


func _draw() -> void:
	if result == null or size.x < 4.0:
		return
	var h := size.y * 0.55
	var y := (size.y - h) * 0.5
	var w := size.x

	var function_of := func(value: int) -> float: return w * clampf(float(value) / 100.0, 0.0, 1.0)

	# Failure band fills the strip, then the successes are painted over it.
	draw_rect(Rect2(0, y, w, h), Palette.with_alpha(Palette.DANGER, 0.35), true)
	draw_rect(Rect2(0, y, function_of.call(result.final_chance), h), Palette.with_alpha(Palette.SUCCESS, 0.45), true)
	if result.crit_success_at > 0:
		draw_rect(Rect2(0, y, function_of.call(result.crit_success_at), h), Palette.with_alpha(Palette.SUCCESS_HI, 0.85), true)
	if result.crit_failure_at <= 100:
		var start: float = function_of.call(result.crit_failure_at - 1)
		draw_rect(Rect2(start, y, w - start, h), Palette.with_alpha(Palette.DANGER_DARK, 0.9), true)

	draw_rect(Rect2(0, y, w, h), Palette.BORDER, false, 1.0)

	if _reveal:
		var x: float = function_of.call(result.roll)
		draw_line(Vector2(x, y - 5), Vector2(x, y + h + 5), Palette.TEXT, 3.0, true)
		draw_circle(Vector2(x, y - 7), 4.0, result.tier_color())
