extends Screen
## A one-page explanation, written so that a first-time player can start a run
## straight after reading it.


func _init() -> void:
	music_mood = "menu"


func build() -> void:
	var column := page("HOW TO PLAY", "It is a strategy game about five idiots. You are not one of them, but you are responsible for them.")

	var scroller := UIKit.scroll()
	column.add_child(scroller)
	var content := UIKit.hbox(18)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(content)

	content.add_child(_column([
		["The crew", "Pick one prisoner from three, four times over. Five in total, then they are locked in. Traits matter more than raw stats, and a crew covering strength, tech, social and stealth unlocks a synergy bonus on every check."],
		["The prison", "Each room offers a SAFE, RISKY or SECRET route onward. Risky rooms are harder and louder but pay more. Secret rooms need a specific stat or trait, and pay best of all."],
		["Encounters", "Each room throws one event at you. Pick an action, then pick who does it. The percentage on the button is the real number the game is about to roll against."],
	]))

	content.add_child(_column([
		["Skill checks", "chance = 34 + (stat - 5) x 8, minus difficulty, plus traits, synergies, power-ups and Heat. Clamped to 5-85 - nothing is ever certain - then a d100. The top slice of a success is a critical success; the bottom slice of a failure is a catastrophe. The full arithmetic is shown every single time."],
		["Heat", "The prison's suspicion, 0 to 100. It makes every check harder, changes which events can fire, and at 100 the run ends in a lockdown. Every room raises it a little just for time passing, and more so the deeper you get. Failing loudly raises it a lot; talking your way out lowers it, but only at half face value."],
		["Health and status", "Characters get injured, scared, angry and exhausted, and each status shifts their stats. At zero health they are unconscious and unavailable - but the run continues without them."],
	]))

	content.add_child(_column([
		["Power-ups", "After a room actually goes your way - a failed encounter earns nothing - you get five cards. Four are exactly what they say. One has a hidden catch, and which card is trapped is re-rolled every time, so it can never be memorised. The catch may land immediately, several rooms later, or at the wall."],
		["The escape", "At the outer wall, pick one of four routes and run its three checks. Two passes out of three gets you over. A loud run makes most routes harder - though the riot, notably, does better the worse things have got."],
		["Seeds", "Every run has a seed, shown in the status bar and the summary. Replaying a seed regenerates the same prison and the same candidates, which is how you settle an argument about whether a run was unwinnable."],
	]))

	var back := UIKit.primary_button("BACK", 18)
	back.pressed.connect(func() -> void:
		Audio.play("click")
		go("main_menu"))
	var row := UIKit.hbox(0)
	row.add_child(back)
	row.add_child(UIKit.spacer())
	column.add_child(row)


func _column(entries: Array) -> Control:
	var v := UIKit.vbox(14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size.x = 340
	for entry in entries:
		var box := UIKit.panel(Palette.PANEL, Palette.BORDER, 12)
		var inner := UIKit.vbox(5)
		box.add_child(inner)
		inner.add_child(UIKit.label(str(entry[0]).to_upper(), 15, Palette.ACCENT))
		inner.add_child(UIKit.paragraph(str(entry[1]), 14, Palette.TEXT_DIM))
		v.add_child(box)
	return v
