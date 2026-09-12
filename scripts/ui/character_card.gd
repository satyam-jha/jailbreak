class_name CharacterCard
extends PanelContainer
## One prisoner, rendered as a card. Used for recruitment (full), the party
## screen (full, with live health and status) and actor pickers (compact).

signal chosen(prisoner: Prisoner)

var prisoner: Prisoner
var compact: bool = false
## "card" is the tall three-across recruitment card; "row" is the full-width
## strip the crew screen uses, where five of them have to fit vertically.
var layout: String = "card"
var selectable: bool = true
var action_text: String = "RECRUIT"
var highlight_stat: String = ""

var _selected := false
var _portrait: CharacterPortrait


func _init(p: Prisoner = null, is_compact: bool = false) -> void:
	prisoner = p
	compact = is_compact


func _ready() -> void:
	_apply_style(false)
	if compact:
		_build_compact()
	elif layout == "row":
		_build_row()
	else:
		_build_full()


func _apply_style(selected: bool) -> void:
	var border := Palette.ACCENT if selected else Palette.BORDER
	var bg := Palette.PANEL_HI if selected else Palette.PANEL
	if prisoner != null and not prisoner.is_available():
		bg = Palette.PANEL_DARK
		border = Palette.darken(Palette.BORDER, 0.3)
	add_theme_stylebox_override("panel", UIKit.stylebox(bg, border, 14, 2))


func set_selected(value: bool) -> void:
	_selected = value
	_apply_style(value)


## --- Full card -----------------------------------------------------------

## Portrait and vitals side by side, so a card fits on screen beside two others
## without scrolling. A single column runs to roughly 950px, which does not.
func _build_full() -> void:
	custom_minimum_size = Vector2(332, 0)
	var v := UIKit.vbox(7)
	add_child(v)

	var top := UIKit.hbox(10)
	v.add_child(top)

	_portrait = CharacterPortrait.new()
	_portrait.setup(prisoner)
	_portrait.animate = true
	_portrait.custom_minimum_size = Vector2(124, 158)
	top.add_child(_portrait)

	var vitals := UIKit.vbox(3)
	vitals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(vitals)

	vitals.add_child(UIKit.label(prisoner.display_name, 20, Palette.TEXT))
	if not prisoner.nickname.is_empty():
		vitals.add_child(UIKit.label("\"%s\"" % prisoner.nickname, 13, Palette.ACCENT))
	vitals.add_child(_health_row())

	for stat in Content.stat_keys:
		var row := UIKit.stat_bar(stat, prisoner.effective_stat(stat), 10, prisoner.status_delta(stat), 72)
		if stat == highlight_stat:
			row.modulate = Color(1.3, 1.3, 1.3)
		vitals.add_child(row)

	v.add_child(UIKit.section("Traits"))
	v.add_child(trait_chips(prisoner))

	var desc := UIKit.paragraph(prisoner.description, 12, Palette.TEXT_DIM)
	desc.custom_minimum_size.y = 48
	v.add_child(desc)

	if selectable:
		var pick := UIKit.primary_button(action_text, 16)
		pick.pressed.connect(func() -> void:
			Audio.play("confirm")
			chosen.emit(prisoner))
		v.add_child(pick)


## Full-width strip: portrait, identity and traits, then stats in their own
## column. Used where several crew members are listed one under another.
func _build_row() -> void:
	var h := UIKit.hbox(14)
	add_child(h)

	_portrait = CharacterPortrait.new()
	_portrait.setup(prisoner)
	_portrait.animate = true
	_portrait.custom_minimum_size = Vector2(112, 142)
	h.add_child(_portrait)

	var middle := UIKit.vbox(5)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(middle)

	var title_row := UIKit.hbox(8)
	title_row.add_child(UIKit.label(prisoner.display_name, 21, Palette.TEXT))
	if not prisoner.nickname.is_empty():
		title_row.add_child(UIKit.label("\"%s\"" % prisoner.nickname, 14, Palette.ACCENT))
	title_row.add_child(UIKit.spacer())
	middle.add_child(title_row)

	middle.add_child(_health_row())
	middle.add_child(trait_chips(prisoner))
	middle.add_child(UIKit.paragraph(prisoner.description, 12, Palette.TEXT_FAINT))

	var stats := UIKit.vbox(3)
	stats.custom_minimum_size.x = 210
	h.add_child(stats)
	for stat in Content.stat_keys:
		var row := UIKit.stat_bar(stat, prisoner.effective_stat(stat), 10, prisoner.status_delta(stat), 92)
		if stat == highlight_stat:
			row.modulate = Color(1.3, 1.3, 1.3)
		stats.add_child(row)


func _health_row() -> Control:
	var h := UIKit.hbox(8)
	var hearts := UIKit.label("%d / %d HP" % [prisoner.health, prisoner.max_health], 14,
		Palette.SUCCESS if prisoner.health > prisoner.max_health * 0.5 else Palette.DANGER)
	h.add_child(hearts)
	h.add_child(UIKit.spacer())
	if prisoner.status != "healthy":
		h.add_child(UIKit.chip(prisoner.status_name(), prisoner.status_color()))
	return h


## Trait names as coloured pills that wrap onto as many rows as they need. The
## full effect text is the tooltip - spelling every one out in full turns a card
## into a wall of text and pushes the recruit button off the screen.
static func trait_chips(p: Prisoner) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 4)
	for trait_id in p.trait_ids:
		var t: Dictionary = Content.get_trait(trait_id)
		if t.is_empty():
			continue
		var color := Palette.TEAL
		match str(t.get("polarity", "neutral")):
			"positive": color = Palette.SUCCESS
			"negative": color = Palette.DANGER
		var chip := UIKit.chip(str(t.get("name", trait_id)), color)
		chip.tooltip_text = "%s\n%s" % [str(t.get("name", trait_id)), str(t.get("description", ""))]
		flow.add_child(chip)
	if p.trait_ids.is_empty():
		flow.add_child(UIKit.paragraph("No notable traits. Suspicious in itself.", 12, Palette.TEXT_FAINT))
	return flow


## --- Compact card (actor pickers) ----------------------------------------

func _build_compact() -> void:
	custom_minimum_size = Vector2(210, 0)
	var h := UIKit.hbox(10)
	add_child(h)

	_portrait = CharacterPortrait.new()
	_portrait.setup(prisoner)
	_portrait.show_background = false
	_portrait.custom_minimum_size = Vector2(56, 68)
	h.add_child(_portrait)

	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)

	v.add_child(UIKit.label(prisoner.display_name, 16, Palette.TEXT))

	if not highlight_stat.is_empty():
		var value := prisoner.effective_stat(highlight_stat)
		var line := UIKit.hbox(6)
		line.add_child(UIKit.label("%s %d" % [highlight_stat.capitalize(), value], 15, Palette.stat_color(highlight_stat)))
		var delta := prisoner.status_delta(highlight_stat)
		if delta != 0:
			line.add_child(UIKit.label("(%s%d)" % ["+" if delta > 0 else "", delta], 13,
				Palette.SUCCESS if delta > 0 else Palette.DANGER))
		v.add_child(line)

	var status_line := UIKit.hbox(6)
	status_line.add_child(UIKit.label("%d/%d HP" % [prisoner.health, prisoner.max_health], 12, Palette.TEXT_DIM))
	if prisoner.status != "healthy":
		status_line.add_child(UIKit.chip(prisoner.status_name(), prisoner.status_color()))
	v.add_child(status_line)

	if selectable:
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.disabled = not prisoner.is_available()
		btn.pressed.connect(func() -> void:
			Audio.play("select")
			chosen.emit(prisoner))
		add_child(btn)


func set_expression(expr: String) -> void:
	if _portrait != null:
		_portrait.expression = expr
