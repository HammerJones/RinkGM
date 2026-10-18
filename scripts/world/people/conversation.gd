class_name Conversation
extends RefCounted
## One conversation with one person, run against a StoryWorld. Trees live in
## data/world/dialogue/<id>.json (PEOPLE.md 6); quest trees in
## data/world/dialogue/quests/<quest id>.json with "offer", "progress" and
## "complete" nodes, reached as "quest:<id>:<node>". Nodes marked "hub" get
## the speaker's quests and favours added to their options automatically.
## Townsfolk without a tree of their own get a built-in one made from their
## archetype, interests and mood, so everyone has something to say.
##
##   var c := Conversation.open(world, bev)
##   print(c.line); for o in c.choices: print(o.text)
##   c.choose(0)

const DIR := "res://data/world/dialogue/"

static var _trees := {}

var world: StoryWorld
var speaker: Person
var tree := {}
var node_id := ""
var line := ""
var choices: Array = []   # [{"text", "to", "do"}] the visible options
var ended := false


static func open(w: StoryWorld, p: Person) -> Conversation:
	var c := Conversation.new()
	c.world = w
	c.speaker = p
	c.tree = tree_for(p)
	# a quest step that sends you to this person can give them their own
	# lines: an "at_<person id>" node in the quest's tree
	for id in w.quests.talk_steps(p):
		if not str(w.quests.def(id).get("giver", "")) == p.id and _load("quests/" + id).get("nodes", {}).has("at_" + p.id):
			w.quests.notify("talk", {"to": p.id})
			c._goto("quest:%s:at_%s" % [id, p.id])
			return c
	# talking to someone can be a quest goal in itself
	w.quests.notify("talk", {"to": p.id})
	var just_done := ""
	for id in w.quests.states:
		var st: Dictionary = w.quests.states[id]
		if st.status == "done" and str(w.quests.def(id).get("giver", "")) == p.id and not st.get("thanked", false):
			just_done = id
			st.thanked = true
			break
	if just_done != "":
		c._goto("quest:%s:complete" % just_done)
		return c
	for s in c.tree.get("start", []):
		if w.check(s.get("if", []), p):
			c._goto(str(s.node))
			return c
	c._goto("hub")
	return c


static func tree_for(p: Person) -> Dictionary:
	var t := _load(p.dialogue)
	if t.is_empty():
		t = _load("archetype_" + p.archetype)
	if t.is_empty():
		t = _generic()
	return t


## A one-off line for `topic` ("idle", "bad_ice", "goal"...): the person's own
## barks first, then their archetype's.
static func bark(w: StoryWorld, p: Person, topic: String) -> String:
	var lines: Array = _load(p.dialogue).get("barks", {}).get(topic, [])
	var s := str(lines[w.rng.randi() % lines.size()]) if not lines.is_empty() else w.cast.bark(p, topic, w.rng)
	return w.fill(s, p)


func choose(i: int) -> void:
	if ended or i < 0 or i >= choices.size():
		return
	var o: Dictionary = choices[i]
	var r := world.apply(o.get("do", []), speaker)
	world.quests.tick()
	if r.get("end", false) or str(o.get("to", "")) in ["", "end"]:
		_end()
		return
	_goto(str(o.to))


func _goto(ref: String) -> void:
	node_id = ref
	var n := _node(ref)
	if n.is_empty():
		_end()
		return
	var say = n.get("say", "")
	if say is Array:
		say = say[world.rng.randi() % say.size()] if not say.is_empty() else ""
	line = world.fill(_special(str(say)), speaker)
	var r := world.apply(n.get("do", []), speaker)
	world.quests.tick()
	choices.clear()
	for o in n.get("options", []):
		if world.check(o.get("if", []), speaker):
			var oo: Dictionary = o.duplicate()
			oo.to = _resolve(str(o.get("to", "end")), ref)
			oo.text = world.fill(str(o.get("text", "...")), speaker)
			choices.append(oo)
	if n.get("hub", false):
		_add_quest_options()
	if r.get("end", false) or (choices.is_empty() and n.get("options", []).is_empty() and not n.get("hub", false)):
		choices.append({"text": "[Leave]", "to": "end"})
	if choices.is_empty():
		choices.append({"text": "[Leave]", "to": "end"})


func _end() -> void:
	ended = true
	choices.clear()


## "quest:x:node", a node in this tree, or a bare node name inside the quest
## tree we're already in.
func _node(ref: String) -> Dictionary:
	if ref.begins_with("quest:"):
		var parts := ref.split(":")
		var qt := _quest_tree(parts[1])
		return qt.get("nodes", {}).get(parts[2] if parts.size() > 2 else "offer", {})
	return tree.get("nodes", {}).get(ref, {})


func _resolve(to: String, from: String) -> String:
	if from.begins_with("quest:") and not to.begins_with("quest:") and to != "end":
		var parts := from.split(":")
		if _quest_tree(parts[1]).get("nodes", {}).has(to):
			return "quest:%s:%s" % [parts[1], to]
	return to


func _quest_tree(id: String) -> Dictionary:
	var t := _load("quests/" + id)
	if t.is_empty():
		t = _favour_tree(id)
	return t


func _add_quest_options() -> void:
	var q := world.quests
	for id in q.offers_from(speaker):
		var d := q.def(id)
		choices.insert(0, {"text": world.fill(str(d.get("prompt", "About %s..." % d.get("title", id))), speaker), "to": "quest:%s:offer" % id})
	for id in q.involving(speaker):
		if str(q.def(id).get("giver", "")) == speaker.id:
			choices.insert(0, {"text": "About %s..." % world.fill(str(q.def(id).get("title", id))), "to": "quest:%s:progress" % id})
	if speaker.generated or q.favours.any(func(f): return str(f.get("giver", "")) == "archetype:" + speaker.archetype):
		var fid := q.favour_from(speaker)
		if fid != "":
			choices.insert(0, {"text": "Anything I can do for you?", "to": "quest:%s:offer" % fid})


## Placeholder lines the generic tree fills from the person.
func _special(s: String) -> String:
	match s:
		"@how_are_things":
			var g := speaker.grudge()
			if speaker.mood < 0.45 and g != "":
				return "Honestly? Last time I %s." % g if not g.begins_with("the ") else "Honestly? Last time %s." % g
			var b := bark(world, speaker, "greet_owner")
			return b if b != "" else "Can't complain. Well, I could, but I won't."
		"@ice":
			var topic := "good_ice" if world.ice_word() in ["glass", "good"] else ("wet_ice" if world.ice_word() == "wet" else ("bad_ice" if world.ice_word() in ["chewed up", "slush"] else "idle"))
			var b := bark(world, speaker, topic)
			return b if b != "" else "Ice is %s today." % world.ice_word()
		"@why_here":
			var play := speaker.favourites("play", 1)
			var watch := speaker.favourites("watch", 2)
			if not play.is_empty():
				return "Me? I'm here for %s. Wouldn't miss it." % _label(play[0])
			if not watch.is_empty():
				return "I come for %s, mostly. %s" % [_label(watch[0]), "And %s, if it's on." % _label(watch[1]) if watch.size() > 1 else ""]
			return "Somebody has to keep the bench warm."
		"@about":
			return speaker.bio if speaker.bio != "" else "%s, from %s. %s" % [speaker.name, speaker.town.capitalize(), str(world.cast.archetype(speaker.archetype).get("label", ""))]
	return s


func _label(kind: String) -> String:
	return str(world.cast.kind_info(kind).get("label", kind.replace("_", " "))).to_lower()


## Built-in quest tree for a favour, from its summary and steps.
func _favour_tree(id: String) -> Dictionary:
	var d := world.quests.def(id)
	if d.is_empty():
		return {}
	return {"nodes": {
		"offer": {"say": str(d.get("ask", d.get("summary", "Could you do me a favour?"))), "options": [
			{"text": "Sure, leave it with me.", "do": [{"quest_start": id}, {"rel": ["self", 2]}], "to": "thanks"},
			{"text": "Not today, sorry.", "to": "end"}]},
		"thanks": {"say": "You're a gem.", "options": []},
		"progress": {"say": world.quests.step_text(id) if world.quests.status(id) == "active" else "All sorted, thanks.", "options": []},
		"complete": {"say": str(d.get("thanks", "That's perfect. Thank you.")), "options": []},
	}}


static func _generic() -> Dictionary:
	return {"id": "generic", "start": [{"node": "hub"}], "nodes": {
		"hub": {"say": "@how_are_things", "hub": true, "options": [
			{"text": "How's the ice treating you?", "to": "ice"},
			{"text": "What brings you to the rink?", "to": "why"},
			{"text": "Tell me about yourself.", "to": "about"},
			{"text": "Enjoy yourself.", "to": "end"}]},
		"ice": {"say": "@ice", "options": [{"text": "Good to know.", "to": "hub"}]},
		"why": {"say": "@why_here", "options": [{"text": "Glad you came.", "do": [{"rel": ["self", 1]}], "to": "hub"}]},
		"about": {"say": "@about", "options": [{"text": "Nice to meet you.", "to": "hub"}]},
	}}


static func _load(id: String) -> Dictionary:
	if id == "":
		return {}
	if _trees.has(id):
		return _trees[id]
	var path := DIR + id + ".json"
	var t := {}
	if FileAccess.file_exists(path):
		var v = JSON.parse_string(FileAccess.get_file_as_string(path))
		t = v if v is Dictionary else {}
	_trees[id] = t
	return t
