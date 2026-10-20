class_name IceSkater
extends RefCounted
## One body on (or by) the ice in an on-ice event: a public skater, a coach,
## a pee-wee, a goalie, a ref, a broomballer in sneakers, or a rental clerk
## walking to the shelves. Positions are 2D in venue space, Vector2(x, z);
## the ice is y = 0. OnIceMotion moves them; OnIceDraw draws them.

var id := 0
var name := ""
var person_id := ""      # a Person id when the skater came from Attendance
var role := "skater"     # skater, beginner, kid, couple, speedy_teen, regular, coach, goalie, ref, player, figure, broomball, employee, customer, carrier
var group := -1          # pee-wee group, class level or station
var team := -1
var age := 30
var look := {}
var skill := 0.5         # 0 wobbly to 1 smooth

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var yaw := 0.0           # facing; Basis(Vector3.UP, yaw) faces atan2(-dx, -dz)
var radius := 0.3
var max_speed := 5.0
var accel := 3.0         # m/s per second
var brake := 6.0         # stopping is quicker than starting on skates
var target := Vector2.ZERO
var speed_want := 0.0    # how fast they want to go toward target (0 = stop here)
var arrive := 0.5
var face := Vector2.ZERO # when stopped, face this way (zero = keep)
var backward := false    # skating backwards (faces away from travel)
var on_ice := true       # confined by the boards; false = on the deck or in the lobby
var shoes := false       # broomball: sneakers, not skates
var box := Rect2()       # extra confinement (pee-wee zone, rental booth); size zero = none
var solid := true        # takes part in separation
var hidden := false      # not in the building view (laced up in the stands, gone home)

var state := "skate"     # skate, fallen, getting_up, spin, jump, spiral, stand, hold
var state_t := 0.0
var pose: int = PeopleArt.Pose.STAND
var pose_lock := -1      # a pose the controller wants regardless of motion
var phase := 0.0
var lift := 0.0          # metres off the ice (a jump)
var spin_rate := 0.0     # extra yaw turn rate, radians per second (a spin)
var fall_rate := 0.0     # falls per second at full speed
var partner := -1        # id of the hand they're holding
var lane := 2.0          # public skate: how far in from the boards they like to skate

var puck := -1           # index of the puck on their stick, -1 none
var catching := false    # wants a pass
var carry := ""          # what they're carrying: pylons, pad, bucket, mini_net, skates
var task := {}           # the controller's state for them
var happy := 0.7
var wear_acc := 0.0
var keys := PackedStringArray()


func speed() -> float:
	return vel.length()


func pos3() -> Vector3:
	return Vector3(pos.x, lift, pos.y)


func forward() -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


func go(to: Vector2, spd: float, arrive_r := 0.5) -> void:
	target = to
	speed_want = spd
	arrive = arrive_r


func hold(at := Vector2.INF) -> void:
	target = pos if at == Vector2.INF else at
	speed_want = 0.0 if at == Vector2.INF else 1.2


func at_target(r := -1.0) -> bool:
	return pos.distance_to(target) <= (arrive if r < 0.0 else r)


func down() -> bool:
	return state == "fallen" or state == "getting_up"


## Goes down: slides a little, lies there, then gets up (OnIceMotion).
func fall(rng: RandomNumberGenerator) -> void:
	if down():
		return
	state = "fallen"
	state_t = rng.randf_range(1.4, 3.5) * (1.4 if age < 8 else 1.0)
	speed_want = 0.0
	backward = false
	if puck >= 0:
		task["lost_puck"] = puck


static func make(id_: int, role_: String, age_: int, look_: Dictionary, skill_: float) -> IceSkater:
	var s := IceSkater.new()
	s.id = id_
	s.role = role_
	s.age = age_
	s.look = look_
	s.skill = clampf(skill_, 0.0, 1.0)
	s.radius = clampf(PeopleArt.body_radius(look_, age_) + 0.04, 0.17, 0.42)
	s.max_speed = lerpf(1.2, 8.5, s.skill) * (0.55 + 0.45 * clampf(float(age_) / 16.0, 0.3, 1.0))
	s.accel = lerpf(0.9, 4.5, s.skill)
	s.brake = s.accel * 2.0
	s.fall_rate = lerpf(0.05, 0.0, clampf(s.skill * 1.6, 0.0, 1.0))
	s.name = str(look_.get("name", "Skater %d" % id_))
	return s
