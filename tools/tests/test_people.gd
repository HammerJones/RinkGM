extends SceneTree
## People: interests decide who comes, kids bring a parent, bad nights are
## remembered, dialogue and quests run against the world, brains get hungry
## and cold, and the real data files load and hang together.
##   godot --headless --path . --script res://tools/tests/test_people.gd

var failures := 0

const EVENTS := {"kinds": {
	"figure_practice": {"label": "Figure practice", "use": "figure", "pull": 0.4, "spectator_cap": 0.1, "participants": [2, 20], "ages": [5, 25]},
	"beer_league": {"label": "Beer league", "use": "hockey", "pull": 0.5, "spectator_cap": 0.2, "participants": [10, 40], "ages": [19, 70]},
	"minor_hockey": {"label": "Minor hockey", "use": "hockey", "pull": 0.6, "spectator_cap": 0.5, "participants": [10, 40], "ages": [5, 17]},
}}


func _initialize() -> void:
	_check_attendance()
	_check_memory()
	_check_dialogue_and_quests()
	_check_brain()
	_check_data()
	_check_life()
	if failures:
		printerr("test_people: %d failure(s)" % failures)
	else:
		print("test_people: ok")
	quit(1 if failures else 0)


func _rec(id: String, age: int, interests: Dictionary, extra := {}) -> Dictionary:
	var d := {"id": id, "name": id.capitalize(), "age": age, "town": "millbrook", "interests": interests,
		"traits": {"warmth": 0.5, "chatter": 0.5, "patience": 0.5, "pride": 0.5, "nerve": 0.5, "humour": 0.5}}
	d.merge(extra, true)
	return d


func _check_attendance() -> void:
	var recs: Array = []
	for i in 40:
		recs.append(_rec("skatefan_%d" % i, 40, {"figure_practice": {"watch": 0.9}}))
		recs.append(_rec("hockeyfan_%d" % i, 40, {"beer_league": {"watch": 0.9}}))
	recs.append(_rec("kid", 9, {"minor_hockey": {"play": 1.0}}, {"family": ["mum"]}))
	recs.append(_rec("mum", 38, {}, {"family": ["kid"]}))
	recs.append(_rec("worker", 50, {}, {"schedule": [{"days": [2], "from": 5.0, "to": 13.0, "place": "canteen", "doing": "work"}]}))
	var cast := Cast.from_records(recs, EVENTS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var ev := {"kind": "figure_practice", "weekday": 2, "hour": 6.0, "hours": 2.0, "ice_rep": 60.0, "seats": 400}
	var came := Attendance.who_comes(cast, ev, rng)
	var skate := 0
	var hockey := 0
	var worker := false
	for e in came:
		skate += 1 if e.person.id.begins_with("skatefan") else 0
		hockey += 1 if e.person.id.begins_with("hockeyfan") else 0
		worker = worker or (e.person.id == "worker" and e.as == "work")
	if skate < 5 or hockey > 0:
		_fail("figure fans should come to figure practice and hockey fans shouldn't (%d, %d)" % [skate, hockey])
	if not worker:
		_fail("staff on shift should be there")
	# a kid playing brings mum
	var mum := 0
	for t in 20:
		for e in Attendance.who_comes(cast, {"kind": "minor_hockey", "weekday": 6, "hour": 9.0, "ice_rep": 70.0}, rng):
			if e.person.id == "mum":
				mum += 1
				if e.as != "watch":
					_fail("mum should watch")
	if mum == 0:
		_fail("a kid at minor hockey should bring a parent at least once in 20 Saturdays")
	# nobody is out at 2 am, and bad ice keeps the impatient home
	if not Attendance.who_comes(cast, {"kind": "beer_league", "weekday": 3, "hour": 2.0, "ice_rep": 60.0}, rng).is_empty():
		_fail("nobody comes at 2 am")
	var good := 0
	var bad := 0
	for t in 10:
		good += Attendance.who_comes(cast, {"kind": "beer_league", "weekday": 3, "hour": 21.0, "ice_rep": 90.0}, rng).size()
		bad += Attendance.who_comes(cast, {"kind": "beer_league", "weekday": 3, "hour": 21.0, "ice_rep": 15.0}, rng).size()
	if bad >= good * 0.8:
		_fail("bad ice should keep people home (%d vs %d)" % [bad, good])


func _check_memory() -> void:
	var p := Person.from_record(_rec("ann", 40, {"beer_league": {"watch": 0.8}}))
	var came := [{"person": p, "as": "play"}]
	Attendance.settle(came, {"day": 1, "kind": "beer_league", "rating": 70.0, "wet_wait": 25.0})
	if p.mood >= 0.7 or not "waited" in p.grudge():
		_fail("a long wait for wet ice should sting and be remembered (%.2f, '%s')" % [p.mood, p.grudge()])
	for d in 40:
		p.fade(d)
	if p.grudge() != "":
		_fail("grudges fade after a month")


func _check_dialogue_and_quests() -> void:
	var bev := _rec("bev", 58, {}, {"dialogue": "test_bev"})
	var cast := Cast.from_records([bev], EVENTS)
	var quests := {"quests": [{"id": "whetstone", "title": "The Whetstone", "giver": "bev",
		"start": [{"rel_gte": ["bev", 10]}],
		"steps": [{"id": "find", "text": "Find it", "goal": {"type": "visit", "place": "plant_room"}},
			{"id": "back", "text": "Bring it back", "goal": {"type": "talk", "to": "bev"}}],
		"reward": [{"rel": ["bev", 15]}, {"item": ["free_sharpening", 5]}]}],
		"favours": [{"id": "lost_mitten", "giver": "archetype:retiree_regular", "title": "{known_as}'s mitten",
			"steps": [{"id": "find", "text": "Find the mitten", "goal": {"type": "visit", "place": "lobby"}}], "reward": [{"rel": ["self", 5]}]}]}
	var w := StoryWorld.create(cast, null, quests)
	w.owner_name = "Sam"
	Conversation._trees["test_bev"] = {"start": [{"if": [{"not_flag": "met_bev"}], "node": "first"}, {"node": "hub"}],
		"nodes": {"first": {"say": "You're {owner}.", "do": [{"set": "met_bev"}], "options": [
			{"text": "Hi.", "do": [{"rel": ["bev", 12]}], "to": "hub"}, {"text": "Hidden", "if": [{"flag": "nope"}], "to": "hub"}]},
			"hub": {"say": "What?", "hub": true, "options": [{"text": "Bye.", "to": "end"}]}}}
	Conversation._trees["quests/whetstone"] = {"nodes": {
		"offer": {"say": "Find my whetstone?", "options": [{"text": "Sure.", "do": [{"quest_start": "whetstone"}], "to": "end"}]},
		"progress": {"say": "Well?", "options": []}, "complete": {"say": "You found it!", "options": []}}}
	var c := Conversation.open(w, cast.person("bev"))
	if c.line != "You're Sam." or c.choices.size() != 1:
		_fail("first meeting: '%s' %s" % [c.line, c.choices])
	c.choose(0)
	if c.choices.is_empty() or c.choices[0].text != "About The Whetstone...":
		_fail("the hub should offer Bev's quest once she likes you: %s" % [c.choices])
		return
	c.choose(0)
	c.choose(0)
	if w.quests.status("whetstone") != "active":
		_fail("accepting should start the quest")
	w.quests.notify("visit", {"place": "plant_room"})
	if w.quests.step_id("whetstone") != "back":
		_fail("visiting the plant room should finish step one")
	c = Conversation.open(w, cast.person("bev"))
	if w.quests.status("whetstone") != "done" or c.line != "You found it!":
		_fail("talking to Bev should finish the quest and thank you: %s '%s'" % [w.quests.status("whetstone"), c.line])
	if int(w.items.get("free_sharpening", 0)) != 5 or cast.person("bev").relation("owner") != 27:
		_fail("rewards: %s, rel %d" % [w.items, cast.person("bev").relation("owner")])
	# townsfolk get the generic tree, with their own favour
	var ret := Person.from_record(_rec("gord", 74, {"public_skate": {"play": 0.8}}, {"archetype": "retiree_regular"}), true)
	cast.people[ret.id] = ret
	c = Conversation.open(w, ret)
	var texts := c.choices.map(func(o): return o.text)
	if not "Anything I can do for you?" in texts or not "What brings you to the rink?" in texts:
		_fail("a townsperson should chat and ask a favour: %s" % [texts])
	c.choose(texts.find("What brings you to the rink?"))
	if not "public skate" in c.line.to_lower():
		_fail("Gord should say he comes for public skate: '%s'" % c.line)
	# saves
	var d: Dictionary = JSON.parse_string(JSON.stringify(w.state()))
	var w2 := StoryWorld.create(Cast.from_records([bev], EVENTS), null, quests)
	w2.apply_state(d)
	if w2.quests.status("whetstone") != "done" or w2.cast.person("bev").relation("owner") != 27 or not w2.flags.has("met_bev"):
		_fail("story state should survive a save")


func _check_brain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var p := Person.from_record(_rec("fan", 40, {"beer_league": {"watch": 0.2}}))
	var b := NpcBrain.make(p, "watch", "beer_league", rng)
	b.arrive()
	var went := {}
	for i in 240:
		if b.think(0.5, {"phase": "on", "air_c": 4.0, "canteen_open": true}):
			went[b.place] = true
			b.arrive()
			if b.activity == "queue":
				b.served()
				b.arrive()
	if not went.has("canteen") or not went.has("washroom"):
		_fail("two hours in the stands should mean the canteen and the washroom: %s" % [went.keys()])
	var player := NpcBrain.make(p, "play", "beer_league", rng)
	player.arrive()
	player.think(10.0, {"phase": "on", "ice_wet": true})
	player.arrive()
	for i in 20:
		player.think(1.0, {"phase": "on", "ice_wet": true})
	if player.activity != "gate" or player.wet_minutes < 10.0:
		_fail("players wait at the gate while the ice is wet (%s, %.0f)" % [player.activity, player.wet_minutes])
	player.think(1.0, {"phase": "on", "ice_wet": false})
	if player.place != "ice":
		_fail("dry ice: on they go")


## The real data: every person, archetype, quest and tree loads and refers
## to things that exist.
func _check_data() -> void:
	if not FileAccess.file_exists(Cast.CAST_PATH):
		print("test_people: no cast data yet")
		return
	var cast := Cast.load_region(1)
	var named := cast.named().size()
	var kinds: Dictionary = cast.events.get("kinds", {})
	print("people: %d (%d named), %d archetypes, %d event kinds" % [cast.people.size(), named, cast.archetypes.size(), kinds.size()])
	if named < 40 or cast.people.size() < 300:
		_fail("the valley needs its people (%d named, %d total)" % [named, cast.people.size()])
	for p: Person in cast.people.values():
		for k in p.interests:
			if not kinds.has(k):
				_fail("%s likes unknown event kind %s" % [p.id, k])
				break
		for r in p.rel:
			if r != "owner" and cast.person(r) == null:
				_fail("%s knows nobody called %s" % [p.id, r])
		if not p.generated and Conversation.tree_for(p).get("id", "") == "generic":
			_fail("%s has no dialogue tree" % p.id)
	for kind in kinds:
		var players := cast.people.values().filter(func(p): return p.interest(kind, "play") >= 0.5).size()
		var fans := cast.people.values().filter(func(p): return p.interest(kind, "watch") >= 0.5).size()
		if kind != "special" and (players < 3 or fans < 3):
			_fail("%s needs people who love it (%d play, %d watch)" % [kind, players, fans])
	var w := StoryWorld.create(cast)
	for id in w.quests.defs:
		var d: Dictionary = w.quests.defs[id]
		if not str(d.giver).begins_with("archetype:") and cast.person(str(d.giver)) == null:
			_fail("quest %s: no giver %s" % [id, d.giver])
	# talk to everyone named: every tree opens and every option leads somewhere
	for p in cast.named():
		var c := Conversation.open(w, p)
		var steps := 0
		while not c.ended and steps < 12:
			if c.line.strip_edges() == "":
				_fail("%s says nothing at %s" % [p.id, c.node_id])
				break
			c.choose(rng_pick(c.choices.size()))
			steps += 1


## Townsfolk have jobs with hours, backstories with nothing left unfilled,
## watchers have reasons, shift swaps read cleanly, and the local-AI
## setting is off unless the player turns it on (and never phones out here).
func _check_life() -> void:
	if not FileAccess.file_exists(Cast.CAST_PATH):
		return
	AiDialogue.blocked = true
	WorldSettings.path = "user://test_people_settings.cfg"
	if FileAccess.file_exists(WorldSettings.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WorldSettings.path))
	WorldSettings.reload()
	var cast := Cast.load_region(1)
	var gen := cast.people.values().filter(func(p): return p.generated)
	var told := 0
	var working := 0
	var adults := 0
	for p: Person in gen:
		if p.backstory != "":
			told += 1
		if "{" in p.backstory or "}" in p.backstory:
			_fail("%s's backstory has a hole: %s" % [p.id, p.backstory])
		if p.is_kid():
			if p.age < 13 and not p.work.is_empty():
				_fail("%s is %d and has a job (%s)" % [p.id, p.age, p.job])
			continue
		if p.age < 65:
			adults += 1
		if p.job == "" or p.work.is_empty():
			continue
		working += 1
		var days: Array = p.work.get("days", [])
		if days.is_empty():
			_fail("%s works as %s on no days" % [p.id, p.job])
			continue
		var from := float(p.work.get("from", 9.0))
		var to := float(p.work.get("to", 17.0))
		var mid := fmod((from + to) / 2.0 if to > from else from + 1.0, 24.0)
		if not p.job_block(int(days[0]), mid) or p.is_free(int(days[0]), mid):
			_fail("%s should be at work (%s) mid-shift on day %d" % [p.id, p.job, int(days[0])])
	print("life: %d of %d townsfolk have a backstory, %d of %d working-age adults have a job" % [told, gen.size(), working, adults])
	if told < gen.size() * 0.95:
		_fail("every townsperson needs a backstory (%d of %d)" % [told, gen.size()])
	if working < adults * 0.6:
		_fail("most working-age adults have a job (%d of %d)" % [working, adults])
	var storied := gen.filter(func(p): return p.backstory != "" and not p.is_kid())
	var sample: Person = storied[0]
	var w := StoryWorld.create(cast)
	var c := Conversation.open(w, sample)
	var about := Conversation.first_person(sample.backstory, sample.known_as)
	if about.strip_edges() == "" or "{" in about:
		_fail("@about should tell %s's story in their own words ('%s')" % [sample.id, about])
	# every watcher at a real Saturday game has a reason, and it reads
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var came := Attendance.who_comes(cast, {"kind": "minor_hockey", "weekday": 6, "hour": 9.0, "hours": 1.5, "ice_rep": 70.0, "seats": 600}, rng)
	var why := {}
	for e in came:
		var r: Dictionary = e.get("reason", {})
		if str(r.get("why", "")) == "":
			_fail("%s came as %s with no reason" % [e.person.id, e.as])
			continue
		why[r.why] = int(why.get(r.why, 0)) + 1
		if e.as == "watch":
			var line := Conversation.open(w, e.person, r).why_line()
			if line == "" or "{" in line:
				_fail("%s (%s) can't say why they came: '%s'" % [e.person.id, r.why, line])
	print("life: minor hockey Saturday, why they came: %s" % [why])
	if not why.has("parent"):
		_fail("parents should come to watch their kids")
	# shift swaps: a keen parent with a flexible boss gets one, and it reads
	var mum := Person.from_record(_rec("swap_mum", 40, {}, {"traits": {"warmth": 0.5, "chatter": 0.5, "patience": 0.5, "pride": 0.5, "nerve": 1.0, "humour": 0.5},
		"job": "nurse", "work": {"title": "nurse", "employer": "the hospital", "days": [6], "from": 7.0, "to": 19.0, "flex": 1.0, "boss": "Marjorie", "place": "away"},
		"schedule": [{"days": [6], "from": 7.0, "to": 19.0, "place": "away", "doing": "work"}]}))
	var kid := Person.from_record(_rec("swap_kid", 10, {}))
	var swaps := 0
	for t in 30:
		var s := Attendance.negotiate(mum, kid, {"kind": "minor_hockey", "weekday": 6, "hour": 9.0}, 1.0, rng)
		if s != "":
			swaps += 1
			if "{" in s:
				_fail("a shift swap line has a hole: %s" % s)
	if swaps == 0:
		_fail("a parent working during the final should sometimes swap a shift (0 of 30)")
	if Attendance.negotiate(mum, kid, {"kind": "minor_hockey", "weekday": 6, "hour": 21.0}, 1.0, rng) != "":
		_fail("no swap needed when they're off work")
	# local AI: off by default, prompt builds, replies are cleaned, no network
	if WorldSettings.get_bool("ai_dialogue") or AiDialogue.enabled():
		_fail("local AI dialogue is off by default")
	var ai := AiDialogue.new()
	root.add_child(ai)
	if ai.ask(c, func(_l): pass):
		_fail("AiDialogue.ask should do nothing while it's off")
	WorldSettings.set_value("ai_dialogue", true)
	if AiDialogue.enabled():
		_fail("tests block the network even with the setting on")
	if ai.ask(c, func(_l): pass) or ai.get_child_count() > 0:
		_fail("no HTTP request in tests")
	WorldSettings.set_value("ai_dialogue", false)
	ai.queue_free()
	var pr := AiDialogue.prompt(c)
	if not sample.name in pr or not "ONE" in pr:
		_fail("the AI prompt should say who's talking")
	if AiDialogue.clean("  \"Cold one tonight, eh.\"\nSecond line") != "Cold one tonight, eh.":
		_fail("AI replies are cut to one clean line ('%s')" % AiDialogue.clean("\"Cold one tonight, eh.\"\nSecond line"))
	if AiDialogue.clean("*waves*") != "" or AiDialogue.clean("") != "":
		_fail("stage directions and empty replies are dropped")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(WorldSettings.path))


var _r := RandomNumberGenerator.new()
func rng_pick(n: int) -> int:
	return _r.randi() % maxi(n, 1)


func _fail(msg: String) -> void:
	printerr(msg)
	failures += 1
