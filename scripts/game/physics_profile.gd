class_name PhysicsProfile
extends RefCounted
## Turns a skater's ratings (Skills, 1..100) into the physical numbers the
## simulation uses. This is the only rating-to-physics converter. Every rating-to-physics curve lives here so balance can be
## tuned in one place; `tools/physics_bench.sh` prints what they produce.
##
## Units: metres, seconds, m/s. 25 mph = 11.18 m/s.

const MPH := 0.44704
const CEILING := 25.0 * MPH  ## nobody skates faster than 25 mph

# skating
var max_speed := 9.0       ## m/s, absolute top skating speed, dash included
var accel := 7.0           ## m/s^2 from a standstill, falls off toward max_speed
var turn_slow := 7.5       ## rad/s heading change when nearly stopped
var turn_fast := 2.4       ## rad/s at top speed (wider arcs)
var edge_grip := 5.0       ## 1/s, how fast sideways slide bleeds off
var stop_decel := 14.0     ## m/s^2 in a hockey stop
var dash_boost := 2.2      ## m/s added by a dash
var dash_cooldown := 0.8   ## s
var balance := 3.5         ## m/s: the jolt (speed change from a hit) this skater can take and stay up
# stick and puck
var blade_speed := 7.0     ## m/s, how fast the blade moves across the arc
var blade_response := 20.0 ## 1/s, how tightly the blade follows the stick
var blade_accel := 110.0   ## m/s^2, how hard the blade can change direction
var puck_grip := 60.0      ## m/s^2, most the blade can accelerate a carried puck
var receive_e := 0.2       ## restitution of a puck off this skater's ready blade: soft hands give with it
var receive_error := 0.2   ## m, how far off a pass's line the hands put the blade (scaled by their tremor)
# shooting and passing
var shot_speed := 36.0     ## m/s, a fully wound slapshot
var wrist_ratio := 0.78    ## a full wrist shot is this fraction of shot_speed
var instant_ratio := 0.55  ## a no-wind-up shot is this fraction of a full wrist shot
var charge_time := 0.6     ## s of wind-up to reach full power
var shot_error := 0.04     ## rad, 1-sigma aim error for a set, charged shot
var instant_error := 2.0   ## error multiplier for a no-wind-up shot
var pass_error := 0.04     ## rad, 1-sigma
# body
var leg_drive := 1000.0    ## N, how hard a checker drives through the hit with the legs
var stick_lift := 0.5      ## 0..1 strength in stick-lift battles


static func from_skills(sk: Skills) -> PhysicsProfile:
	var p := PhysicsProfile.new()
	p.apply(sk)
	return p


## Cheap enough to call every frame, so injury and fatigue modifiers on
## `sk` take effect immediately.
func apply(sk: Skills) -> void:
	var spd := sk.n("speed")
	var agi := sk.n("agility")
	var sh := sk.n("stick_handling")
	var acc := sk.n("shot_accuracy")
	var pw := sk.n("shot_power")
	var rel := sk.n("shot_release")
	var pq := sk.n("pass_quality")
	var hit := sk.n("hitting")
	var tough := sk.n("toughness")

	# absolute ceiling, dash included: 11 mph for a 1, 25 mph for a 100, rising
	# much faster at the top end, so a beer leaguer (~35) tops out near 13 mph
	# and senior AAA (~55) near 15.5; striding alone cruises at Skater.CRUISE
	# of that (Sean, 2026-10-19: skating felt far too fast)
	max_speed = lerpf(11.0, 25.0, pow(spd, 2.0)) * MPH
	accel = lerpf(3.0, 7.5, pow(0.75 * spd + 0.25 * agi, 1.5))
	turn_slow = lerpf(5.5, 9.5, agi)
	turn_fast = lerpf(1.7, 3.3, agi)
	edge_grip = lerpf(3.2, 7.5, agi)
	stop_decel = lerpf(10.0, 18.0, agi)
	dash_boost = lerpf(2.0, 3.2, 0.6 * spd + 0.4 * agi)
	dash_cooldown = lerpf(1.1, 0.6, agi)
	balance = lerpf(3.4, 6.0, tough) * lerpf(0.9, 1.1, agi)

	blade_speed = lerpf(6.0, 13.0, sh)
	blade_response = lerpf(18.0, 40.0, sh)
	# a weak stickhandler's blade can jerk harder than it can hold the puck,
	# so quick dekes and hard cuts (agility turns you faster) shake it loose
	blade_accel = lerpf(60.0, 220.0, sh)
	puck_grip = 20.0 + 115.0 * pow(sh, 1.5)
	receive_e = lerpf(0.32, 0.04, 0.6 * pq + 0.4 * sh)
	receive_error = lerpf(0.45, 0.02, 0.6 * pq + 0.4 * sh)

	# ~60 mph slapshot for a 1, ~98 mph for a 100
	shot_speed = lerpf(27.0, 44.0, pw)
	wrist_ratio = lerpf(0.72, 0.82, rel)
	# the no-wind-up shot is weak and wild for a beginner, nearly a full shot for a 100
	instant_ratio = lerpf(0.42, 0.85, rel)
	instant_error = lerpf(3.0, 1.25, rel)
	charge_time = lerpf(0.95, 0.35, rel)
	shot_error = lerpf(0.085, 0.01, acc)

	pass_error = 0.003 + 0.057 * (1.0 - pq) * (1.0 - pq)

	leg_drive = lerpf(500.0, 1500.0, hit)
	stick_lift = clampf(0.5 * sh + 0.5 * hit, 0.0, 1.0)


## Wrist/snap shot speed after `held` seconds of wind-up (0 = instant).
func wrist_speed(held: float) -> float:
	var full := shot_speed * wrist_ratio
	return lerpf(full * instant_ratio, full, charge(held))


func charge(held: float) -> float:
	return clampf(held / charge_time, 0.0, 1.0)


## 1-sigma aim error (radians) for a shot with this much wind-up.
func aim_error(held: float) -> float:
	return shot_error * lerpf(instant_error, 1.0, charge(held))
