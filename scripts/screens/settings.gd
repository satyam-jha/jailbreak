extends Screen
## Volumes, text speed, fullscreen, and a switch for the check breakdown.


func _init() -> void:
	music_mood = "menu"


func build() -> void:
	var column := page("SETTINGS", "Saved to user://settings.json the moment you change them.")

	var box := UIKit.panel(Palette.PANEL, Palette.BORDER, 14)
	box.custom_minimum_size.x = 560
	var v := UIKit.vbox(14)
	box.add_child(v)

	v.add_child(_slider("Master volume", "master_volume"))
	v.add_child(_slider("Music volume", "music_volume"))
	v.add_child(_slider("Sound effects", "sfx_volume"))
	v.add_child(_slider("Text speed", "text_speed", 0.4, 2.0))

	v.add_child(_toggle("Show the maths behind every skill check",
		"show_check_maths",
		"Turning this off hides the modifier table but keeps the roll and the verdict."))

	if not OS.has_feature("web"):
		var fullscreen := CheckBox.new()
		fullscreen.text = "Fullscreen  (or press F11 at any time)"
		fullscreen.button_pressed = DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED
		fullscreen.toggled.connect(func(on: bool) -> void:
			Audio.play("click")
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
			SaveSystem.set_setting("fullscreen", on))
		v.add_child(fullscreen)

	var row := UIKit.hbox(0)
	row.add_child(box)
	row.add_child(UIKit.spacer())
	column.add_child(row)

	var back := UIKit.primary_button("BACK", 18)
	back.pressed.connect(func() -> void:
		Audio.play("click")
		go("main_menu"))
	var actions := UIKit.hbox(0)
	actions.add_child(back)
	actions.add_child(UIKit.spacer())
	column.add_child(actions)


func _slider(caption: String, key: String, minimum: float = 0.0, maximum: float = 1.0) -> Control:
	var v := UIKit.vbox(4)
	var head := UIKit.hbox(8)
	head.add_child(UIKit.label(caption, 16, Palette.TEXT))
	head.add_child(UIKit.spacer())
	var value_label := UIKit.label("", 15, Palette.ACCENT)
	head.add_child(value_label)
	v.add_child(head)

	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = float(SaveSystem.get_setting(key, maximum * 0.8))
	slider.custom_minimum_size.y = 28
	value_label.text = "%d%%" % int(round(slider.value * 100.0))
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%d%%" % int(round(value * 100.0))
		SaveSystem.set_setting(key, value))
	slider.drag_ended.connect(func(_changed: bool) -> void: Audio.play("select"))
	v.add_child(slider)
	return v


func _toggle(caption: String, key: String, note: String) -> Control:
	var v := UIKit.vbox(2)
	var check := CheckBox.new()
	check.text = caption
	check.button_pressed = bool(SaveSystem.get_setting(key, true))
	check.toggled.connect(func(on: bool) -> void:
		Audio.play("click")
		SaveSystem.set_setting(key, on))
	v.add_child(check)
	v.add_child(UIKit.paragraph(note, 12, Palette.TEXT_FAINT))
	return v
