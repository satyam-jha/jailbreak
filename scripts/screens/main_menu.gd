extends Screen
## Title screen. Also the only place that offers to resume a saved run.


func _init() -> void:
	music_mood = "menu"


func build() -> void:
	var root := UIKit.margin(36)
	add_child(root)

	var column := UIKit.vbox(6)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(column)

	var title := UIKit.label("JAILBREAK", 78, Palette.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Palette.BG_DEEP)
	column.add_child(title)

	var tagline := UIKit.paragraph(
		"Assemble five ridiculous prisoners and attempt the world's dumbest prison escape.",
		17, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(tagline)

	column.add_child(UIKit.spacer(18))
	column.add_child(_mugshot_row())
	column.add_child(UIKit.spacer(18))

	var buttons := UIKit.vbox(10)
	buttons.custom_minimum_size.x = 340
	var center := UIKit.hbox(0)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(buttons)
	column.add_child(center)

	var new_run := UIKit.primary_button("NEW RUN", 22)
	new_run.pressed.connect(_start_new_run)
	buttons.add_child(new_run)

	if SaveSystem.has_run():
		var resume := UIKit.button("CONTINUE SAVED RUN", 17)
		resume.pressed.connect(_resume_run)
		buttons.add_child(resume)

	var how := UIKit.button("HOW TO PLAY", 17)
	how.pressed.connect(func() -> void:
		Audio.play("click")
		go("how_to_play"))
	buttons.add_child(how)

	var settings := UIKit.button("SETTINGS", 17)
	settings.pressed.connect(func() -> void:
		Audio.play("click")
		go("settings"))
	buttons.add_child(settings)

	# On the web there is nothing to quit to, so the button does not appear.
	if not OS.has_feature("web"):
		var quit := UIKit.button("QUIT", 17)
		quit.pressed.connect(func() -> void:
			Audio.play("click")
			get_tree().quit())
		buttons.add_child(quit)

	column.add_child(UIKit.spacer(16))
	var footer := UIKit.paragraph(
		"F1 opens the debug menu   -   F11 toggles fullscreen   -   every run has a seed",
		12, Palette.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(footer)

	UIKit.pop_in(column, 0.4)


## A line-up of five random members of the cast, purely so the title screen
## shows the game's art rather than describing it.
func _mugshot_row() -> Control:
	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var boot := RandomNumberGenerator.new()
	boot.randomize()
	var defs: Array = Content.character_defs.duplicate()
	for i in range(defs.size() - 1, 0, -1):
		var j := boot.randi_range(0, i)
		var tmp: Variant = defs[i]
		defs[i] = defs[j]
		defs[j] = tmp

	var expressions := ["idle", "happy", "worried", "angry", "idle"]
	for i in range(mini(5, defs.size())):
		var frame := UIKit.panel(Palette.PANEL_DARK, Palette.BORDER, 12)
		var portrait := CharacterPortrait.new()
		portrait.visual = (defs[i] as Dictionary).get("visual", {})
		portrait.expression = expressions[i % expressions.size()]
		portrait.animate = true
		portrait.custom_minimum_size = Vector2(120, 150)
		frame.add_child(portrait)
		row.add_child(frame)
		UIKit.pop_in(frame, 0.35, 0.06 * i)
	return row


func _start_new_run() -> void:
	Audio.play("confirm")
	Game.start_run()
	SaveSystem.delete_run()
	go("recruitment", {"step": 0})


func _resume_run() -> void:
	Audio.play("confirm")
	if not SaveSystem.load_run():
		Audio.play("failure")
		return
	if Game.party.size() < Game.PARTY_SIZE:
		go("recruitment", {"step": Game.party.size()})
	elif Game.result != "":
		go("summary")
	else:
		go("map")
