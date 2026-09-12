class_name Screen
extends MarginContainer
## Base class for every screen. Main owns exactly one of these at a time.
##
## Screens are built in code in build(): the layouts are lists and grids driven
## by JSON, so a loop stays closer to the data than a hand-wired .tscn would.
##
## It is a MarginContainer (with no margin of its own) rather than a plain
## Control so that whatever a screen adds as its root is fitted to the full rect
## on every layout pass. Anchors alone are not enough here: a screen is added to
## the tree during Main._ready(), before anything has been laid out, so anchors
## would resolve against a zero-sized parent and stay that way.

signal navigate(screen_name: String, payload: Dictionary)

var payload: Dictionary = {}
var music_mood: String = ""
var show_hud: bool = false


func _ready() -> void:
	build()
	UIKit.fade_in(self)


## Override in each screen.
func build() -> void:
	pass


func go(screen_name: String, data: Dictionary = {}) -> void:
	navigate.emit(screen_name, data)


## Standard page scaffold: a padded column with an optional heading.
func page(heading: String = "", subheading: String = "") -> VBoxContainer:
	var margin := UIKit.margin(28)
	add_child(margin)

	var column := UIKit.vbox(16)
	margin.add_child(column)

	if not heading.is_empty():
		var head := UIKit.title(heading, 34, Palette.TEXT)
		column.add_child(head)
	if not subheading.is_empty():
		column.add_child(UIKit.body(subheading, 16))
	return column


## Renders the change lines produced by EffectResolver into coloured rows.
func changes_panel(changes: Array, heading: String = "WHAT CHANGED") -> Control:
	if changes.is_empty():
		return UIKit.spacer(0, 0)
	var box := UIKit.panel(Palette.PANEL_DARK, Palette.BORDER)
	var v := UIKit.vbox(6)
	box.add_child(v)
	v.add_child(UIKit.label(heading, 12, Palette.TEXT_FAINT))
	var wrapper := UIKit.vbox(4)
	v.add_child(wrapper)
	for c in changes:
		var text := str(c.get("text", ""))
		if text.is_empty():
			continue
		var good := bool(c.get("good", true))
		wrapper.add_child(UIKit.label(text, 15, Palette.SUCCESS if good else Palette.DANGER))
	return box
