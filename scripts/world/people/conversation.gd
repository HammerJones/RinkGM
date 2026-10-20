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
## Lines everyone shares, by reason and topic (data/world/dialogue/_life.json).
const LIFE := "_life"
## Kin words for {kin}: the speaker's relation to the person they came for.
const KIN_WORD := {"parent": ["my son", "my daughter", "my kid"], "grandparent": ["my grandson", "my granddaughter", "my grandkid"],
	"sibling": ["my brother", "my sister", "my sibling"], "partner": ["my husband", "my wife", "my partner"],
	"friend": ["my buddy", "my friend", "my friend"], "date": ["my date", "my date", "my date"],
	"child": ["my dad", "my mom", "my parent"], "grandchild": ["my grandpa", "my grandma", "my grandparent"]}

static var _trees := {}

var world: StoryWorld
var speaker: Person
var tree := {}
var node_id := ""
var line := ""
var choices: Array = []   # [{"text", "to", "do"}] the visible options
var ended := false
## Why they're in the building and what they're doing (RinkPeople.talk):
## Attendance's reason plus "activity". Empty when talked to outside the rink.
var reason := {}
## An extra line from the optional local model (AiDialogue), shown under `line`.
var ai_line := ""


static func open(w: StoryWorld, p: Person, why := {}) -> Conversation:
	var c := Conversation.new()
	c.world = w
	c.speaker = p
	c.reason = why
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
static func bark(w: StoryWorld, p: Person, topic: String, why := {}) -> String:
	var lines: Array = _load(p.dialogue).get("barks", {}).get(topic, [])
	var s := str(lines[w.rng.randi() % lines.size()]) if not lines.is_empty() else w.cast.bark(p, topic, w.rng)
	if s == "":
		s = pick_filled(_load(LIFE).get("barks", {}).get(topic, []), w, p, why)
	if topic == "negotiated":
		s = str(why.get("negotiated", s))
	return _cap(w.fill(fill_reason(s, w, p, why), p))


static func _cap(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1) if s != "" else s


## A line from `lines` whose reason tokens can all be filled, or "".
static func pick_filled(lines: Array, w: StoryWorld, p: Person, why: Dictionary) -> String:
	if lines.is_empty():
		return ""
	var tok := reason_tokens(w, p, why)
	var start := w.rng.randi() % lines.size()
	for i in lines.size():
		var s := str(lines[(start + i) % lines.size()])
		var ok := true
		for k in REASON_TOKENS:
			if ("{%s}" % k) in s and not tok.has(k):
				ok = false
				break
		if ok:
			return s
	return ""


const REASON_TOKENS := ["for", "they", "they_cap", "them", "their", "kin", "kin_cap", "kin_bare", "kin_upper", "for_upper", "until", "doing", "start"]


## Tokens about why `p` is here: who for, their pronouns, until when.
static func reason_tokens(w: StoryWorld, p: Person, why: Dictionary) -> Dictionary:
	var t := {}
	var fid := str(why.get("for", ""))
	var f: Person = w.cast.person(fid) if fid != "" and w.cast else null
	if f:
		t["for"] = f.known_as
		t["for_upper"] = f.known_as.to_upper()
		var pr := f.pronouns
		var they := "he" if pr == "he/him" else ("she" if pr == "she/her" else "they")
		t["they"] = they
		t["them"] = "him" if pr == "he/him" else ("her" if pr == "she/her" else "them")
		t["their"] = "his" if pr == "he/him" else ("her" if pr == "she/her" else "their")
		t["they_cap"] = they.capitalize()
		var rel := str(why.get("why", ""))
		if rel == "zamboni":
			rel = "sibling"
		var words: Array = KIN_WORD.get(rel, [])
		if not words.is_empty():
			var i := 0 if pr == "he/him" else (1 if pr == "she/her" else 2)
			var word := str(words[i])
			t["kin"] = word
			t["kin_cap"] = word.left(1).to_upper() + word.substr(1)
			t["kin_bare"] = word.trim_prefix("my ")
			t["kin_upper"] = word.to_upper()
	elif str(why.get("for_name", "")) != "":
		t["for"] = str(why.for_name)
	if why.has("until"):
		t["until"] = _clock(float(why.until))
	if str(why.get("doing", "")) != "":
		t["doing"] = str(why.doing)
	if why.has("start"):
		t["start"] = _clock(float(why.start))
	return t


static func fill_reason(s: String, w: StoryWorld, p: Person, why: Dictionary) -> String:
	if not "{" in s:
		return s
	var t := reason_tokens(w, p, why)
	for k in t:
		s = s.replace("{%s}" % k, str(t[k]))
	return s


## "7", "7:30", "noon": how people say a time.
static func _clock(h: float) -> String:
	var hh := int(floor(h)) % 24
	var mm := int(round((h - floor(h)) * 60.0))
	if mm >= 60:
		mm = 0
		hh = (hh + 1) % 24
	if hh == 12 and mm == 0:
		return "noon"
	var h12 := hh % 12
	if h12 == 0:
		h12 = 12
	return str(h12) if mm == 0 else "%d:%02d" % [h12, mm]


## A line for why they came, from the shared lines (or "" for none).
func why_line() -> String:
	var why := str(reason.get("why", ""))
	if why == "":
		return ""
	var s := pick_filled(_load(LIFE).get("why", {}).get(why, []), world, speaker, reason)
	if s == "":
		return ""
	s = _cap(world.fill(fill_reason(s, world, speaker, reason), speaker))
	if reason.has("negotiated"):
		s += " " + str(reason.negotiated)
	return s


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
		_add_life_options()
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
	if ref.begins_with("_"):
		return _builtin_node(ref)
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


## On a hub: a named person can be asked why they're here today; a
## townsperson's archetype tree also gets work and family questions.
func _add_life_options() -> void:
	var tid := str(tree.get("id", ""))
	if tid == "generic":
		return
	var adds: Array = []
	if tid.begins_with("archetype_"):
		adds.append({"text": "What do you do for work?", "to": "_work"})
		if not speaker.family.is_empty() or str(reason.get("for", "")) != "":
			adds.append({"text": "Who are you here with?", "to": "_with"})
	elif why_line() != "":
		adds.append({"text": "What brings you in today?", "to": "_why"})
	var n := choices.size()
	if n > 0 and choices.back().get("do", []).is_empty() and str(choices.back().get("to", "")) in ["end", "bye"]:
		n -= 1
	for o in adds:
		if not choices.any(func(c): return str(c.get("to", "")) == str(o.to)):
			choices.insert(n, o)
			n += 1


func _builtin_node(ref: String) -> Dictionary:
	match ref:
		"_why": return {"say": "@why_here", "options": [{"text": "Good to see you.", "to": "hub"}]}
		"_work": return {"say": "@work", "options": [{"text": "Sounds busy.", "to": "hub"}]}
		"_with": return {"say": "@with", "options": [{"text": "Nice.", "to": "hub"}]}
	return {}


## Placeholder lines the generic tree fills from the person.
func _special(s: String) -> String:
	match s:
		"@work":
			return _work_line()
		"@with":
			return _with_line()
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
			var wl := why_line()
			if wl != "":
				return wl
			var play := speaker.favourites("play", 1)
			var watch := speaker.favourites("watch", 2)
			if not play.is_empty():
				return "Me? I'm here for %s. Wouldn't miss it." % _label(play[0])
			if not watch.is_empty():
				return "I come for %s, mostly. %s" % [_label(watch[0]), "And %s, if it's on." % _label(watch[1]) if watch.size() > 1 else ""]
			return "Somebody has to keep the bench warm."
		"@about":
			if speaker.bio != "":
				return speaker.bio
			if speaker.backstory != "":
				return first_person(speaker.backstory, speaker.known_as)
			return "%s, from %s. %s" % [speaker.name, speaker.town.capitalize(), str(world.cast.archetype(speaker.archetype).get("label", ""))]
	return s


## A backstory told in their own voice: "Lisa keeps..." becomes "I keep...".
static func first_person(s: String, me: String) -> String:
	var out := " " + s + " "
	for pair in [[" " + me + " is ", " I'm "], [" " + me + " has ", " I have "], [" " + me + " was ", " I was "],
			[" " + me + "'s ", " my "], [" " + me + " and ", " I and "]]:
		out = out.replace(pair[0], pair[1])
	for verb in FIRST_PERSON:
		out = out.replace(" " + me + " " + verb + " ", " I " + str(FIRST_PERSON[verb]) + " ")
	out = out.replace(" I and ", " me and ")
	for tail in [".", ",", "'s", " "]:
		out = out.replace(" " + me + tail, (" me" if tail != "'s" else " my") + (tail if tail != "'s" else ""))
	out = out.strip_edges()
	return out.left(1).to_upper() + out.substr(1)


## Third person to first, for the verbs the backstory lines use.
const FIRST_PERSON := {"keeps": "keep", "owns": "own", "drives": "drive", "plays": "play", "brings": "bring", "works": "work",
	"knows": "know", "comes": "come", "sits": "sit", "remembers": "remember", "likes": "like", "lives": "live",
	"says": "say", "reads": "read", "thinks": "think", "claims": "claim", "wants": "want", "asks": "ask", "holds": "hold",
	"shows": "show", "drinks": "drink", "coaches": "coach", "runs": "run", "sells": "sell", "carries": "carry",
	"gives": "give", "wears": "wear", "scouts": "scout", "sleeps": "sleep", "puts": "put", "sponsors": "sponsor",
	"practises": "practise", "pretends": "pretend", "refs": "ref", "loves": "love", "hasn't": "haven't",
	"doesn't": "don't", "always": "always", "still": "still", "never": "never", "once": "once", "can": "can",
	"learned": "learned", "decided": "decided", "grew": "grew", "moved": "moved", "retired": "retired", "met": "met",
	"signed": "signed", "joined": "joined", "found": "found", "played": "played", "brings,": "bring,",
	"explains": "explain", "treats": "treat", "waits": "wait", "buys": "buy", "talks": "talk", "plans": "plan",
	"tells": "tell", "closes": "close", "checks": "check", "drives,": "drive,", "makes": "make", "sews": "sew"}


func _work_line() -> String:
	var w := speaker.work
	if w.is_empty():
		match speaker.job:
			"Retired":
				return "Retired. Busier than I ever was working."
			"In school":
				return ("School. Grade %d. Don't remind me." % clampi(speaker.age - 5, 1, 12)) if speaker.age >= 6 else "I'm %d!" % speaker.age
			"":
				return "Bit of this, bit of that."
		return speaker.job + "."
	var days: Array = w.get("days", [])
	var when := "weekdays" if days == [1, 2, 3, 4, 5] else ("most days" if days.size() >= 5 else "%d days a week" % days.size())
	var line := "%s at %s, %s, %s to %s." % [str(w.get("title", "")), str(w.get("employer", "")), when,
		_clock(float(w.get("from", 9.0))), _clock(float(w.get("to", 17.0)))]
	if str(w.get("employer", "")) == "":
		line = "%s, %s, %s to %s." % [str(w.get("title", "")), when, _clock(float(w.get("from", 9.0))), _clock(float(w.get("to", 17.0)))]
	if str(w.get("boss", "")) != "":
		line += " %s sets the hours, so the rink gets what's left." % (str(w.boss).left(1).to_upper() + str(w.boss).substr(1))
	if reason.has("negotiated"):
		line += " " + str(reason.negotiated)
	return line


func _with_line() -> String:
	var names: Array = []
	for fid in speaker.family:
		var f: Person = world.cast.person(fid)
		if f:
			var k := speaker.kin_of(fid)
			names.append("%s (%s)" % [f.known_as, {"partner": "my other half", "child": "mine", "parent": "the chauffeur",
				"sibling": "the sibling", "grandparent": "the grandparent", "grandchild": "the grandkid"}.get(k, "family")])
	var line := "Just me. I like it that way. Mostly." if names.is_empty() else "That's " + ", ".join(names.slice(0, 4)) + ". The family."
	var fid := str(reason.get("for", ""))
	if fid != "" and world.cast.person(fid) and not fid in speaker.family:
		line += " Tonight I'm here for %s." % world.cast.person(fid).known_as
	return line


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
			{"text": "What do you do for work?", "to": "_work"},
			{"text": "Who are you here with?", "to": "_with"},
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
