extends Screen
## The crew sheet: who you have, what condition they are in, which synergies
## are live, and every power-up currently in play.


func _init() -> void:
	show_hud = true
	music_mood = "gameplay"


func build() -> void:
	var locking := bool(payload.get("locking", false))
	var heading := "THE CREW IS LOCKED" if locking else "THE CREW"
	var sub := "Five prisoners. No substitutions. The prison has been generated - seed %d." % Game.seed_value \
		if locking else "Everything currently true about your crew."

	var column := page(heading, sub)

	var scroller := UIKit.scroll()
	column.add_child(scroller)
	var content := UIKit.vbox(16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(content)

	for i in range(Game.party.size()):
		var card := CharacterCard.new(Game.party[i], false)
		card.selectable = false
		card.layout = "row"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(card)
		UIKit.pop_in(card, 0.28, 0.05 * i)

	content.add_child(_synergy_panel())
	content.add_child(_powerup_panel())

	var actions := UIKit.hbox(12)
	actions.add_child(UIKit.spacer())
	if locking:
		var enter := UIKit.primary_button("ENTER THE PRISON", 20)
		enter.pressed.connect(func() -> void:
			Audio.play("confirm")
			go("map"))
		actions.add_child(enter)
	else:
		var back := UIKit.button("BACK TO THE MAP", 17)
		back.pressed.connect(func() -> void:
			Audio.play("click")
			go("map"))
		actions.add_child(back)
	column.add_child(actions)


func _synergy_panel() -> Control:
	var box := UIKit.panel(Palette.PANEL_DARK, Palette.BORDER)
	var v := UIKit.vbox(8)
	box.add_child(v)
	v.add_child(UIKit.section("Party synergies", Palette.TEAL))

	var active := Game.active_synergies()
	if active.is_empty():
		v.add_child(UIKit.paragraph("None active. Synergies come from shared tags - two tech people, two talkers, or one of each discipline.", 14, Palette.TEXT_FAINT))
	else:
		for s in active:
			var line := UIKit.vbox(2)
			var head := UIKit.hbox(8)
			head.add_child(UIKit.chip(str(s.get("name", "")), Palette.TEAL))
			head.add_child(UIKit.paragraph(str(s.get("description", "")), 14, Palette.TEXT))
			head.add_child(UIKit.spacer())
			line.add_child(head)
			line.add_child(UIKit.paragraph(str(s.get("flavor", "")), 12, Palette.TEXT_FAINT))
			v.add_child(line)

	var tags := Game.party_tag_counts()
	var tag_row := UIKit.hbox(6)
	tag_row.add_child(UIKit.label("TAGS", 11, Palette.TEXT_FAINT))
	var keys: Array = tags.keys()
	keys.sort()
	for tag in keys:
		tag_row.add_child(UIKit.chip("%s x%d" % [str(tag), int(tags[tag])], Palette.PURPLE))
	tag_row.add_child(UIKit.spacer())
	v.add_child(tag_row)
	return box


func _powerup_panel() -> Control:
	var box := UIKit.panel(Palette.PANEL_DARK, Palette.BORDER)
	var v := UIKit.vbox(8)
	box.add_child(v)
	v.add_child(UIKit.section("Power-ups in play", Palette.ACCENT))

	if Game.powerups.is_empty():
		v.add_child(UIKit.paragraph("None yet. You get five choices after a room goes your way.", 14, Palette.TEXT_FAINT))
		return box

	for offer in Game.powerups:
		var def: Dictionary = offer.get("def", {})
		var line := UIKit.vbox(2)
		var head := UIKit.hbox(8)
		var cancelled := bool(offer.get("cancelled", false))
		head.add_child(UIKit.chip(str(def.get("name", "?")), Palette.TEXT_FAINT if cancelled else Palette.ACCENT))
		head.add_child(UIKit.paragraph(str(def.get("description", "")), 14,
			Palette.TEXT_FAINT if cancelled else Palette.TEXT))
		head.add_child(UIKit.spacer())
		line.add_child(head)

		if bool(offer.get("revealed", false)):
			var catch_def := PowerupSystem.catch_for(offer)
			line.add_child(UIKit.paragraph("CATCH: " + str(catch_def.get("reveal_text", "")), 12, Palette.DANGER))
		else:
			var hint := PowerupSystem.pending_hint(offer)
			if not hint.is_empty():
				line.add_child(UIKit.paragraph(hint, 12, Palette.WARN))
		v.add_child(line)
	return box
