class_name DemoPuck
extends Node3D
## A puck on the demo's ice, the game's own model (Models.puck(), drawn at
## twice regulation so it reads from the camera). It slides on the sheet
## plane and loses `FRICTION` of speed a second, bounces off the boards
## (`clamp_fn` keeps it inside, the velocity into them comes back at
## `RESTITUTION`), is cupped on the stick's blade when the blade is on
## it (`carry()`), and LMB shoots it off the blade (`shoot()`). Positions
## are sheet metres; the demo places the node from `at`.

const FRICTION := 0.5  # m/s2 lost sliding on good ice
const RESTITUTION := 0.5
const SHOT_V := 16.0
const CARRY_R := 0.32  # the blade this close has the puck
const REACH := 0.75  # a shot reaches this far from the blade
const RADIUS := Models.PUCK_DIAMETER / 2

var at := Vector2.ZERO  # sheet metres
var vel := Vector2.ZERO
var live := false  # on the ice (false: a prop on a shelf)


func _ready() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Puck"
	mi.mesh = Models.puck().build_mesh()
	add_child(mi)


## One step on the ice; `clamp_fn(p) -> p` holds `p` inside the boards.
func step(dt: float, clamp_fn: Callable) -> void:
	if not live:
		return
	var v := vel.length()
	if v > 0.0:
		v = maxf(v - FRICTION * dt, 0.0)
		vel = vel.normalized() * v
	var a1 := at + vel * dt
	var held: Vector2 = clamp_fn.call(a1)
	if held != a1:
		var n := (held - a1).normalized()
		var into := minf(vel.dot(n), 0.0)
		vel -= n * into * (1.0 + RESTITUTION)
		a1 = held
	at = a1


## The blade at `blade` (sheet metres) with the skater moving `skater_vel`:
## a puck under the blade is cupped on it and goes where it goes.
func carry(blade: Vector2, skater_vel: Vector2) -> bool:
	if not live or at.distance_to(blade) > CARRY_R:
		return false
	var ahead := skater_vel.normalized() * 0.08 if skater_vel.length() > 0.1 else Vector2.ZERO
	at = blade + ahead
	vel = skater_vel
	return true


## A shot from the blade along `dir` when the puck is in reach.
func shoot(blade: Vector2, dir: Vector2, speed := SHOT_V) -> bool:
	if not live or at.distance_to(blade) > REACH:
		return false
	vel = dir.normalized() * speed
	return true
