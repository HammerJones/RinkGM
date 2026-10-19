extends "res://scripts/venue/venue_walk.gd"
## The venue walk started in the gym with a pickup run already on: for
## playtesting PickupRun (and its screenshots). Walk up to the court and
## press E to join; see PickupRun for the controls.
##
##   godot --path . res://scenes/world/pickup_gym.tscn -- --free-walk [--play] [--weekday=6]
##
## `--play` joins straight away and puts you at the top of the key with the
## ball once your game is on. `--shot=<png>` saves a screenshot after
## `--shot-after=` seconds (default 12) and quits; `--venue-cam=` views it
## from a fixed camera instead of your eyes. `--clock=<min/s>` sets how fast
## the gym clock runs (default WalkStory's pace).

var _shot := ""
var _shot_t := 12.0
var _play := false
var _placed := false


func _ready() -> void:
	super._ready()
	var wd := 2
	var rate := WalkStory.TIME_SCALE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot = a.trim_prefix("--shot=")
		elif a.begins_with("--shot-after="):
			_shot_t = a.trim_prefix("--shot-after=").to_float()
		elif a == "--play":
			_play = true
		elif a.begins_with("--weekday="):
			wd = a.trim_prefix("--weekday=").to_int()
		elif a.begins_with("--clock="):
			rate = a.trim_prefix("--clock=").to_float()
	if pickup_run == null:
		push_warning("gym walk: this venue has no gym")
		return
	# the gym keeps its own clock here, so the run is on whatever the walk's hour
	pickup_run.sim = null
	pickup_run.clock_weekday = wd
	pickup_run.clock_day = 1
	pickup_run.clock_minute = 16.0 * 60.0
	pickup_run.clock_rate = rate
	pickup_run.start_now()
	# in the gym, by the east doors, looking at the court
	walker.global_position = venue.global_transform * Vector3(-6.5, 0.05, -45.2)
	_yaw = -0.3
	_pitch = -0.1
	if _play:
		walker.global_position = venue.global_transform * Vector3(-9.6, 0.05, -51.4)
		_yaw = -PI * 0.5
		pickup_run.join()
	print("gym walk: %s, %d people here" % [pickup_run.score_text(), pickup_run.hoopers.size()])


func _process(dt: float) -> void:
	super._process(dt)
	if pickup_run and _play and not _placed and pickup_run.is_playing() and pickup_run.stage == "live":
		_placed = true
		walker.global_position = venue.global_transform * Vector3(-9.6, 0.05, -51.4)
		_yaw = -PI * 0.5
		_pitch = -0.12
		pickup_run.hand_ball_to_player()
	if _shot != "":
		_shot_t -= dt
		if _shot_t <= 0.0:
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot)
			print("gym walk: saved %s (%s)" % [_shot, pickup_run.score_text() if pickup_run else ""])
			get_tree().quit()
