class_name Venue
extends Node3D
## The building around the ice: stands, benches, penalty boxes, lobby,
## manager's office, locker rooms, Zamboni bay, lighting, scoreboard and crowd.
##
## Built at human scale (metres; doors 2.2 m, steps 0.21 m) with walkable
## floors and colliders on physics layer 2, so an on-foot player can explore
## it later without rebuilding. The hockey sim never touches those colliders.
##
## Every room is a VenueRoom with its own renovation age (worn, repaired,
## renovated). The match scene instances venue.tscn around the Rink:
##
##     venue = Venue.instantiate_for(fixture)
##     add_child(venue)
##     venue.bind_game(self)
##
## Rooms and all geometry share one space: the rink centre is the origin, the
## rink runs along X, and the player benches are on the -Z side.

const SCENE := "res://scenes/venue/venue.tscn"

# building envelope
const HALF_X := 46.0
const HALF_Z := 30.0
const WALL_T := 0.5
const ROOF_Y := 16.0
# zones around the ice (all |z| or |x|)
const BOARD_OUT := 13.3    # outside face of the side boards
const BENCH_BACK := 15.2   # back wall of the benches / penalty boxes
const STAND_FRONT := 17.5  # front of the side stands
const STAND_X := 24.0      # side stands run x -24..24
const STAND_ROWS := 10
const ROW_RUN := 0.85
const ROW_RISE := 0.42
const STAND_Y0 := 0.9      # height of the first row's tread
const END_FRONT := 34.0    # front wall of the end rooms (lobby, lockers, bay)
const LOBBY_H := 4.2       # lobby ceiling = mezzanine floor
const ROOM_Z := 14.0       # end rooms span z -14..14

## Share of seats filled per league tier (beer league is friends and partners).
const ATTENDANCE := [0.03, 0.05, 0.09, 0.22, 0.45, 0.72]

## Club colours of the home team, and the building's name.
var primary := Color("c8191e")
var secondary := Color("ece7dc")
var rink_name := "COMMUNITY RINK"
var home_short := "HOME"
var away_short := "AWAY"
var tier := 0
var attendance := 0.05
var rooms := {}  # room_id -> VenueRoom
var crowd: VenueCrowd
var game: Node

var _built := false
var _above_roof := false
var _tick := 0.0
var _fixture := {}


static func instantiate_for(fixture: Dictionary) -> Venue:
	var v: Venue = (load(SCENE) as PackedScene).instantiate()
	v.configure(fixture)
	return v


## Sets colours, name, tier and crowd from a match fixture (Career format).
## Rink age defaults by tier: beer league rinks are worn, senior and up are
## repaired, minor pro is renovated; each club's rink varies a little.
func configure(fixture: Dictionary) -> void:
	_fixture = fixture
	var home = fixture.get("home")
	var away = fixture.get("away")
	if home:
		primary = Color(home.primary)
		secondary = Color(home.secondary)
		tier = int(home.tier)
		home_short = _short(home)
		rink_name = "%s COMMUNITY RINK" % String(home.name).to_upper() if tier < 3 else "%s ARENA" % String(home.name).to_upper()
	if away:
		away_short = _short(away)
	attendance = ATTENDANCE[clampi(tier, 0, ATTENDANCE.size() - 1)]
	if fixture.get("playoff", false):
		attendance = minf(1.0, attendance * 1.8 + 0.03)
	var base := VenueRoom.Age.WORN if tier < 3 else (VenueRoom.Age.REPAIRED if tier < 5 else VenueRoom.Age.RENOVATED)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(rink_name)
	for r in _room_nodes():
		var a := base
		if rng.randf() < 0.25:
			a = clampi(base + (1 if rng.randf() < 0.6 else -1), VenueRoom.Age.WORN, VenueRoom.Age.RENOVATED)
		r.age = a
	if _built:
		_rebuild_all()


func _short(team) -> String:
	var s := String(team.get("short")) if team.get("short") else ""
	if s == "":
		s = String(team.name).substr(0, 4)
	return s.to_upper().substr(0, 4)


func _ready() -> void:
	for r in _room_nodes():
		rooms[r.room_id] = r
	crowd = get_node_or_null("Crowd")
	_apply_args()
	var t0 := Time.get_ticks_usec()
	_rebuild_all()
	_built = true
	if "--venue-stats" in OS.get_cmdline_user_args():
		print("venue: built in %.0f ms, %s" % [(Time.get_ticks_usec() - t0) / 1000.0, stats()])


## Geometry budget: {meshes, triangles, colliders, lights, signs, fans}.
func stats() -> Dictionary:
	var d := {"meshes": 0, "triangles": 0, "colliders": 0, "lights": 0, "signs": 0, "fans": crowd.count() if crowd else 0}
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is VenueSign:
			d.signs += 1
		elif n is MeshInstance3D and n.mesh:
			d.meshes += 1
			for si in n.mesh.get_surface_count():
				d.triangles += n.mesh.surface_get_array_len(si) / 3
		elif n is CollisionShape3D:
			d.colliders += 1
		elif n is Light3D:
			d.lights += 1
	return d


func _room_nodes() -> Array:
	return get_children().filter(func(c): return c is VenueRoom)


## Command-line overrides for playtests and screenshots:
## `--venue-age=worn|repaired|renovated`, `--venue-crowd=0..1`.
func _apply_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--venue-age="):
			var i := VenueRoom.AGE_NAMES.find(a.trim_prefix("--venue-age="))
			if i >= 0:
				for r in _room_nodes():
					r.age = i
		elif a.begins_with("--venue-crowd="):
			attendance = clampf(a.trim_prefix("--venue-crowd=").to_float(), 0.0, 1.0)
		elif a.begins_with("--venue-cam="):
			# `--venue-cam=x,y,z,lookx,looky,lookz` views the building from a fixed camera
			var v := a.trim_prefix("--venue-cam=").split_floats(",")
			_debug_cam.call_deferred(Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]))


func _debug_cam(from: Vector3, at: Vector3) -> void:
	await get_tree().process_frame
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 400.0
	add_child(cam)
	cam.look_at_from_position(from, at, Vector3.UP)
	cam.current = true


func _rebuild_all() -> void:
	for r in _room_nodes():
		r.venue = self
		r.rebuild()
		if r.overhead:
			r.set_overhead_hidden(_above_roof)
	_refill_crowd()


func _refill_crowd() -> void:
	if crowd == null:
		return
	var seats: Array = []
	for r in _room_nodes():
		if r.has_method("seats"):
			seats.append_array(r.seats())
	crowd.fill(seats, attendance, primary, secondary, hash(rink_name))


# ---------------------------------------------------------------- renovation API

func set_room_age(id: String, age: int) -> void:
	var r: VenueRoom = rooms.get(id)
	if r == null:
		push_warning("Venue: no room '%s'" % id)
		return
	r.set_age(age)
	if r.overhead:
		r.set_overhead_hidden(_above_roof)
	if r.has_method("seats"):
		_refill_crowd()


func set_all_ages(age: int) -> void:
	for r in _room_nodes():
		r.age = age
	_rebuild_all()


func set_attendance(f: float) -> void:
	attendance = clampf(f, 0.0, 1.0)
	_refill_crowd()


## {room_id: age} for saves (the career stores this for the user's home rink).
func get_state() -> Dictionary:
	var d := {}
	for id in rooms:
		d[id] = rooms[id].age
	return d


func apply_state(d: Dictionary) -> void:
	for id in d:
		if rooms.has(id):
			rooms[id].age = int(d[id])
	if _built:
		_rebuild_all()


## The room whose floor area contains `p` (venue space), or null.
## The smallest room wins, so the locker room beats the building shell.
func room_at(p: Vector3) -> VenueRoom:
	var best: VenueRoom = null
	for r in _room_nodes():
		if r.bounds.size != Vector3.ZERO and r.bounds.grow(0.01).has_point(p):
			if best == null or r.bounds.get_volume() < best.bounds.get_volume():
				best = r
	return best


func all_doors() -> Array[VenueDoor]:
	var out: Array[VenueDoor] = []
	for r in _room_nodes():
		out.append_array(r.doors)
	return out


# ---------------------------------------------------------------- match hook

## Hooks the venue to a running match: the scoreboard and the timekeeper's
## clock read the score, the crowd cheers goals, and the venue's lighting
## sets the sun and ambient light of the match environment.
func bind_game(g: Node) -> void:
	game = g
	var f: Dictionary = g.get("fixture") if g.get("fixture") else {}
	if not f.is_empty() and _fixture.is_empty():
		configure(f)
	var puck = g.get("puck")
	if puck and puck.has_signal("goal_scored"):
		puck.goal_scored.connect(_on_goal)
	for c in g.get_children():
		if c is WorldEnvironment:
			apply_lighting(c.environment, null)
		elif c is DirectionalLight3D:
			apply_lighting(null, c)


func apply_lighting(env: Environment, sun: DirectionalLight3D) -> void:
	var lights = rooms.get("lighting")
	if lights and lights.has_method("apply"):
		lights.apply(env, sun)


func _on_goal(net_side: int) -> void:
	if game == null or crowd == null:
		return
	# team 0 (the user's club) attacks +x; the home crowd cheers home goals
	var scorer := 0 if net_side == (game.attack_side(0) if game.has_method("attack_side") else 1) else 1
	var user_home: bool = _fixture.get("user_home", true)
	var home_scored := (scorer == 0) == user_home
	crowd.cheer(1.0 if home_scored else 0.25)


## Score shown on the boards: [home, away] whatever side the user is on.
func scoreboard_state() -> Dictionary:
	if game == null:
		return {"home": 0, "away": 0, "period": "1ST", "clock": "20:00"}
	var sc: Array = game.get("score")
	var user_home: bool = _fixture.get("user_home", true)
	var period := int(game.get("period"))
	var label: String = "OT" if game.get("overtime") else (["1ST", "2ND", "3RD"][clampi(period - 1, 0, 2)])
	if game.get("shootout"):
		label = "SO"
	var t := maxf(0.0, float(game.get("clock")))
	return {
		"home": sc[0] if user_home else sc[1], "away": sc[1] if user_home else sc[0],
		"period": label, "clock": "%02d:%02d" % [int(t) / 60, int(t) % 60],
	}


func _process(dt: float) -> void:
	_tick -= dt
	if _tick > 0.0:
		return
	_tick = 0.2
	var cam := get_viewport().get_camera_3d()
	if cam:
		# from above the roof (isometric view) hide what hangs from it
		var above := cam.global_position.y > ROOF_Y - 0.5 or cam.projection == Camera3D.PROJECTION_ORTHOGONAL
		if above != _above_roof:
			_above_roof = above
			for r in _room_nodes():
				if r.overhead:
					r.set_overhead_hidden(above)
	var st := scoreboard_state()
	for r in _room_nodes():
		if r.has_method("show_score"):
			r.show_score(st, home_short, away_short)
