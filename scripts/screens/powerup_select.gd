extends Screen
## Five cards. Four are exactly what they say. One is not, and nothing on the
## screen tells you which - that is the whole mechanic.

enum State { OFFER, TARGET, TAKEN }

var _state: int = State.OFFER
var _offers: Array = []
var _chosen: Dictionary = {}
var _result: Dictionary = {}
var _body: VBoxContainer


func _init() -> void:
	show_hud = true
	music_mood = "gameplay"


func build() -> void:
	_offers = PowerupSystem.generate_offers(Game.owned_powerup_ids())

	var column := page("THE ROOM WENT YOUR WAY", "Somebody has produced five things. Take exactly one.")

	var warning := UIKit.panel(Palette.PANEL_DARK, Palette.with_alpha(Palette.WARN, 0.6), 12)
	var wv := UIKit.hbox(10)
	warning.add_child(wv)
	wv.add_child(UIKit.chip("HEADS UP", Palette.WARN))
	wv.add_child(UIKit.paragraph(
		"Exactly one of these has a catch. It might land now, later, or at the wall. Nothing on the card will tell you.",
		15, Palette.TEXT_DIM))
	column.add_child(warning)

	var scroller := UIKit.scroll()
	column.add_child(scroller)
	_body = UIKit.vbox(12)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(_body)

	_render()


func _clear_body() -> void:
	# Detach before freeing: queue_free() is deferred, so leaving the outgoing
	# nodes parented would make the container lay out both sets for a frame.
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()


func _render() -> void:
	_clear_body()
	match _state:
		State.OFFER: _render_offers()
		State.TARGET: _render_target_picker()
		State.TAKEN: _render_taken()


func _render_offers() -> void:
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(_offers.size()):
		var card := _offer_card(_offers[i])
		row.add_child(card)
		UIKit.pop_in(card, 0.3, 0.07 * i)
	_body.add_child(row)


func _offer_card(offer: Dictionary) -> Control:
	var def: Dictionary = offer.get("def", {})
	var rarity := str(def.get("rarity", "common"))
	var rarity_color := Palette.TEXT_DIM
	match rarity:
		"uncommon": rarity_color = Palette.TEAL
		"rare": rarity_color = Palette.PURPLE

	var box := UIKit.panel(Palette.PANEL, Palette.BORDER, 14)
	box.custom_minimum_size = Vector2(220, 280)

	var v := UIKit.vbox(8)
	box.add_child(v)

	var head := UIKit.hbox(6)
	head.add_child(UIKit.chip(rarity.to_upper(), rarity_color))
	head.add_child(UIKit.spacer())
	head.add_child(UIKit.chip(str(def.get("target", "party")).to_upper(), Palette.TEXT_FAINT))
	v.add_child(head)

	var icon := RoomIcon.new(_icon_for(def), rarity_color)
	icon.custom_minimum_size = Vector2(0, 54)
	v.add_child(icon)

	var name_label := UIKit.label(str(def.get("name", "?")), 20, Palette.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(name_label)

	v.add_child(UIKit.paragraph(str(def.get("description", "")), 15, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.spacer())
	v.add_child(UIKit.paragraph(str(def.get("flavor", "")), 12, Palette.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER))

	var take := UIKit.button("TAKE IT", 16, 44)
	take.pressed.connect(func() -> void:
		Audio.play("powerup")
		_on_offer_chosen(offer))
	v.add_child(take)

	var hover := Button.new()
	hover.flat = true
	hover.set_anchors_preset(Control.PRESET_FULL_RECT)
	hover.mouse_filter = Control.MOUSE_FILTER_PASS
	hover.focus_mode = Control.FOCUS_NONE
	hover.mouse_entered.connect(func() -> void: Audio.play("hover"))
	box.add_child(hover)
	return box


## Picks a glyph from what the power-up actually does, so the cards are
## scannable without reading every word.
func _icon_for(def: Dictionary) -> String:
	for e in def.get("effects", []):
		match str(e.get("type", "")):
			"heal", "max_health", "revive": return "cross"
			"money", "money_per_room", "money_on_success": return "tray"
			"heat", "heat_decay", "heat_multiplier": return "badge"
			"escape_bonus": return "wall"
			"save_chance": return "star"
			"check_bonus": return "gear"
			"stat_bonus": return "flame"
	return "book"


func _on_offer_chosen(offer: Dictionary) -> void:
	_chosen = offer
	if str((offer.get("def", {}) as Dictionary).get("target", "party")) == "one":
		_state = State.TARGET
		_render()
		return
	_take(null)


func _render_target_picker() -> void:
	var def: Dictionary = _chosen.get("def", {})
	_body.add_child(UIKit.paragraph("%s only helps one person. Who gets it?" % str(def.get("name", "It")), 19, Palette.TEXT))

	var row := UIKit.hbox(10)
	for member in Game.party:
		var card := CharacterCard.new(member, true)
		card.chosen.connect(_take)
		row.add_child(card)
	_body.add_child(row)

	var back := UIKit.button("CHOOSE A DIFFERENT POWER-UP", 16)
	back.pressed.connect(func() -> void:
		Audio.play("click")
		_state = State.OFFER
		_render())
	_body.add_child(back)


func _take(target: Prisoner) -> void:
	_result = Game.take_powerup(_chosen, target)
	_state = State.TAKEN
	SaveSystem.save_run()
	_render()


func _render_taken() -> void:
	var def: Dictionary = _chosen.get("def", {})
	var box := UIKit.panel(Palette.PANEL, Palette.ACCENT, 14)
	var v := UIKit.vbox(8)
	box.add_child(v)
	v.add_child(UIKit.title(str(def.get("name", "")), 28, Palette.ACCENT))
	v.add_child(UIKit.paragraph(str(def.get("description", "")), 17, Palette.TEXT))
	v.add_child(UIKit.paragraph(str(def.get("flavor", "")), 13, Palette.TEXT_FAINT))
	_body.add_child(box)

	var changes: Array = _result.get("changes", [])
	if not changes.is_empty():
		_body.add_child(changes_panel(changes))

	var catches: Array = _result.get("catches", [])
	for report in catches:
		_body.add_child(_catch_panel(report))

	if catches.is_empty():
		_body.add_child(UIKit.paragraph("It seems fine. It seems completely fine.", 14, Palette.TEXT_FAINT))

	var onward := UIKit.primary_button("BACK TO THE MAP", 19)
	onward.pressed.connect(func() -> void:
		Audio.play("click")
		go("map"))
	_body.add_child(onward)


func _catch_panel(report: Dictionary) -> Control:
	Audio.play("catch")
	var box := UIKit.panel(Palette.darken(Palette.DANGER_DARK, 0.35), Palette.DANGER, 14)
	var v := UIKit.vbox(6)
	box.add_child(v)
	var head := UIKit.hbox(8)
	head.add_child(UIKit.chip("THE CATCH", Palette.DANGER))
	head.add_child(UIKit.label(str(report.get("powerup_name", "")), 17, Palette.TEXT))
	head.add_child(UIKit.spacer())
	v.add_child(head)
	v.add_child(UIKit.paragraph(str(report.get("reveal_text", "")), 16, Palette.TEXT))
	for c in report.get("changes", []):
		v.add_child(UIKit.label(str(c.get("text", "")), 14, Palette.DANGER))
	return box
