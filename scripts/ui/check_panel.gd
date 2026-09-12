class_name CheckPanel
extends PanelContainer
## Shows the entire arithmetic behind one skill check.
##
## Design spec section 36: if randomness causes a failure, the player must be
## able to see why. Every modifier that went into the number is listed, then the
## roll is animated against a bar that shows the critical bands, so a 94 on an
## 80% check is visibly bad luck rather than a mystery.

var result: CheckResult
var _roll_label: Label
var _bar: RollBar


func _init(check: CheckResult = null) -> void:
	result = check


func _ready() -> void:
	add_theme_stylebox_override("panel", UIKit.stylebox(Palette.PANEL_DARK, Palette.BORDER, 12))
	if result == null:
		return

	var v := UIKit.vbox(6)
	add_child(v)

	var head := UIKit.hbox(8)
	head.add_child(UIKit.label("%s CHECK" % result.stat_name.to_upper(), 14, Palette.stat_color(result.stat_name)))
	head.add_child(UIKit.spacer())
	head.add_child(UIKit.label(result.actor_name, 14, Palette.TEXT_DIM))
	v.add_child(head)

	if SaveSystem.get_setting("show_check_maths", true):
		var table := UIKit.vbox(2)
		for m in result.breakdown:
			var value := int(m["value"])
			table.add_child(UIKit.stat_row(
				str(m["label"]),
				"%s%d" % ["+" if value > 0 else "", value],
				Palette.SUCCESS if value > 0 else Palette.DANGER))
		v.add_child(table)

		var rule := ColorRect.new()
		rule.color = Palette.BORDER
		rule.custom_minimum_size.y = 1
		v.add_child(rule)

	v.add_child(UIKit.stat_row("Success chance", "%d%%" % result.final_chance, Palette.ACCENT))

	_bar = RollBar.new()
	_bar.result = result
	_bar.custom_minimum_size.y = 26
	v.add_child(_bar)

	var roll_row := UIKit.hbox(10)
	roll_row.add_child(UIKit.label("ROLL", 15, Palette.TEXT_DIM))
	_roll_label = UIKit.label("--", 26, Palette.TEXT)
	roll_row.add_child(_roll_label)
	roll_row.add_child(UIKit.spacer())
	var tier := UIKit.label(result.tier_name(), 22, result.tier_color())
	roll_row.add_child(tier)
	v.add_child(roll_row)

	if result.was_saved:
		v.add_child(UIKit.paragraph("Rescued by %s - that should have failed." % result.saved_by, 13, Palette.TEAL))

	_animate_roll(tier)


## Counts the die up to its final value, then punches the verdict in.
func _animate_roll(tier_label: Label) -> void:
	tier_label.modulate.a = 0.0
	var steps := 14
	var tween := create_tween()
	for i in range(steps):
		var shown: int = (result.roll + int(randf_range(-40, 40)) + 100) % 100 + 1
		if i == steps - 1:
			shown = result.roll
		tween.tween_callback(func() -> void: _roll_label.text = str(shown))
		tween.tween_interval(0.025 + 0.012 * i)
	tween.tween_callback(func() -> void:
		_roll_label.text = str(result.roll)
		_roll_label.add_theme_color_override("font_color", result.tier_color())
		_bar.reveal()
		Audio.play(_sfx_for_tier()))
	tween.tween_property(tier_label, "modulate:a", 1.0, 0.18)
	if result.is_critical():
		tween.tween_callback(func() -> void: UIKit.shake(self, 8.0))


func _sfx_for_tier() -> String:
	match result.tier:
		CheckResult.Tier.CRIT_SUCCESS: return "crit_success"
		CheckResult.Tier.SUCCESS: return "success"
		CheckResult.Tier.CRIT_FAILURE: return "crit_failure"
		_: return "failure"
