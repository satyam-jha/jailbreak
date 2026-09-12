extends Screen
## The bit people screenshot. Numbers on the left, the actual story on the right.

func _init() -> void:
	music_mood = "victory"

func build() -> void:
	var data := Game.summary()
	var escaped := str(data["result"]) == "escaped"
	music_mood = "victory" if escaped else "defeat"
	Audio.play_music(music_mood)
	SaveSystem.delete_run()
	var column := page()
	var banner := UIKit.panel(Palette.PANEL, Palette.SUCCESS if escaped else Palette.DANGER, 16)
	var bv := UIKit.vbox(6); banner.add_child(bv)
	bv.add_child(UIKit.label("ESCAPE ATTEMPT COMPLETE", 13, Palette.TEXT_FAINT))
	bv.add_child(UIKit.title(str(data["headline"]), 42, Palette.SUCCESS if escaped else Palette.DANGER))
	bv.add_child(UIKit.paragraph(str(data["detail"]), 17, Palette.TEXT))
	column.add_child(banner); UIKit.pop_in(banner, 0.4)
	var scroller := UIKit.scroll(); column.add_child(scroller)
	var content := UIKit.hbox(16); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroller.add_child(content)
	content.add_child(_numbers_panel(data)); content.add_child(_story_panel(data))
	var actions := UIKit.hbox(12)
	var retry := UIKit.primary_button("RUN IT AGAIN, SAME SEED", 18)
	retry.pressed.connect(func() -> void: Audio.play("confirm"); Game.start_run(int(data["seed"])); go("recruitment")); actions.add_child(retry)
	var fresh := UIKit.button("NEW RUN, NEW SEED", 17)
	fresh.pressed.connect(func() -> void: Audio.play("confirm"); Game.start_run(); go("recruitment")); actions.add_child(fresh)
	var menu := UIKit.button("MAIN MENU", 17)
	menu.pressed.connect(func() -> void: Audio.play("click"); go("main_menu")); actions.add_child(menu); actions.add_child(UIKit.spacer()); column.add_child(actions)

func _numbers_panel(data: Dictionary) -> Control:
	var box := UIKit.panel(Palette.PANEL_DARK, Palette.BORDER, 14); box.custom_minimum_size.x = 400
	var v := UIKit.vbox(6); box.add_child(v)
	v.add_child(UIKit.section("The record", Palette.ACCENT))
	v.add_child(UIKit.stat_row("Days survived", str(data["days"])))
	v.add_child(UIKit.stat_row("Rooms cleared", str(data["rooms_cleared"])))
	v.add_child(UIKit.stat_row("Guards fooled", str(data["guards_fooled"])))
	v.add_child(UIKit.stat_row("Checks attempted", str(data["checks_made"])))
	v.add_child(UIKit.stat_row("Critical moments", str(data["criticals"]), Palette.SUCCESS))
	v.add_child(UIKit.stat_row("Complete disasters", str(data["disasters"]), Palette.DANGER))
	v.add_child(UIKit.stat_row("Final Heat", "%d / 100" % int(data["heat"]), Game.heat_color()))
	v.add_child(UIKit.stat_row("Money", "$%d" % int(data["money"]), Palette.ACCENT))
	if not str(data["route"]).is_empty(): v.add_child(UIKit.stat_row("Escape route", str(Content.get_escape_route(str(data["route"])).get("name", "-"))))
	var strategy := Strategy.summary()
	v.add_child(UIKit.spacer(10)); v.add_child(UIKit.section("Consequences", Palette.DANGER))
	v.add_child(UIKit.stat_row("Suspicion", "%d / 5" % int(strategy["suspicion"]), Palette.DANGER if int(strategy["suspicion"]) >= 3 else Palette.TEXT))
	v.add_child(UIKit.stat_row("Noise", "%d / 5" % int(strategy["noise"]), Palette.WARN if int(strategy["noise"]) >= 3 else Palette.TEXT))
	v.add_child(UIKit.stat_row("Prison intel", "%d / 5" % int(strategy["intel"]), Palette.TEAL))
	v.add_child(UIKit.stat_row("Patrol attention", "%d / 5" % int(strategy["guard_attention"]), Palette.DANGER))
	v.add_child(UIKit.stat_row("Inside favors", "%d" % int(strategy["favors"]), Palette.ACCENT))
	v.add_child(UIKit.spacer(10)); v.add_child(UIKit.section("The crew", Palette.TEAL))
	for member in Game.party:
		var p: Prisoner = member; var row := UIKit.hbox(8); var portrait := CharacterPortrait.new(); portrait.setup(p); portrait.show_background = false; portrait.custom_minimum_size = Vector2(40, 48); row.add_child(portrait)
		var info := UIKit.vbox(1); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info.add_child(UIKit.label(p.display_name, 15, Palette.TEXT)); info.add_child(UIKit.label("%d/%d HP - %s - %d of %d checks passed" % [p.health, p.max_health, p.status_name(), p.checks_passed, p.checks_attempted], 12, Palette.TEXT_FAINT)); row.add_child(info); v.add_child(row)
	v.add_child(UIKit.spacer(10)); var score := UIKit.hbox(10); score.add_child(UIKit.label("FINAL SCORE", 16, Palette.TEXT_DIM)); score.add_child(UIKit.spacer()); score.add_child(UIKit.label(str(data["score"]), 34, Palette.ACCENT)); v.add_child(score); v.add_child(UIKit.label("RUN SEED: %d" % int(data["seed"]), 13, Palette.TEXT_FAINT))
	return box

func _story_panel(data: Dictionary) -> Control:
	var box := UIKit.panel(Palette.PANEL, Palette.BORDER, 14); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(8); box.add_child(v)
	v.add_child(UIKit.section("Notable events", Palette.PURPLE))
	var notable: Array = data["notable"]
	if notable.is_empty(): v.add_child(UIKit.paragraph("Nothing worth writing down happened, which is its own kind of achievement.", 15, Palette.TEXT_FAINT))
	else:
		for line in notable:
			var row := UIKit.hbox(8); row.add_child(UIKit.label("-", 15, Palette.PURPLE)); row.add_child(UIKit.paragraph(str(line), 15, Palette.TEXT)); v.add_child(row)
	v.add_child(UIKit.spacer(8)); v.add_child(UIKit.section("Power-ups carried", Palette.ACCENT))
	if Game.powerups.is_empty(): v.add_child(UIKit.paragraph("None. A purist run, or a short one.", 14, Palette.TEXT_FAINT))
	for offer in Game.powerups:
		var def: Dictionary = offer.get("def", {}); var row2 := UIKit.vbox(2); var head := UIKit.hbox(8); head.add_child(UIKit.chip(str(def.get("name", "?")), Palette.ACCENT)); if bool(offer.get("has_catch", false)): head.add_child(UIKit.chip("HAD A CATCH", Palette.DANGER)); head.add_child(UIKit.spacer()); row2.add_child(head)
		if bool(offer.get("has_catch", false)):
			row2.add_child(UIKit.paragraph(str(PowerupSystem.catch_for(offer).get("reveal_text", "")), 13, Palette.DANGER if bool(offer.get("revealed", false)) else Palette.TEXT_FAINT))
			if not bool(offer.get("revealed", false)): row2.add_child(UIKit.paragraph("...and it never went off. You got away with it.", 13, Palette.SUCCESS))
		v.add_child(row2)
	return box
