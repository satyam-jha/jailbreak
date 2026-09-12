extends RefCounted
## Prison generation: every generated map must be walkable start to wall.


static func run(t: TestRunner) -> void:
	t.suite("Prison generation")

	var invalid: Array = []
	var no_start := 0
	var no_final := 0
	var too_short := 0
	var room_variety: Dictionary = {}
	var path_variety: Dictionary = {}
	var gated_starts := 0

	for seed_value in range(300):
		Rng.start_run(20000 + seed_value)
		Game.start_run(20000 + seed_value)
		while not Game.party_is_full():
			Game.recruit(Game.draw_candidates()[0])

		var map := PrisonGenerator.generate(Game.party)
		var check := PrisonGenerator.validate(map)
		if not bool(check["ok"]):
			invalid.append("seed %d: %s" % [20000 + seed_value, str(check["reason"])])
			continue

		var nodes: Dictionary = map["nodes"]
		var start_node: Dictionary = nodes[str(map["start"])]
		var final_node: Dictionary = nodes[str(map["final"])]

		if str(start_node.get("room_id", "")) != PrisonGenerator.START_ROOM:
			no_start += 1
		if str(final_node.get("room_id", "")) != PrisonGenerator.FINAL_ROOM:
			no_final += 1
		if not bool(final_node.get("is_final", false)):
			no_final += 1
		if int(map["layer_count"]) < PrisonGenerator.MIN_LAYERS:
			too_short += 1
		if not (start_node.get("gate", {}) as Dictionary).is_empty():
			gated_starts += 1

		for node_id in nodes.keys():
			var n: Dictionary = nodes[node_id]
			room_variety[str(n.get("room_id", ""))] = true
			path_variety[int(n.get("path_type", 0))] = true

	t.check(invalid.is_empty(), "every generated prison is connected and walkable (%s)" % str(invalid.slice(0, 3)))
	t.equal(no_start, 0, "every run starts in the cell block")
	t.equal(no_final, 0, "every run ends at the outer wall")
	t.equal(too_short, 0, "every prison is at least MIN_LAYERS deep")
	t.equal(gated_starts, 0, "the starting room is never behind a gate")
	t.check(room_variety.size() >= 8, "generation uses a wide spread of room types (%d)" % room_variety.size())
	t.equal(path_variety.size(), 3, "safe, risky and secret paths all appear")

	# A deliberately broken map must be rejected, or the validator proves nothing.
	var broken := {
		"nodes": {
			"a": {"id": "a", "connections": ["b"], "path_type": PrisonGenerator.Path.SAFE},
			"b": {"id": "b", "connections": [], "path_type": PrisonGenerator.Path.SAFE},
			"orphan": {"id": "orphan", "connections": ["b"], "path_type": PrisonGenerator.Path.SAFE},
		},
		"start": "a", "final": "b", "layer_count": 2,
	}
	t.check(not bool(PrisonGenerator.validate(broken)["ok"]), "the validator rejects a disconnected map")

	var unreachable := {
		"nodes": {
			"a": {"id": "a", "connections": [], "path_type": PrisonGenerator.Path.SAFE},
			"b": {"id": "b", "connections": [], "path_type": PrisonGenerator.Path.SAFE},
		},
		"start": "a", "final": "b", "layer_count": 2,
	}
	t.check(not bool(PrisonGenerator.validate(unreachable)["ok"]), "the validator rejects an unreachable wall")

	# Gates are only satisfiable by somebody who really qualifies.
	Rng.start_run(31)
	Game.start_run(31)
	while not Game.party_is_full():
		Game.recruit(Game.draw_candidates()[0])
	var impossible := {"gate": {"type": "stat", "stat": "strength", "value": 99}}
	t.check(not PrisonGenerator.party_can_enter(impossible, Game.party), "an impossible stat gate blocks the party")
	var trivial := {"gate": {"type": "stat", "stat": "strength", "value": 1}}
	t.check(PrisonGenerator.party_can_enter(trivial, Game.party), "a trivial stat gate lets the party through")
	t.check(PrisonGenerator.party_can_enter({}, Game.party), "an ungated room is always enterable")

	# Same seed, same prison.
	Rng.start_run(8080)
	Game.start_run(8080)
	while not Game.party_is_full():
		Game.recruit(Game.draw_candidates()[0])
	var first := PrisonGenerator.generate(Game.party)
	Rng.start_run(8080)
	Game.start_run(8080)
	while not Game.party_is_full():
		Game.recruit(Game.draw_candidates()[0])
	var second := PrisonGenerator.generate(Game.party)
	t.equal(JSON.stringify(first), JSON.stringify(second), "the same seed regenerates the same prison")
