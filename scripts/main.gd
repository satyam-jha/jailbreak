extends Control
## The root scene and the only scene. Owns the background, the HUD, the debug
## panel, and exactly one Screen at a time.
##
## Screens never reference each other - they emit navigate() and this decides
## what happens, which keeps the flow in section 4 of the design spec readable
## in one place.

const SCREEN_PATHS := {
	"main_menu": "res://scripts/screens/main_menu.gd",
	"recruitment": "res://scripts/screens/recruitment.gd",
	"party": "res://scripts/screens/party_overview.gd",
	"map": "res://scripts/screens/prison_map.gd",
	"encounter": "res://scripts/screens/encounter.gd",
	"powerup": "res://scripts/screens/powerup_select.gd",
	"escape": "res://scripts/screens/escape.gd",
	"summary": "res://scripts/screens/run_summary.gd",
	"how_to_play": "res://scripts/screens/how_to_play.gd",
	"settings": "res://scripts/screens/settings.gd",
}

var _host: MarginContainer
var _hud: HUD
var _current: Screen
var _debug_panel: DebugPanel
var _backdrop: Backdrop


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.build_theme()

	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_backdrop = Backdrop.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)

	_hud = HUD.new()
	_hud.visible = false
	_hud.party_requested.connect(func() -> void: go_to("party"))
	column.add_child(_hud)

	# A container, not a bare Control: containers fit their children on every
	# layout pass, which is what makes a screen fill the window even though it
	# is added before the window has been laid out.
	_host = MarginContainer.new()
	_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_host)

	if Content.loaded and not Content.load_errors.is_empty():
		_show_content_error()
		return

	go_to("main_menu")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key.keycode == KEY_F1 and Game.debug_enabled:
		_toggle_debug()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_F11:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()


## --- Navigation ----------------------------------------------------------

func go_to(screen_name: String, data: Dictionary = {}) -> void:
	if not SCREEN_PATHS.has(screen_name):
		push_error("[Main] Unknown screen: " + screen_name)
		return

	if _current != null and is_instance_valid(_current):
		_host.remove_child(_current)
		_current.queue_free()
		_current = null

	var script: Script = load(SCREEN_PATHS[screen_name])
	var screen: Screen = script.new()
	screen.payload = data
	screen.navigate.connect(go_to)
	_current = screen
	_host.add_child(screen)

	# Each screen declares whether it wants the status bar (see scripts/ui/screen.gd).
	_hud.visible = screen.show_hud and not Game.party.is_empty()
	if _hud.visible:
		_hud.refresh()

	_backdrop.set_mood(screen_name)

	if not screen.music_mood.is_empty():
		Audio.play_music(screen.music_mood)


func _toggle_debug() -> void:
	if _debug_panel != null and is_instance_valid(_debug_panel):
		_debug_panel.queue_free()
		_debug_panel = null
		return
	_debug_panel = DebugPanel.new()
	_debug_panel.main = self
	add_child(_debug_panel)


func _toggle_fullscreen() -> void:
	var windowed := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if windowed else DisplayServer.WINDOW_MODE_WINDOWED)


func refresh_hud() -> void:
	if _hud != null:
		_hud.refresh()


## Shown instead of the game if data/ could not be read, because a silent
## failure here would look like a dozen unrelated bugs later.
func _show_content_error() -> void:
	var box := UIKit.margin(40)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	var v := UIKit.vbox(12)
	box.add_child(v)
	v.add_child(UIKit.title("CONTENT FAILED TO LOAD", 30, Palette.DANGER))
	v.add_child(UIKit.body("The game could not read its data files. If this is an exported build, add *.json to the export preset's non-resource file filter."))
	for err in Content.load_errors:
		v.add_child(UIKit.paragraph("- " + str(err), 14, Palette.TEXT_DIM))
