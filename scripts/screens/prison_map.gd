extends Screen
## The journey view. Shows where the crew is, which rooms are reachable, and
## what each route is likely to cost.


func _init() -> void:
	show_hud = true
	music_mood = "gameplay"


func build() -> void:
	if Game.map.is_empty():
		go("main_menu")
		return

	music_mood = "tension" if Game.heat >= 60 else "gameplay"
	Audio.play_music(music_mood)

	var current := Game.current_node()
	var room: Dictionary = Content.get_room(str(current.get("room_id", "")))

	var column := page("", "")
	var header := UIKit.hbox(14)
	var here := UIKit.vbox(2)
	here.custom_minimum_size.x = 520
	here.add_child(UIKit.label("YOU ARE IN", 12, Palette.TEXT_FAINT))
	here.add_child(UIKit.title(str(room.get("name", "?")), 30, Palette.TEXT))
	here.add_child(UIKit.paragraph(str(room.get("blurb", "")), 14, Palette.TEXT_DIM))
	header.add_child(here)
	header.add_child(UIKit.spacer())
	header.add_child(_band_panel())
	column.add_child(header)

	if Game.at_final_room():
		column.add_child(_final_panel())
		return

	column.add_child(UIKit.label("CHOOSE THE NEXT ROOM", 13, Palette.ACCENT))

	var scroller := ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(scroller)

	var map_view := MapView.new()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.room_chosen.connect(_on_room_chosen)
	scroller.add_child(map_view)

	var legend := UIKit.hbox(16)
	legend.add_child(UIKit.chip("SAFE", PrisonGenerator.path_color(PrisonGenerator.Path.SAFE)))
	legend.add_child(UIKit.label("normal risk, normal reward", 12, Palette.TEXT_FAINT))
	legend.add_child(UIKit.chip("RISKY", PrisonGenerator.path_color(PrisonGenerator.Path.RISKY)))
	legend.add_child(UIKit.label("harder, louder, pays better", 12, Palette.TEXT_FAINT))
	legend.add_child(UIKit.chip("SECRET", PrisonGenerator.path_color(PrisonGenerator.Path.SECRET)))
	legend.add_child(UIKit.label("needs the right person, pays best", 12, Palette.TEXT_FAINT))
	legend.add_child(UIKit.spacer())
	column.add_child(legend)


func _band_panel() -> Control:
	var band := Game.heat_band()
	var box := UIKit.panel(Palette.PANEL_DARK, Palette.with_alpha(Game.heat_color(), 0.7), 12)
	box.custom_minimum_size.x = 380
	var v := UIKit.vbox(2)
	box.add_child(v)
	v.add_child(UIKit.label(str(band.get("name", "")), 20, Game.heat_color()))
	v.add_child(UIKit.paragraph(str(band.get("flavor", "")), 13, Palette.TEXT_DIM))
	var effect := -int(round((float(Game.heat) / 100.0) * Game.HEAT_PRESSURE_AT_MAX))
	v.add_child(UIKit.label("Every check is currently at %d%% because of Heat." % effect, 12, Palette.TEXT_FAINT))
	return box


func _final_panel() -> Control:
	var box := UIKit.panel(Palette.PANEL, Palette.ACCENT, 14)
	var v := UIKit.vbox(10)
	box.add_child(v)
	v.add_child(UIKit.title("THE OUTER WALL", 30, Palette.ACCENT))
	v.add_child(UIKit.paragraph(
		"Forty feet of concrete and whatever plan you have left. This is the last thing that happens in this run.",
		16, Palette.TEXT_DIM))

	var down := 0
	for m in Game.party:
		if not (m as Prisoner).is_available():
			down += 1
	if down > 0:
		v.add_child(UIKit.paragraph("%d of the crew will not be helping. They are here, but they are not helping." % down, 14, Palette.DANGER))

	var go_button := UIKit.primary_button("ATTEMPT THE ESCAPE", 22)
	go_button.pressed.connect(func() -> void:
		Audio.play("confirm")
		go("escape"))
	v.add_child(go_button)
	return box


func _on_room_chosen(node_id: String) -> void:
	SaveSystem.save_run()
	go("encounter", {"node_id": node_id})
