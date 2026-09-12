class_name HUD
extends PanelContainer
## The persistent status bar: Heat, money, progress and the run seed.
##
## Heat is the number the player is meant to be frightened of, so it gets a
## labelled bar that changes colour by band and flashes when it moves.

var _heat_bar: ProgressBar
var _heat_label: Label
var _band_label: Label
var _money_label: Label
var _room_label: Label
var _seed_label: Label
var _party_button: Button

signal party_requested()


func _ready() -> void:
	add_theme_stylebox_override("panel", UIKit.stylebox(Palette.PANEL_DARK, Palette.BORDER, 0, 0))
	custom_minimum_size.y = 62
	clip_contents = true

	var row := UIKit.hbox(18)
	var margin := UIKit.margin(10)
	margin.add_child(row)
	add_child(margin)

	# Heat
	var heat_box := UIKit.vbox(3)
	heat_box.custom_minimum_size.x = 260
	var heat_head := UIKit.hbox(8)
	heat_head.add_child(UIKit.label("HEAT", 12, Palette.TEXT_FAINT))
	_band_label = UIKit.label("", 12, Palette.SUCCESS)
	heat_head.add_child(_band_label)
	heat_head.add_child(UIKit.spacer())
	_heat_label = UIKit.label("0", 14, Palette.TEXT)
	heat_head.add_child(_heat_label)
	heat_box.add_child(heat_head)

	_heat_bar = ProgressBar.new()
	_heat_bar.min_value = 0
	_heat_bar.max_value = Game.MAX_HEAT
	_heat_bar.show_percentage = false
	_heat_bar.custom_minimum_size.y = 14
	heat_box.add_child(_heat_bar)
	row.add_child(heat_box)

	row.add_child(_divider())

	_money_label = UIKit.label("$0", 20, Palette.ACCENT)
	row.add_child(_labelled("MONEY", _money_label))

	row.add_child(_divider())

	_room_label = UIKit.label("0", 20, Palette.TEXT)
	row.add_child(_labelled("ROOMS CLEARED", _room_label))

	row.add_child(_divider())

	_seed_label = UIKit.label("-", 14, Palette.TEXT_FAINT)
	row.add_child(_labelled("SEED", _seed_label))

	row.add_child(UIKit.spacer())

	_party_button = UIKit.button("THE CREW", 15, 40)
	_party_button.pressed.connect(func() -> void:
		Audio.play("click")
		party_requested.emit())
	row.add_child(_party_button)

	Game.heat_changed.connect(_on_heat_changed)
	Game.money_changed.connect(_on_money_changed)
	refresh()


func _labelled(caption: String, value_label: Label) -> Control:
	var v := UIKit.vbox(1)
	v.add_child(UIKit.label(caption, 11, Palette.TEXT_FAINT))
	v.add_child(value_label)
	return v


func _divider() -> Control:
	var c := ColorRect.new()
	c.color = Palette.BORDER
	c.custom_minimum_size = Vector2(1, 32)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


func refresh() -> void:
	_on_heat_changed(Game.heat, 0)
	_on_money_changed(Game.money, 0)
	_room_label.text = str(Game.rooms_cleared)
	_seed_label.text = str(Game.seed_value)


func _on_heat_changed(value: int, delta: int) -> void:
	var color := Game.heat_color()
	_heat_bar.value = value
	_heat_label.text = "%d / 100" % value
	_band_label.text = Game.heat_band_name()
	_band_label.add_theme_color_override("font_color", color)

	var bg := UIKit.stylebox(Palette.PANEL_DARK, Palette.PANEL_DARK, 7, 0)
	bg.content_margin_left = 0
	bg.content_margin_right = 0
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	var fill := UIKit.stylebox(color, color, 7, 0)
	fill.content_margin_left = 0
	fill.content_margin_right = 0
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	_heat_bar.add_theme_stylebox_override("background", bg)
	_heat_bar.add_theme_stylebox_override("fill", fill)

	if delta != 0:
		Audio.play("heat_up" if delta > 0 else "heat_down")
		var tween := create_tween()
		tween.tween_property(_heat_label, "modulate", Color(1.6, 1.2, 1.2), 0.10)
		tween.tween_property(_heat_label, "modulate", Color.WHITE, 0.30)
	_room_label.text = str(Game.rooms_cleared)


func _on_money_changed(value: int, delta: int) -> void:
	_money_label.text = "$%d" % value
	if delta != 0:
		var tween := create_tween()
		tween.tween_property(_money_label, "modulate", Color(1.5, 1.5, 1.0) if delta > 0 else Color(1.6, 0.9, 0.9), 0.10)
		tween.tween_property(_money_label, "modulate", Color.WHITE, 0.30)
