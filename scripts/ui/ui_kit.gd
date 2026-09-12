class_name UIKit
extends RefCounted
## Small factory functions for the controls the screens build repeatedly.
##
## Screens are constructed in code rather than as .tscn files: the layouts here
## are mostly lists and grids driven by data, so building them in a loop is both
## shorter and easier to keep in step with the JSON than hand-wiring nodes.

const TOUCH_HEIGHT := 52   ## minimum tappable height, for the eventual mobile build


static func stylebox(bg: Color, border: Color = Palette.BORDER, radius: int = 10, border_width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16

	var normal := stylebox(Palette.PANEL_HI, Palette.BORDER, 10, 2)
	var hover := stylebox(Palette.lighten(Palette.PANEL_HI, 0.10), Palette.ACCENT, 10, 2)
	var pressed := stylebox(Palette.darken(Palette.PANEL_HI, 0.20), Palette.ACCENT_DARK, 10, 2)
	var disabled := stylebox(Palette.PANEL_DARK, Palette.darken(Palette.BORDER, 0.3), 10, 2)
	var focus := stylebox(Palette.with_alpha(Palette.ACCENT, 0.08), Palette.ACCENT, 10, 2)

	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", Palette.TEXT)
	theme.set_color("font_hover_color", "Button", Palette.ACCENT)
	theme.set_color("font_pressed_color", "Button", Palette.ACCENT)
	theme.set_color("font_disabled_color", "Button", Palette.TEXT_FAINT)
	theme.set_font_size("font_size", "Button", 17)

	theme.set_color("font_color", "Label", Palette.TEXT)
	theme.set_color("font_color", "RichTextLabel", Palette.TEXT)
	theme.set_stylebox("panel", "PanelContainer", stylebox(Palette.PANEL))
	theme.set_stylebox("focus", "PanelContainer", StyleBoxEmpty.new())

	theme.set_constant("separation", "HBoxContainer", 12)
	theme.set_constant("separation", "VBoxContainer", 10)

	theme.set_color("font_color", "CheckBox", Palette.TEXT)
	theme.set_color("font_color", "HSlider", Palette.TEXT)
	return theme


## --- Labels --------------------------------------------------------------

## Word wrapping is OFF by default and must be asked for.
##
## A wrapping Label reports a minimum width of one pixel, so inside a horizontal
## container it collapses to a one-character column hundreds of pixels tall and
## drags the whole row with it. Use paragraph() for prose, label() for anything
## that sits in a row.
static func label(text: String, size: int = 16, color: Color = Palette.TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


## Prose that should wrap. Always give it room to be wide: put it in a vertical
## container, or set size_flags_horizontal to expand.
static func paragraph(text: String, size: int = 16, color: Color = Palette.TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, size, color, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func title(text: String, size: int = 38, color: Color = Palette.TEXT) -> Label:
	var l := label(text, size, color)
	l.add_theme_constant_override("outline_size", 0)
	return l


static func body(text: String, size: int = 16) -> Label:
	return paragraph(text, size, Palette.TEXT_DIM)


## --- Containers ----------------------------------------------------------

static func panel(bg: Color = Palette.PANEL, border: Color = Palette.BORDER, radius: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", stylebox(bg, border, radius))
	return p


static func vbox(separation: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func spacer(height: int = 0, width: int = 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, height)
	if height == 0 and width == 0:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


static func margin(all: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", all)
	m.add_theme_constant_override("margin_right", all)
	m.add_theme_constant_override("margin_top", all)
	m.add_theme_constant_override("margin_bottom", all)
	return m


## --- Buttons -------------------------------------------------------------

static func button(text: String, size: int = 17, min_height: int = TOUCH_HEIGHT) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = min_height
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_ALL
	return b


static func primary_button(text: String, size: int = 20) -> Button:
	var b := button(text, size, 60)
	b.add_theme_stylebox_override("normal", stylebox(Palette.ACCENT_DARK, Palette.ACCENT, 12))
	b.add_theme_stylebox_override("hover", stylebox(Palette.ACCENT, Palette.ACCENT, 12))
	b.add_theme_stylebox_override("pressed", stylebox(Palette.darken(Palette.ACCENT_DARK, 0.25), Palette.ACCENT, 12))
	b.add_theme_color_override("font_color", Palette.BG_DEEP)
	b.add_theme_color_override("font_hover_color", Palette.BG_DEEP)
	b.add_theme_color_override("font_pressed_color", Palette.BG_DEEP)
	return b


## --- Small display widgets -----------------------------------------------

## A coloured pill, used for traits, tags and statuses.
static func chip(text: String, color: Color, text_color: Color = Color.WHITE) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := stylebox(Palette.with_alpha(color, 0.18), Palette.with_alpha(color, 0.85), 999, 1)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var l := label(text, 13, text_color if text_color != Color.WHITE else Palette.lighten(color, 0.45))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	return p


## A labelled horizontal bar, used for stats and Heat.
static func stat_bar(stat: String, value: int, max_value: int = 10, delta: int = 0, width: int = 110) -> Control:
	var row := hbox(8)
	var name_label := label(Content.stat_label(stat), 13, Palette.TEXT_DIM)
	name_label.custom_minimum_size.x = 36
	row.add_child(name_label)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max_value
	bar.value = clampi(value, 0, max_value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := stylebox(Palette.PANEL_DARK, Palette.PANEL_DARK, 6, 0)
	bg.content_margin_left = 0
	bg.content_margin_right = 0
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	var fill := stylebox(Palette.stat_color(stat), Palette.stat_color(stat), 6, 0)
	fill.content_margin_left = 0
	fill.content_margin_right = 0
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)

	var value_text := str(value)
	var value_color := Palette.TEXT
	if delta > 0:
		value_text += " (+%d)" % delta
		value_color = Palette.SUCCESS
	elif delta < 0:
		value_text += " (%d)" % delta
		value_color = Palette.DANGER
	var value_label := label(value_text, 13, value_color)
	value_label.custom_minimum_size.x = 52
	row.add_child(value_label)
	return row


## A section heading with a rule under it.
static func section(text: String, color: Color = Palette.ACCENT) -> Control:
	var v := vbox(4)
	v.add_child(label(text.to_upper(), 13, color))
	var rule := ColorRect.new()
	rule.color = Palette.with_alpha(color, 0.28)
	rule.custom_minimum_size.y = 2
	v.add_child(rule)
	return v


## A key/value row for summaries.
static func stat_row(key: String, value: String, value_color: Color = Palette.TEXT) -> Control:
	var h := hbox(10)
	var k := label(key, 15, Palette.TEXT_DIM)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	var v := label(value, 16, value_color)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	return h


## Fades a control in, used on every screen transition.
static func fade_in(node: CanvasItem, duration: float = 0.22, delay: float = 0.0) -> void:
	node.modulate.a = 0.0
	var tween := node.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(node, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)


## Fades a control in with a brief overexposure, so a grid of cards arrives one
## at a time instead of all at once.
##
## Deliberately animates `modulate` and nothing else: these controls live inside
## containers, which own their children's position and size and would fight a
## tween on either - especially during build(), before the first layout pass has
## even given them real coordinates.
static func pop_in(node: CanvasItem, duration: float = 0.28, delay: float = 0.0) -> void:
	node.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := node.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(node, "modulate", Color(1.22, 1.22, 1.22, 1.0), duration * 0.62).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "modulate", Color.WHITE, duration * 0.38).set_trans(Tween.TRANS_SINE)


## A short judder for critical results. Runs after layout has settled, and always
## restores the original offset even if it is interrupted.
static func shake(node: Control, strength: float = 10.0) -> void:
	var origin := node.position
	var tween := node.create_tween()
	for i in 5:
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength) * 0.4)
		tween.tween_property(node, "position", origin + offset, 0.04)
		strength *= 0.65
	tween.tween_property(node, "position", origin, 0.05)
