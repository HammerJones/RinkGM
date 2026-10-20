class_name SkateRental
extends Node3D
## The skate rental window at the ticket booth in the lobby (Venue.places()
## "skate_rental"). A finite stock of rental skates by size, kids Y8 to adult
## 13, in cubbies on the booth walls. Customers line up; a clerk asks the
## size, physically walks to the cubby, grabs a pair, walks back and hands it
## over while the line keeps building. Several clerks share the booth
## without walking through each other. The wrong size, or none left, makes a
## customer unhappy and can bring a refund demand. Returned skates pile up on
## the counter until somebody puts them away; the return rack upgrade lets
## customers drop them on a sorted rack the clerks rent straight from.
##
##   var r := SkateRental.new()
##   venue.add_child(r)
##   r.setup({"staff": 2})                 # or {"staff_looks": [gus_look]}
##   r.enqueue(look, age)                   # a customer joins the line
##   r.served.connect(...)                  # (customer, info) when they walk off with skates
##
## The player serves too: player_begin() -> what the customer says,
## player_grab(size), player_hand(); player_put_away() clears the pile.
## All positions are venue space (the lobby at the -X end).

signal served(customer: IceSkater, info: Dictionary)
signal refund_demanded(info: Dictionary)
signal said(who: IceSkater, text: String)
signal pile_changed(count: int)

const SIZES := ["Y8", "Y9", "Y10", "Y11", "Y12", "Y13", "A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8", "A9", "A10", "A11", "A12", "A13"]
## The layout hangs off the customer's spot at the window (Venue.places()
## "skate_rental"), `into` (from the customer into the booth) and `along`
## (the way the line runs). Depth d and along a are metres in that frame;
## data/world/on_ice.json "rental" sizes the booth.
var anchor := Vector2(-34.3, -14.7)
var into := Vector2(-1, 0)
var along := Vector2(0, 1)
var counter_d := 0.9
var booth_depth := 4.3
var a_min := -1.9
var a_max := 0.7
var BOOTH := Rect2()
var WINDOWS: Array = []
var PILE := Vector2.ZERO
var RETURN_SPOT := Vector2.ZERO
var RACK := Vector2.ZERO
var RACK_FETCH := Vector2.ZERO
var RACK_DROP := Vector2.ZERO
var LINE_START := Vector2.ZERO
var LINE_STEP := Vector2.ZERO
var ENTRANCE := Vector2(-44.0, 0.4)
var RINK_DOOR := Vector2(-34.6, -8.5)

var inventory := {}      # size -> Array of pairs {size, sharp, clean}
var pile: Array = []     # pairs on the counter waiting to be put away
var rack: Array = []     # pairs on the return rack (the upgrade)
var has_rack := false
var staff: Array = []    # IceSkater clerks
var customers: Array = []
var line: Array = []     # IceSkater waiting, front first
var auto_run := true
var t := 0.0
var rng := RandomNumberGenerator.new()
var price := 3.0
var cfg := {}
var served_count := 0
var refunds := 0
var unhappy := 0

var _next_id := 50000
var _draw: OnIceDraw
var _player := {}        # {"customer": id, "pair": {}} while the owner serves
var _pairs_mm := {}      # mesh id -> MultiMeshInstance3D
var _shelf_built := false


func _init() -> void:
	cfg = OnIceData.section("rental")
	price = float(cfg.get("rental_price", 3.0))
	_draw = OnIceDraw.new(self, "Rental")


## Lays the counter out from the window spot. `places`: Venue.places().
func set_frame(at: Vector2, into_ := Vector2(-1, 0), along_ := Vector2(0, 1), places := {}) -> void:
	anchor = at
	into = into_.normalized()
	along = along_.normalized()
	counter_d = float(cfg.get("counter_depth", 0.9))
	booth_depth = float(cfg.get("booth_depth", 4.3))
	a_min = float(cfg.get("along_min", -1.9))
	a_max = float(cfg.get("along_max", 0.7))
	var c0 := L(counter_d + 0.15, a_min + 0.1)
	var c1 := L(booth_depth - 0.1, a_max - 0.1)
	BOOTH = Rect2(Vector2(minf(c0.x, c1.x), minf(c0.y, c1.y)), (c1 - c0).abs())
	WINDOWS = [L(0.0, 0.0), L(0.0, -0.85)]
	PILE = L(counter_d, -1.45)
	RETURN_SPOT = L(-0.05, -1.6)
	RACK = L(counter_d, -1.5)
	RACK_FETCH = L(counter_d + 0.45, -1.45)
	RACK_DROP = RETURN_SPOT
	LINE_START = L(-0.4, 1.0)
	LINE_STEP = along * 0.8
	var ent: Array = places.get("entrance", [])
	if ent.size() > 1:
		ENTRANCE = Vector2(ent[1].x, ent[1].z)
	RINK_DOOR = OnIceData.v2(cfg.get("exit"), RINK_DOOR)
	_shelf_built = false


## A point in the counter's frame: d metres into the booth, a along the counter.
func L(d: float, a: float) -> Vector2:
	return anchor + into * d + along * a


func _serve(win: int, rank := 0) -> Vector2:
	return WINDOWS[win] + into * (counter_d + 0.4 + 0.65 * rank)


func setup(opts := {}) -> void:
	if WINDOWS.is_empty():
		var pl: Dictionary = opts.get("places", {})
		var sr: Array = pl.get("skate_rental", [])
		var at := OnIceData.v2(cfg.get("window"), anchor)
		if opts.get("window") is Vector2:
			at = opts.window  # an explicit window spot (a walk-through before the booth lands)
		elif not sr.is_empty():
			at = Vector2(sr[0].x, sr[0].z)
		set_frame(at, OnIceData.v2(cfg.get("into"), Vector2(-1, 0)), OnIceData.v2(cfg.get("along"), Vector2(0, 1)), pl)
	rng.seed = int(opts.get("seed", 7))
	var inv: Dictionary = opts.get("inventory", cfg.get("inventory", {}))
	inventory.clear()
	for sz in SIZES:
		inventory[sz] = []
		for i in int(inv.get(sz, 0)):
			inventory[sz].append({"size": sz, "sharp": rng.randf_range(0.55, 0.95), "clean": rng.randf_range(0.5, 0.9)})
	has_rack = bool(opts.get("return_rack", false))
	var looks: Array = opts.get("staff_looks", [])
	var n := maxi(int(opts.get("staff", looks.size() if not looks.is_empty() else 1)), looks.size())
	for i in n:
		add_clerk(looks[i] if i < looks.size() else {})


## Another clerk behind the counter ({} = a generated teenager in a polo).
func add_clerk(look := {}) -> IceSkater:
	var l: Dictionary = look if not look.is_empty() else _clerk_look()
	var i := staff.size()
	var e := _agent("employee", int(l.get("age", 24)), l)
	e.pos = _serve(i % WINDOWS.size(), i / WINDOWS.size())
	e.box = BOOTH
	e.task = {"state": "idle", "window": i % WINDOWS.size(), "rank": i / WINDOWS.size()}
	e.face = -into
	staff.append(e)
	return e


func buy_return_rack() -> void:
	has_rack = true
	_shelf_built = false


func _clerk_look() -> Dictionary:
	var l := PeopleArt.random_look(rng, rng.randi_range(17, 24), "staff")
	l.outfit = "staff_polo"
	l.accessory = "none"
	l["skates"] = false
	l["age"] = rng.randi_range(17, 24)
	l["name"] = Names.first(rng)
	return l


func _agent(role: String, age: int, look: Dictionary) -> IceSkater:
	var s := IceSkater.make(_next_id, role, age, look, 0.6)
	_next_id += 1
	s.on_ice = false
	s.shoes = true
	s.look["skates"] = false
	s.max_speed = float(cfg.get("walk_speed", 1.25)) * (0.85 if age > 65 or age < 8 else 1.0)
	s.accel = 2.5
	s.brake = 4.0
	s.name = str(look.get("name", "Customer"))
	_draw.mark_dirty()
	return s


# ------------------------------------------------------------- customers

## Someone wants rental skates. `size` empty: from their age and build.
func enqueue(look: Dictionary, age: int, size := "", from := ENTRANCE) -> IceSkater:
	var c := _agent("customer", age, look)
	c.pos = from
	c.task = {"state": "line", "size": size if size != "" else size_for(age, look, rng), "joined": t}
	c.happy = 0.75
	customers.append(c)
	line.append(c)
	return c


## Someone brings their rentals back (they walk from the rink doors).
func return_pair(pair: Dictionary, look: Dictionary, age: int) -> IceSkater:
	var c := _agent("customer", age, look)
	c.pos = RINK_DOOR
	c.task = {"state": "returning", "pair": pair}
	customers.append(c)
	return c


static func size_for(age: int, look: Dictionary, r: RandomNumberGenerator) -> String:
	if age <= 10:
		return "Y%d" % clampi(age + 3 + r.randi_range(-1, 1), 8, 13)
	if age <= 13:
		return "A%d" % clampi(age - 10 + r.randi_range(0, 2), 1, 5)
	var big := str(look.get("build", "average")) in ["stocky", "big"]
	var base := r.randi_range(5, 10) + (2 if big else 0)
	if age < 17:
		base -= 1
	return "A%d" % clampi(base, 1, 13)


func stock(size: String) -> int:
	var n: int = inventory.get(size, []).size()
	for p: Dictionary in rack:
		n += 1 if p.size == size else 0
	return n


func total_stock() -> int:
	var n := 0
	for sz in SIZES:
		n += stock(sz)
	return n


## Minutes a new arrival would wait at the back of the line (rough).
func line_minutes() -> float:
	var per := float(cfg.get("ask_seconds", 3.0)) + float(cfg.get("grab_seconds", 1.6)) + float(cfg.get("hand_seconds", 2.0)) + 6.0
	return line.size() * per / maxf(staff.size(), 1) / 60.0


# ------------------------------------------------------------------ step

func _physics_process(dt: float) -> void:
	if auto_run:
		step(dt)


func _process(_dt: float) -> void:
	var all := staff + customers
	_draw.draw(all)
	_draw_pairs()


func step(dt: float) -> void:
	t += dt
	_customers_step(dt)
	for e: IceSkater in staff:
		_clerk(e, dt)
	var all := staff + customers
	OnIceMotion.step(all, dt, rng)
	var gone: Array = []
	for c: IceSkater in customers:
		if c.hidden and str(c.task.get("state", "")) == "gone":
			gone.append(c)
	for c in gone:
		customers.erase(c)
		_draw.mark_dirty()


func _customers_step(_dt: float) -> void:
	# the line shuffles up
	for i in line.size():
		var c: IceSkater = line[i]
		c.go(LINE_START + LINE_STEP * i, c.max_speed, 0.25)
		c.face = -along
		if c.pos.distance_to(LINE_START + LINE_STEP * i) < 0.6 and float(c.task.get("wait_from", -1.0)) < 0.0:
			c.task["wait_from"] = t
	# waiting at the window, then off to lace up
	for c2: IceSkater in customers:
		match str(c2.task.get("state", "")):
			"window":
				c2.go(WINDOWS[int(c2.task.window)], c2.max_speed, 0.2)
				c2.face = into
			"leaving":
				c2.go(RINK_DOOR, c2.max_speed, 0.5)
				if c2.pos.distance_to(RINK_DOOR) < 0.7:
					c2.hidden = true
					c2.task.state = "gone"
			"walk_out":
				c2.go(ENTRANCE, c2.max_speed, 0.5)
				if c2.pos.distance_to(ENTRANCE) < 0.7:
					c2.hidden = true
					c2.task.state = "gone"
			"returning":
				var drop := RACK_DROP if has_rack else RETURN_SPOT
				c2.go(drop, c2.max_speed, 0.3)
				c2.carry = "skates"
				if c2.pos.distance_to(drop) < 0.45:
					var pr: Dictionary = c2.task.pair
					if has_rack:
						rack.append(pr)
					else:
						pile.append(pr)
						pile_changed.emit(pile.size())
					c2.carry = ""
					c2.task.state = "walk_out"
	# wait wears thin
	for c3: IceSkater in line:
		var w := t - float(c3.task.get("joined", t))
		if w > 360.0:
			c3.happy = maxf(c3.happy - 0.0004, 0.2)


func _free_window(e: IceSkater) -> int:
	return int(e.task.get("window", 0))


func _clerk(e: IceSkater, dt: float) -> void:
	var tk := e.task
	var win := _free_window(e)
	var serve := _serve(win)
	var rest := _serve(win, int(tk.get("rank", 0)))
	tk["t"] = float(tk.get("t", 0.0)) + dt
	match str(tk.state):
		"idle":
			e.go(rest, e.max_speed, 0.2)
			e.face = -into
			e.carry = ""
			var c := _front_for(win)
			if c and e.pos.distance_to(rest) < 0.5 and not _window_busy(win, e):
				line.erase(c)
				c.task.state = "window"
				c.task.window = win
				c.task.waited = t - float(c.task.get("joined", t))
				tk.state = "ask"
				tk.t = 0.0
				tk.customer = c.id
			elif (c == null or _window_busy(win, e)) and (not pile.is_empty() or (has_rack and not rack.is_empty() and rng.randf() < 0.01)):
				tk.state = "pickup"
				tk.t = 0.0
		"ask":
			e.go(serve, e.max_speed, 0.2)
			e.face = -into
			e.pose_lock = PeopleArt.Pose.TALK
			var c2 := _cust(int(tk.customer))
			if c2 == null:
				_reset(e)
				return
			if tk.t > float(cfg.get("ask_seconds", 3.0)) * 0.4 and not tk.get("asked", false):
				tk.asked = true
				said.emit(e, "What size?")
				said.emit(c2, _size_words(str(c2.task.size)))
			if c2.pos.distance_to(WINDOWS[win]) < 0.6 and tk.t > float(cfg.get("ask_seconds", 3.0)):
				e.pose_lock = -1
				var pick := _choose(str(c2.task.size))
				if pick.is_empty():
					tk.state = "sorry"
					tk.t = 0.0
				else:
					tk.state = "fetch"
					tk.size = pick.size
					tk.from = pick.from
					tk.t = 0.0
		"fetch":
			var to := shelf_spot(str(tk.size)) if tk.from == "shelf" else RACK_FETCH
			e.go(to, e.max_speed, 0.2)
			if e.pos.distance_to(to) < 0.35:
				tk.state = "grab"
				tk.t = 0.0
			elif tk.t > 25.0:
				tk.state = "grab"  # wedged behind a colleague: reach over
				tk.t = 0.0
		"grab":
			e.pose_lock = PeopleArt.Pose.WORK
			if tk.t > float(cfg.get("grab_seconds", 1.6)):
				e.pose_lock = -1
				var pr := _take(str(tk.size), str(tk.from))
				if pr.is_empty():
					var again := _choose(str(_cust(int(tk.customer)).task.size) if _cust(int(tk.customer)) else str(tk.size))
					if again.is_empty():
						tk.state = "sorry"
					else:
						tk.size = again.size
						tk.from = again.from
						tk.state = "fetch"
					tk.t = 0.0
					return
				tk.pair = pr
				e.carry = "skates"
				tk.state = "back"
				tk.t = 0.0
		"back":
			e.go(serve, e.max_speed, 0.2)
			if e.pos.distance_to(serve) < 0.35:
				tk.state = "hand"
				tk.t = 0.0
		"hand":
			e.face = -into
			if tk.t > float(cfg.get("hand_seconds", 2.0)):
				e.carry = ""
				var c3 := _cust(int(tk.customer))
				if c3:
					_hand_over(c3, tk.pair)
				_reset(e)
		"sorry":
			e.face = -into
			e.pose_lock = PeopleArt.Pose.TALK
			if tk.t > 2.0:
				e.pose_lock = -1
				var c4 := _cust(int(tk.customer))
				if c4:
					said.emit(e, "Sorry, we're out of %s." % _size_words(str(c4.task.size)).trim_suffix(", please."))
					_no_skates(c4)
				_reset(e)
		"pickup":
			if pile.is_empty() and not (has_rack and not rack.is_empty()):
				_reset(e)
				return
			if _front_for(win) != null and not _window_busy(win, e) and tk.t > 0.2 and not tk.has("held"):
				_reset(e)  # a customer came: serve them first
				return
			if not tk.has("held"):
				var src := PILE + into * 0.45 if not pile.is_empty() else RACK_FETCH
				e.go(src, e.max_speed, 0.2)
				if e.pos.distance_to(src) < 0.35:
					var pr2: Dictionary = pile.pop_back() if not pile.is_empty() else rack.pop_back()
					pile_changed.emit(pile.size())
					tk.held = pr2
					e.carry = "skates"
					tk.t = 0.0
			else:
				var to2 := shelf_spot(str(tk.held.size))
				e.go(to2, e.max_speed, 0.2)
				if e.pos.distance_to(to2) < 0.35 or tk.t > 25.0:
					e.pose_lock = PeopleArt.Pose.WORK
					if tk.t > float(cfg.get("put_away_seconds", 1.4)) + (0.0 if e.pos.distance_to(to2) < 0.35 else 99.0) or tk.t > 26.0:
						inventory[str(tk.held.size)].append(tk.held)
						tk.erase("held")
						e.carry = ""
						e.pose_lock = -1
						tk.t = 0.0
						if pile.is_empty():
							_reset(e)


func _reset(e: IceSkater) -> void:
	var w := int(e.task.get("window", 0))
	e.task = {"state": "idle", "window": w, "rank": int(e.task.get("rank", 0))}
	e.pose_lock = -1
	e.carry = ""


## Another clerk is already serving someone at this window.
func _window_busy(win: int, me: IceSkater) -> bool:
	for o: IceSkater in staff:
		if o != me and int(o.task.get("window", -1)) == win and str(o.task.state) in ["ask", "fetch", "grab", "back", "hand", "sorry"]:
			return true
	return false


## The front of the line, if this window can take them (one window each).
func _front_for(_win: int) -> IceSkater:
	if line.is_empty():
		return null
	var c: IceSkater = line[0]
	if c.pos.distance_to(LINE_START) > 1.2:
		return null
	if not _player.is_empty() and int(_player.get("customer", -1)) == c.id:
		return null
	return c


func _cust(cid: int) -> IceSkater:
	for c: IceSkater in customers:
		if c.id == cid:
			return c
	return null


## The best pair for a size: exact, then a half size either way, then a size
## either way, from the rack first (it's closer). {} when there's nothing close.
func _choose(size: String) -> Dictionary:
	var i := SIZES.find(size)
	for d in [0, 1, -1, 2, -2]:
		var k: int = i + d
		if k < 0 or k >= SIZES.size():
			continue
		var sz: String = SIZES[k]
		if absi(d) == 2 and sz.substr(0, 1) != size.substr(0, 1):
			continue
		for p: Dictionary in rack:
			if p.size == sz:
				return {"size": sz, "from": "rack"}
		if not inventory.get(sz, []).is_empty():
			return {"size": sz, "from": "shelf"}
	return {}


func _take(size: String, from: String) -> Dictionary:
	if from == "rack":
		for k in rack.size():
			if rack[k].size == size:
				var p: Dictionary = rack[k]
				rack.remove_at(k)
				return p
	var arr: Array = inventory.get(size, [])
	if arr.is_empty():
		return {}
	return arr.pop_back()


func _hand_over(c: IceSkater, pair: Dictionary) -> void:
	var want := str(c.task.size)
	var got := str(pair.size)
	var off := absi(SIZES.find(got) - SIZES.find(want))
	var q := (float(pair.sharp) + float(pair.clean)) * 0.5
	if off == 1:
		c.happy -= 0.15
	elif off >= 2:
		c.happy -= 0.35
	c.happy += (q - 0.6) * 0.3
	pair.sharp = maxf(float(pair.sharp) - float(cfg.get("sharpness_per_use", 0.04)), 0.0)
	pair.clean = maxf(float(pair.clean) - float(cfg.get("clean_per_use", 0.05)), 0.0)
	var waited := float(c.task.get("waited", 0.0))
	if waited > 300.0:
		c.happy -= clampf((waited - 300.0) / 1200.0, 0.0, 0.25)
	c.task.state = "leaving"
	c.task.pair = pair
	c.carry = "skates"
	served_count += 1
	var info := {"size_want": want, "size_got": got, "off": off, "quality": q, "waited": waited, "pair": pair, "happy": c.happy}
	if off >= 2 and rng.randf() < 0.35:
		_refund(c, "wrong_size")
	if c.happy < 0.45:
		unhappy += 1
	served.emit(c, info)


func _no_skates(c: IceSkater) -> void:
	c.happy -= 0.5
	unhappy += 1
	var pride := float(c.look.get("pride", 0.5))
	if rng.randf() < 0.55 + pride * 0.3:
		_refund(c, "no_size")
	c.task.state = "walk_out"
	served.emit(c, {"size_want": str(c.task.size), "size_got": "", "off": 99, "quality": 0.0, "waited": float(c.task.get("waited", 0.0)), "pair": {}, "happy": c.happy})


func _refund(c: IceSkater, why: String) -> void:
	refunds += 1
	refund_demanded.emit({"name": c.name, "size": str(c.task.get("size", "")), "reason": why, "amount": price + 4.0})


func _size_words(size: String) -> String:
	if size.begins_with("Y"):
		return "Kids' %s, please." % size.substr(1)
	return "Adult %s, please." % size.substr(1)


# ------------------------------------------------------------ the owner

## The owner steps up to the window: the front customer tells them their size.
func player_begin() -> Dictionary:
	if line.is_empty():
		return {}
	var c: IceSkater = line[0]
	line.erase(c)
	c.task.state = "window"
	c.task.window = WINDOWS.size() - 1
	c.task.waited = t - float(c.task.get("joined", t))
	_player = {"customer": c.id, "pair": {}}
	said.emit(c, _size_words(str(c.task.size)))
	return {"id": c.id, "name": c.name, "ask": "What size?", "say": _size_words(str(c.task.size)), "size": str(c.task.size)}


## The owner takes a pair of `size` off the cubby (or the rack).
func player_grab(size: String) -> bool:
	if _player.is_empty():
		return false
	var from := "rack" if rack.any(func(p: Dictionary) -> bool: return p.size == size) else "shelf"
	var pr := _take(size, from)
	if pr.is_empty():
		return false
	if not _player.pair.is_empty():
		inventory[str(_player.pair.size)].append(_player.pair)
	_player.pair = pr
	return true


## The owner hands over what they grabbed; nothing in hand = "we're out".
func player_hand() -> Dictionary:
	if _player.is_empty():
		return {}
	var c := _cust(int(_player.customer))
	var pr: Dictionary = _player.pair
	_player = {}
	if c == null:
		return {}
	var out := {"customer": c.name, "want": str(c.task.size)}
	if pr.is_empty():
		_no_skates(c)
		out["got"] = ""
	else:
		_hand_over(c, pr)
		out["got"] = str(pr.size)
	out["happy"] = c.happy
	return out


## The owner puts away up to `n` pairs from the counter pile.
func player_put_away(n := 2) -> int:
	var k := 0
	while k < n and not pile.is_empty():
		var p: Dictionary = pile.pop_back()
		inventory[str(p.size)].append(p)
		k += 1
	pile_changed.emit(pile.size())
	return k


## Where to stand to reach a size's cubby (venue space, inside the booth).
## Kids' sizes are on the side wall, adult sizes on the back wall.
func shelf_spot(size: String) -> Vector2:
	var i := maxi(SIZES.find(size), 0)
	if i < 6:
		return L(counter_d + 1.0 + i * 0.3, a_min + 0.55)
	return L(booth_depth - 0.6, _adult_a(i - 6))


func shelf_point(size: String) -> Vector3:
	var i := maxi(SIZES.find(size), 0)
	var p := L(counter_d + 1.0 + i * 0.3, a_min + 0.17) if i < 6 else L(booth_depth - 0.2, _adult_a(i - 6))
	return Vector3(p.x, 1.0, p.y)


func _adult_a(k: int) -> float:
	var span := a_max - a_min - 0.5
	return a_min + 0.25 + span * float(k) / 12.0


# ------------------------------------------------------------------ draw

func _draw_pairs() -> void:
	if not is_inside_tree():
		return
	if not _shelf_built:
		_build_shelves()
	var lists := {"skates": [], "skates_kid": []}
	for i in SIZES.size():
		var sz: String = SIZES[i]
		var n: int = mini(inventory.get(sz, []).size(), 4)
		var base := shelf_point(sz)
		for k in n:
			var y := 0.25 + float(k % 2) * 0.32 + float(k / 2) * 0.62
			var xf: Transform3D
			var toe := into if i < 6 else along
			xf = Transform3D(Basis(Vector3.UP, atan2(-toe.x, -toe.y)).scaled(Vector3.ONE * (0.85 if i < 6 else 0.95)), Vector3(base.x, y, base.z))
			lists["skates_kid" if i < 6 else "skates"].append(xf)
	for k in pile.size():
		var a := float(k) * 1.7
		var off := Vector3(fmod(float(k) * 0.37, 0.5) - 0.25, 1.12 + float(k / 6) * 0.17, fmod(float(k) * 0.23, 0.6) - 0.3)
		lists["skates_kid" if str(pile[k].size).begins_with("Y") else "skates"].append(Transform3D(Basis(Vector3.UP, a), Vector3(PILE.x, 0, PILE.y) + off))
	for k in rack.size():
		var row := k / 7
		lists["skates_kid" if str(rack[k].size).begins_with("Y") else "skates"].append(
			Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * 0.6), Vector3(RACK.x, 1.12 + 0.2 + (row % 3) * 0.15, RACK.y) + Vector3(along.x, 0, along.y) * (-0.3 + (k % 7) * 0.1)))
	for e: IceSkater in staff + customers:
		if e.carry == "skates" and not e.hidden:
			var f := e.forward()
			lists.skates.append(Transform3D(Basis(Vector3.UP, e.yaw), Vector3(e.pos.x + f.x * 0.3, 0.95, e.pos.y + f.y * 0.3)))
	for id in lists:
		var arr: Array = lists[id]
		var mmi: MultiMeshInstance3D = _pairs_mm.get(id)
		if mmi == null:
			mmi = MultiMeshInstance3D.new()
			mmi.name = "Pairs_" + id
			mmi.cast_shadow = Look.cast()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = OnIceArt.mesh(id)
			mmi.multimesh = mm
			add_child(mmi)
			_pairs_mm[id] = mmi
		var m: MultiMesh = mmi.multimesh
		if m.instance_count < arr.size():
			m.instance_count = arr.size() + 16
		for k in m.instance_count:
			m.set_instance_transform(k, arr[k] if k < arr.size() else Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -50, 0)))


## World: the cubbies on the booth's back and north walls, and the return
## rack once it's bought. Built here, not in the venue, so the rental counter
## owns its own fittings.
func _build_shelves() -> void:
	_shelf_built = true
	var old := get_node_or_null("Cubbies")
	if old:
		old.free()
	var b := VoxelMeshBuilder.new()
	var wood := Color("7a5c3c")
	var dark := wood.darkened(0.25)
	# adult cubbies: 13 columns on the back wall, kids' 6 on the side wall
	var bd := booth_depth - 0.2
	for y in [0.05, 0.6, 1.22, 1.85]:
		_slab(b, bd - 0.19, bd + 0.19, a_min + 0.1, a_max - 0.1, y, y + 0.04, wood)
	for k in 14:
		var a := _adult_a(k) - 0.5 * (a_max - a_min - 0.5) / 12.0
		_slab(b, bd - 0.19, bd + 0.19, a - 0.015, a + 0.015, 0.05, 1.87, dark)
	var ka := a_min + 0.17
	var d0 := counter_d + 1.0 - 0.15
	var d1 := counter_d + 1.0 + 5 * 0.3 + 0.15
	for y2 in [0.05, 0.6, 1.22]:
		_slab(b, d0, d1, ka - 0.17, ka + 0.17, y2, y2 + 0.04, wood)
	for k2 in 7:
		var dd := d0 + k2 * 0.3
		_slab(b, dd - 0.015, dd + 0.015, ka - 0.17, ka + 0.17, 0.05, 1.25, dark)
	var mi := MeshInstance3D.new()
	mi.name = "Cubbies"
	mi.cast_shadow = Look.cast()
	mi.mesh = b.commit(VoxelMeshBuilder.material())
	add_child(mi)
	var rk := get_node_or_null("ReturnRack")
	if has_rack and rk == null:
		var r := MeshInstance3D.new()
		r.name = "ReturnRack"
		r.cast_shadow = Look.cast()
		r.mesh = OnIceArt.mesh("return_rack")
		r.transform = Transform3D(Basis(Vector3.UP, atan2(into.x, into.y)).scaled(Vector3.ONE * 0.5), Vector3(RACK.x, 1.12, RACK.y))
		add_child(r)


## An axis-aligned box between two (d, a) corners and two heights.
func _slab(b: VoxelMeshBuilder, d0: float, d1: float, a0: float, a1: float, y0: float, y1: float, col: Color) -> void:
	var p0 := L(d0, a0)
	var p1 := L(d1, a1)
	var mn := Vector3(minf(p0.x, p1.x), y0, minf(p0.y, p1.y))
	var mx := Vector3(maxf(p0.x, p1.x), y1, maxf(p0.y, p1.y))
	b.add_box(Transform3D(Basis.IDENTITY.scaled(mx - mn), (mn + mx) * 0.5), col)
