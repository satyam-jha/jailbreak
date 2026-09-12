extends Screen
## Choose the main prisoner, then recruit four more. Three candidates per step,
## one pick, no take-backs.


func _init() -> void:
	music_mood = "menu"


func build() -> void:
	var step: int = Game.party.size()
	var is_first := step == 0

	var heading := "CHOOSE YOUR MAIN PRISONER" if is_first else "RECRUIT PRISONER #%d" % (step + 1)
	var sub := "Three candidates. Pick one. They are locked in for the whole run." if is_first \
		else "Four in the crew by the end. Mind the gaps in what you already have."

	var column := page(heading, sub)

	var progress := UIKit.hbox(8)
	for i in range(Game.PARTY_SIZE):
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(48, 8)
		var filled := i < step
		pip.add_theme_stylebox_override("panel",
			UIKit.stylebox(Palette.ACCENT if filled else Palette.PANEL_HI, Palette.BORDER, 4, 0))
		progress.add_child(pip)
	progress.add_child(UIKit.spacer())
	if not is_first:
		progress.add_child(_current_crew_strip())
	column.add_child(progress)

	var candidates := Game.draw_candidates()
	if candidates.is_empty():
		column.add_child(UIKit.paragraph("The candidate pool is empty. Check data/characters.json.", 18, Palette.DANGER))
		return

	var scroller := UIKit.scroll()
	column.add_child(scroller)

	var row := UIKit.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(row)

	for i in range(candidates.size()):
		var card := CharacterCard.new(candidates[i], false)
		card.action_text = "TAKE " + (candidates[i] as Prisoner).display_name.to_upper()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.chosen.connect(_on_chosen)
		row.add_child(card)
		UIKit.pop_in(card, 0.3, 0.08 * i)

	var hint := UIKit.paragraph(
		"Tip: traits matter more than raw stats, and a crew that covers strength, tech, social and stealth unlocks a synergy.",
		13, Palette.TEXT_FAINT)
	column.add_child(hint)


## A small reminder of who is already on the crew, so pick five is not blind.
func _current_crew_strip() -> Control:
	var row := UIKit.hbox(6)
	for member in Game.party:
		var frame := UIKit.panel(Palette.PANEL_DARK, Palette.BORDER, 8)
		var portrait := CharacterPortrait.new()
		portrait.setup(member)
		portrait.show_background = false
		portrait.custom_minimum_size = Vector2(44, 54)
		frame.add_child(portrait)
		frame.tooltip_text = (member as Prisoner).full_name()
		row.add_child(frame)
	return row


func _on_chosen(p: Prisoner) -> void:
	Game.recruit(p)
	Game.add_notable("%s joined the crew." % p.display_name)
	if Game.party_is_full():
		Game.lock_party_and_generate_prison()
		SaveSystem.save_run()
		go("party", {"locking": true})
	else:
		go("recruitment")
