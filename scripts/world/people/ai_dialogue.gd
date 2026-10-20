class_name AiDialogue
extends Node
## Optional: one extra in-character line from a free model running on the
## player's own machine (an Ollama-compatible /api/generate endpoint), on
## top of the offline dialogue, never instead of it. Off by default
## (WorldSettings "ai_dialogue"); no keys, no accounts. The request is async
## with a timeout, and any failure (nothing listening, a slow model, a reply
## that isn't one clean line) is silent: the offline line simply stands.
##
##   var ai := AiDialogue.new(); add_child(ai)
##   ai.ask(conversation, func(line): conversation.ai_line = line)

## Tests and headless tools set this, so nothing ever goes on the network.
static var blocked := false

var _req: HTTPRequest
var _done: Callable
var _busy := false


static func enabled() -> bool:
	return not blocked and WorldSettings.get_bool("ai_dialogue") and WorldSettings.get_string("ai_endpoint").begins_with("http")


## The prompt for `c`'s speaker: who they are, how they talk, how they feel
## about the rink, what they remember, why they're here and what's on.
static func prompt(c: Conversation) -> String:
	var p := c.speaker
	var w := c.world
	var traits: Array = []
	for t in Person.TRAITS:
		var v := p.trait_value(t)
		if v >= 0.7:
			traits.append("very " + {"warmth": "warm", "chatter": "chatty", "patience": "patient", "pride": "proud", "nerve": "steady", "humour": "funny"}[t])
		elif v <= 0.3:
			traits.append({"warmth": "cool", "chatter": "quiet", "patience": "impatient", "pride": "easygoing", "nerve": "jumpy", "humour": "serious"}[t])
	var mood := "fond of the rink" if p.mood >= 0.7 else ("lukewarm about the rink" if p.mood >= 0.45 else "fed up with the rink")
	var mem: Array = p.memory.slice(-3).map(func(m): return str(m.get("what", "")))
	var lines := [
		"You are %s (%s, age %d) from %s, at the %s, a worn 1970s community hockey rink in a small northern town." % [p.name, p.pronouns, p.age, p.town.capitalize().replace("_", " "), w.rink_name],
		"About you: %s" % (p.backstory if p.backstory != "" else p.bio),
		"Work: %s." % (p.job if p.job != "" else "none to speak of"),
		"Personality: %s." % (", ".join(traits) if not traits.is_empty() else "ordinary"),
	]
	if p.voice != "":
		lines.append("How you talk: %s" % p.voice)
	lines.append("You are %s.%s" % [mood, (" Lately: " + "; ".join(mem) + ".") if not mem.is_empty() else ""])
	var why := c.why_line()
	if why != "":
		lines.append("Why you're here today: %s" % why)
	lines.append("On the ice right now: %s. The ice is %s." % [w.fill("{event}"), w.ice_word()])
	lines.append("You're talking to %s, the rink's new owner. You just said: \"%s\"" % [w.owner_name, c.line])
	lines.append("Add ONE more short line (under 25 words) in your own voice, warm and a little wry, about the rink, the town or your day. No quotes, no stage directions, no names of real people or brands.")
	return "\n".join(lines)


## Asks for a line for `c`; `done(line)` is called only with a usable line.
## Returns false (and does nothing) when it's off or already asking.
func ask(c: Conversation, done: Callable) -> bool:
	if not enabled() or _busy or not is_inside_tree():
		return false
	if _req == null:
		_req = HTTPRequest.new()
		_req.name = "AiRequest"
		add_child(_req)
		_req.request_completed.connect(_on_done)
	_req.timeout = float(WorldSettings.get_value("ai_timeout"))
	_done = done
	var body := JSON.stringify({"model": WorldSettings.get_string("ai_model"), "prompt": prompt(c), "stream": false,
		"options": {"num_predict": 60, "temperature": 0.8}})
	var err := _req.request(WorldSettings.get_string("ai_endpoint"), PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body)
	_busy = err == OK
	return _busy


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var v = JSON.parse_string(body.get_string_from_utf8())
	if not v is Dictionary:
		return
	var line := clean(str(v.get("response", "")))
	if line != "" and _done.is_valid():
		_done.call(line)


## One clean line or "": the first line, unquoted, not too long.
static func clean(s: String) -> String:
	s = s.strip_edges()
	if s.contains("\n"):
		s = s.get_slice("\n", 0).strip_edges()
	s = s.trim_prefix("\"").trim_suffix("\"").strip_edges()
	if s.length() < 3 or s.length() > 240 or s.begins_with("*") or s.begins_with("("):
		return ""
	return s
