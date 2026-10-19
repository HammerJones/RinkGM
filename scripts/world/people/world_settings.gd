class_name WorldSettings
extends RefCounted
## The player's settings for the world's people, kept on this machine (not in
## a save): a small ConfigFile, read on first use. No autoload.
##
##   ai_dialogue   false   ask a local model for an extra in-character line
##   ai_endpoint   "http://localhost:11434/api/generate"  (Ollama-compatible)
##   ai_model      "llama3.2"
##   ai_timeout    4.0     seconds before the offline line stands alone
##   tutorial      ""      "" (ask), "on", "off": Gus's first-day walkthrough,
##                         for walks outside a career (a career saves its own)
##
##   if WorldSettings.get_bool("ai_dialogue"): ...
##   WorldSettings.set_value("ai_dialogue", true)   # saves

const DEFAULTS := {"ai_dialogue": false, "ai_endpoint": "http://localhost:11434/api/generate",
	"ai_model": "llama3.2", "ai_timeout": 4.0, "tutorial": ""}
const SECTION := "people"

## Where the file lives; tests point it somewhere of their own.
static var path := "user://world_settings.cfg"
static var _cfg: ConfigFile


static func _load() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		if FileAccess.file_exists(path):
			_cfg.load(path)
	return _cfg


static func get_value(key: String) -> Variant:
	return _load().get_value(SECTION, key, DEFAULTS.get(key))


static func get_bool(key: String) -> bool:
	return bool(get_value(key))


static func get_string(key: String) -> String:
	return str(get_value(key))


static func set_value(key: String, v: Variant) -> void:
	_load().set_value(SECTION, key, v)
	_cfg.save(path)


## Forget what was read, so the next read comes from `path` again.
static func reload() -> void:
	_cfg = null
