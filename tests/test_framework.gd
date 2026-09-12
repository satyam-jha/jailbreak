class_name TestRunner
extends RefCounted
## A deliberately tiny assertion harness. No plugin, no dependency - run it with
##
##     godot --headless --script res://tests/run_tests.gd
##
## Exit code 0 means everything passed.

var passed := 0
var failed := 0
var current_suite := ""
var failures: Array = []


func suite(name: String) -> void:
	current_suite = name
	print("\n== %s ==" % name)


func check(condition: bool, description: String) -> bool:
	if condition:
		passed += 1
		print("  ok    %s" % description)
	else:
		failed += 1
		failures.append("%s :: %s" % [current_suite, description])
		print("  FAIL  %s" % description)
	return condition


func equal(actual: Variant, expected: Variant, description: String) -> bool:
	var ok: bool = actual == expected
	if not ok:
		description = "%s (got %s, expected %s)" % [description, str(actual), str(expected)]
	return check(ok, description)


func between(value: float, low: float, high: float, description: String) -> bool:
	var ok := value >= low and value <= high
	if not ok:
		description = "%s (got %s, wanted %s..%s)" % [description, str(value), str(low), str(high)]
	return check(ok, description)


func report() -> int:
	print("\n" + "-".repeat(52))
	print("%d passed, %d failed" % [passed, failed])
	if failed > 0:
		print("\nFailures:")
		for f in failures:
			print("  - " + str(f))
	print("-".repeat(52))
	return failed
