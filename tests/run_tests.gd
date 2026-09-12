extends SceneTree
## Headless test entry point.
##
##     godot --headless --script res://tests/run_tests.gd
##
## Exits 0 when everything passes, 1 otherwise, so it drops straight into CI.

const SUITES := [
	"res://tests/test_content.gd",
	"res://tests/test_stats.gd",
	"res://tests/test_skill_check.gd",
	"res://tests/test_recruitment.gd",
	"res://tests/test_heat_powerups.gd",
	"res://tests/test_prison.gd",
	"res://tests/test_save.gd",
	"res://tests/test_full_run.gd",
]

var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true

	print("JAILBREAK - test suite")
	print("Godot %s" % Engine.get_version_info().get("string", "?"))

	# Autoloads are attached to the tree after this script is compiled, so they
	# cannot be referenced here by name the way the suites reference them.
	var content := root.get_node_or_null("Content")
	if content == null:
		print("FATAL: the Content autoload is missing - run this from the project root.")
		quit(1)
		return true
	if not bool(content.get("loaded")):
		content.call("load_all")

	var runner := TestRunner.new()
	for path in SUITES:
		var script: Script = load(path)
		if script == null:
			runner.suite("loader")
			runner.check(false, "could not load suite " + str(path))
			continue
		var suite: Object = script.new()
		suite.call("run", runner)

	var failures := runner.report()
	quit(1 if failures > 0 else 0)
	return true
