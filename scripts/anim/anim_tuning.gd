class_name AnimTuning
extends Resource
## Every number that shapes how skaters move, in one place so the animation
## studio (scenes/anim/anim_studio.tscn) can tune them live and save them to
## `assets/anim/anim_tuning.tres`. SkaterRig reads `AnimTuning.current()`
## every frame, so a change shows up at once in the studio and in games.
##
## Properties are grouped by the prefix before the first underscore; the
## studio shows the groups each clip uses. Distances are metres, angles
## radians, rates per second.

const PATH := "res://assets/anim/anim_tuning.tres"

static var _current: AnimTuning


## The shared tuning: the saved file if there is one, otherwise the defaults.
static func current() -> AnimTuning:
	if _current == null:
		if ResourceLoader.exists(PATH):
			_current = load(PATH) as AnimTuning
		if _current == null:
			_current = AnimTuning.new()
	return _current


## Puts every value back to its default (the studio's reset button).
func reset() -> void:
	var fresh := AnimTuning.new()
	for p in tunables():
		set(p.name, fresh.get(p.name))


## The tunable properties as [{name, group, min, max, step}].
func tunables() -> Array:
	var out := []
	for p in get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or p.hint != PROPERTY_HINT_RANGE:
			continue
		var r: PackedStringArray = p.hint_string.split(",")
		out.append({"name": p.name, "group": p.name.get_slice("_", 0),
			"min": r[0].to_float(), "max": r[1].to_float(), "step": r[2].to_float() if r.size() > 2 else 0.001})
	return out


# ----------------------------------------------------------------- stance
## How far the hips sink below standing height when still.
@export_range(0.0, 0.4, 0.005) var stance_crouch := 0.16
## Extra hip sink at full speed.
@export_range(0.0, 0.3, 0.005) var stance_crouch_speed := 0.05
## Forward lean of the upper body when still.
@export_range(0.0, 1.2, 0.01) var stance_lean := 0.5
## Extra forward lean at full speed.
@export_range(0.0, 1.2, 0.01) var stance_lean_speed := 0.42
## Gap between the skates when gliding on both feet (each side).
@export_range(0.05, 0.4, 0.005) var stance_width := 0.15
## Gentle idle bob while standing.
@export_range(0.0, 0.05, 0.001) var stance_breathe := 0.006
## How much the head stays level while the body leans (1 = always level).
@export_range(0.0, 1.0, 0.01) var stance_head_level := 0.85

# ----------------------------------------------------------------- stride
## Stride length from a standstill (0..1 of a full stride).
@export_range(0.0, 1.0, 0.01) var stride_amp := 0.4
## Extra stride length at full speed.
@export_range(0.0, 1.0, 0.01) var stride_amp_speed := 0.6
## Strides per second from a standstill.
@export_range(0.5, 3.0, 0.01) var stride_cadence := 1.7
## Strides per second at full speed.
@export_range(0.5, 3.0, 0.01) var stride_cadence_fast := 1.25
## How far out to the side each push goes.
@export_range(0.0, 0.6, 0.005) var stride_push_out := 0.3
## How far back each push goes.
@export_range(0.0, 0.5, 0.005) var stride_push_back := 0.2
## How high the skate lifts on the recovery.
@export_range(0.0, 0.25, 0.005) var stride_lift := 0.09
## Toe-out of the pushing skate.
@export_range(0.0, 1.2, 0.01) var stride_toe_out := 0.6
## Hip rotation with each push.
@export_range(0.0, 0.5, 0.005) var stride_hip_twist := 0.16
## How far the hips ride over the gliding skate.
@export_range(0.0, 1.0, 0.01) var stride_hip_shift := 0.55
## Hip bob with each push.
@export_range(0.0, 0.08, 0.001) var stride_bob := 0.025
## Part of each leg's cycle spent gliding under the hips.
@export_range(0.2, 0.7, 0.01) var stride_glide_end := 0.45
## Where the push ends and the recovery starts.
@export_range(0.5, 0.95, 0.01) var stride_push_end := 0.8
## Swing of the free hand when skating one-handed.
@export_range(0.0, 0.4, 0.005) var stride_arm_swing := 0.12

# ------------------------------------------------------------------- back
# Skating backwards: C-cuts. Each skate in turn sweeps out and forward on
# its inside edge, toe turned in, pushing the body back, then glides back in
# under the hips. The skater sits lower with the back more upright.
## How far out each C-cut sweeps, and how far forward it reaches.
@export_range(0.0, 0.5, 0.005) var back_cut_width := 0.2
@export_range(0.0, 0.6, 0.005) var back_cut_reach := 0.28
## Toe turned in through the cut (radians).
@export_range(0.0, 1.0, 0.01) var back_toe_in := 0.45
## Extra hip sink and less forward lean skating backwards.
@export_range(0.0, 0.3, 0.005) var back_sit := 0.06
@export_range(0.0, 1.0, 0.01) var back_upright := 0.25
## Backwards speed (m/s) that counts as skating backwards.
@export_range(0.1, 2.0, 0.05) var back_speed := 0.4
## The turn-around pivot (Skater.backwards toggling): skates apart, toes
## turned out, hips dropped a little.
@export_range(0.05, 0.5, 0.005) var back_pivot_width := 0.22
@export_range(0.0, 1.5, 0.01) var back_pivot_toe_out := 0.7
@export_range(0.0, 0.2, 0.005) var back_pivot_sink := 0.05

# ------------------------------------------------------------------ stick
# Real sticks are about 163 cm tall with a 32-39 cm blade 5-9 cm high; the
# blocky voxel players need a chunkier stick to read at that scale.
## Shaft length, times the model's 1.47 m.
@export_range(0.7, 1.5, 0.01) var stick_length := 0.85
## Shaft and blade thickness, times the model's 3.5 cm shaft.
@export_range(0.8, 3.0, 0.05) var stick_thickness := 1.9
## Blade length, times the model's 30 cm.
@export_range(0.7, 2.0, 0.05) var stick_blade_length := 1.3
## Blade height, times the model's 7 cm.
@export_range(0.7, 2.5, 0.05) var stick_blade_height := 1.6

# ------------------------------------------------------------------- grip
# The top hand (opposite the shooting side) never leaves the knob; the bottom
# hand slides along the shaft and lets go to reach.
## Where the top hand sits across the body (- is its own side).
@export_range(-0.5, 0.3, 0.01) var grip_top_side := -0.1
## Top hand height above the hips (it stays between grip_top_low and
## grip_top_high: hips to chest).
@export_range(0.0, 0.8, 0.01) var grip_top_height := 0.22
## Lowest the top hand goes, above the hips.
@export_range(-0.2, 0.6, 0.01) var grip_top_low := 0.05
## Highest the top hand goes, above the hips (about chest height).
@export_range(0.1, 0.9, 0.01) var grip_top_high := 0.55
## How much the top hand goes to the height that lays the blade flat on
## the ice (1) rather than grip_top_height (0), inside the hips-to-chest
## band. Off the flat height the rigid blade tips onto its heel or toe.
@export_range(0.0, 1.0, 0.01) var grip_top_flat := 0.85
## How far in front of the body the top hand sits.
@export_range(0.0, 0.6, 0.01) var grip_top_fwd := 0.3
## How far the top hand drifts towards the blade's side.
@export_range(0.0, 0.6, 0.01) var grip_top_follow := 0.2
## How far the top hand sways sideways with the blade (times the blade's
## sideways offset), keeping the shaft pointing out at the puck.
@export_range(0.0, 1.0, 0.01) var grip_top_sway := 0.25
## Bottom hand, metres below the knob, while carrying and stickhandling.
@export_range(0.2, 1.2, 0.01) var grip_bottom := 0.45
## Bottom hand on a wrist shot or backhand wind-up (lower = more power).
@export_range(0.2, 1.2, 0.01) var grip_bottom_shot := 0.62
## Bottom hand on a slapshot wind-up.
@export_range(0.2, 1.2, 0.01) var grip_bottom_slap := 0.8
## How quickly the bottom hand slides to its new spot.
@export_range(1.0, 30.0, 0.5) var grip_slide_speed := 10.0
## Arm length (shoulder to the middle of the glove), times the model's
## 0.68 m (World's character sheet). Leave at 1 unless testing.
@export_range(0.8, 1.5, 0.01) var grip_arm_length := 1.0
## Two hands on: the shoulders turn towards the stick (radians) so the
## bottom shoulder comes forward to the shaft ...
@export_range(0.0, 1.0, 0.01) var grip_shoulder_turn := 0.4
## ... and dip on the bottom-hand side (radians).
@export_range(0.0, 0.6, 0.01) var grip_shoulder_dip := 0.15
## Share of the arm's length the hands can use before letting go.
@export_range(0.7, 1.0, 0.01) var grip_reach := 0.97

# ------------------------------------------------------------------- dash
## Stride length multiplier during a dash.
@export_range(1.0, 2.0, 0.01) var dash_amp := 1.25
## Cadence multiplier during a dash.
@export_range(1.0, 2.0, 0.01) var dash_cadence := 1.35
## Extra hip sink during a dash.
@export_range(0.0, 0.15, 0.005) var dash_crouch := 0.03

# -------------------------------------------------------------- crossover
## Body lean into a turn per (turn rate x speed).
@export_range(0.0, 0.15, 0.001) var cross_lean := 0.05
## Most lean allowed in a turn.
@export_range(0.0, 0.9, 0.01) var cross_lean_max := 0.45
## Lean at which crossovers begin.
@export_range(0.0, 0.4, 0.005) var cross_start := 0.08
## Extra lean over which crossovers blend fully in.
@export_range(0.05, 0.6, 0.005) var cross_range := 0.25
## Extra lift of the crossing skate.
@export_range(0.0, 0.2, 0.005) var cross_lift := 0.06
## How far the outside skate crosses over in front.
@export_range(0.0, 0.3, 0.005) var cross_over := 0.12
## How far the inside skate pushes under the body.
@export_range(0.0, 1.0, 0.01) var cross_under := 0.7

# ------------------------------------------------------------------- stop
## How far the body turns sideways in a hockey stop.
@export_range(0.0, 1.8, 0.01) var stop_turn := 1.15
## Extra hip sink in the stop.
@export_range(0.0, 0.25, 0.005) var stop_crouch := 0.07
## Extra upper-body lean in the stop.
@export_range(-0.5, 0.8, 0.01) var stop_lean := 0.2
## Gap between the skates in the stop (each side).
@export_range(0.1, 0.5, 0.005) var stop_width := 0.3
## Sideways lean back against the stop.
@export_range(0.0, 0.6, 0.01) var stop_tilt := 0.25
## How quickly the body swings into the stop.
@export_range(2.0, 30.0, 0.5) var stop_speed := 12.0

# ------------------------------------------------------------------- shot
## Upper body rising out of the crouch as a shot winds up.
@export_range(0.0, 0.6, 0.01) var shot_windup_rise := 0.15
## How much the shoulders turn to follow the blade.
@export_range(0.0, 1.0, 0.01) var shot_shoulder_turn := 0.4
## How high the stick finishes on a follow-through.
@export_range(0.0, 1.2, 0.01) var shot_follow_height := 0.55
## Shoulder turn towards the target on the follow-through.
@export_range(0.0, 1.0, 0.01) var shot_follow_turn := 0.35
## Upper body straightening on the follow-through.
@export_range(0.0, 0.6, 0.01) var shot_follow_rise := 0.15
## How quickly the follow-through fades (per second).
@export_range(0.5, 6.0, 0.05) var shot_follow_fade := 2.2

# ------------------------------------------------------------------- pass
## Strength of the follow-through on a pass (a shot's is 0.3-1).
@export_range(0.0, 1.0, 0.01) var pass_follow := 0.35
## How high the stick finishes on a pass, as a share of a shot's.
@export_range(0.0, 1.0, 0.01) var pass_height := 0.25

# ------------------------------------------------------------------ check
## Hip sink as the check loads up.
@export_range(0.0, 0.3, 0.005) var check_crouch := 0.12
## Forward drive of the upper body into the check.
@export_range(0.0, 1.0, 0.01) var check_lean := 0.45
## Shoulder turn to lead with the shoulder.
@export_range(0.0, 1.5, 0.01) var check_shoulder := 0.75
## Upward explosion at contact.
@export_range(0.0, 0.2, 0.005) var check_rise := 0.06
## Hands pull in towards the chest (0 = stick stays out).
@export_range(0.0, 1.0, 0.01) var check_tuck := 0.6

# ------------------------------------------------------------------- fall
## How far the body tips over when knocked down.
@export_range(0.5, 1.6, 0.01) var fall_angle := 1.35
## How quickly the body goes down.
@export_range(1.0, 20.0, 0.5) var fall_speed := 7.0
## How quickly the skater gets back up.
@export_range(1.0, 20.0, 0.5) var fall_rise_speed := 5.0
## How far the hips drop towards the ice when down.
@export_range(0.0, 0.6, 0.01) var fall_drop := 0.25
## How wide the arms fly out when going down.
@export_range(0.0, 1.0, 0.01) var fall_flail := 0.5
## Forward speed (m/s) above which a knocked-down skater falls forward
## instead of backward.
@export_range(-5.0, 10.0, 0.1) var fall_forward_speed := 3.0

# -------------------------------------------------------------- celebrate
## How long a celebration lasts (seconds).
@export_range(0.5, 5.0, 0.05) var celebrate_time := 2.4
## How high the hands go on the arms-up celebration.
@export_range(0.0, 0.8, 0.01) var celebrate_reach := 0.55
## Fist pumps per second.
@export_range(0.5, 5.0, 0.05) var celebrate_pump_rate := 2.2
## How far the fist travels on each pump.
@export_range(0.0, 0.5, 0.01) var celebrate_pump := 0.28
## How low the knee goes on the knee slide (hip drop).
@export_range(0.0, 0.6, 0.01) var celebrate_knee_drop := 0.38
## Upper-body lean back on the celebrations.
@export_range(-0.5, 0.8, 0.01) var celebrate_lean_back := 0.25

# ------------------------------------------------------------------- walk
# People on foot (PersonRig). The feet stay planted on the floor while they
# carry weight, so a stride's length always matches the walker's speed.
## Steps per second at a stroll (VenueWalker.WALK, 1.4 m/s) ...
@export_range(1.0, 3.0, 0.05) var walk_cadence := 1.8
## ... and at a run (VenueWalker.RUN, 4 m/s).
@export_range(1.5, 4.5, 0.05) var walk_cadence_run := 2.9
## Share of each cycle a foot is on the floor walking (above 0.5: both feet
## down for a moment) ...
@export_range(0.5, 0.75, 0.01) var walk_duty := 0.62
## ... and running (below 0.5: both feet off the floor for a moment).
@export_range(0.2, 0.5, 0.01) var walk_duty_run := 0.36
## How high the swinging foot lifts walking / running.
@export_range(0.0, 0.2, 0.005) var walk_lift := 0.07
@export_range(0.0, 0.4, 0.005) var walk_lift_run := 0.2
## Hip rise and fall with each step.
@export_range(0.0, 0.08, 0.002) var walk_bob := 0.025
## Hips shift over the foot that carries the weight.
@export_range(0.0, 0.1, 0.002) var walk_sway := 0.03
## Hips turn with each stride (radians); the shoulders turn against them.
@export_range(0.0, 0.4, 0.01) var walk_hip_turn := 0.12
## How far the arms swing (radians, at a walk; more at a run).
@export_range(0.0, 1.2, 0.01) var walk_arm_swing := 0.35
## Forward lean of the upper body at a run.
@export_range(0.0, 0.6, 0.01) var walk_run_lean := 0.2
## Feet apart, side to side.
@export_range(0.05, 0.3, 0.005) var walk_width := 0.11
## How quickly the body turns to face the way it walks (per second).
@export_range(1.0, 20.0, 0.5) var walk_turn := 8.0
## Standing still: slow weight shift side to side.
@export_range(0.0, 0.06, 0.002) var walk_idle_sway := 0.015
## Speeds (m/s) where a walk starts turning into a run, is a full run, and
## is a flat-out sprint (VenueWalker: walk 2.2, sprint 6.5).
@export_range(1.5, 4.0, 0.05) var walk_run_from := 2.5
@export_range(2.5, 5.0, 0.05) var walk_run_full := 3.6
@export_range(4.0, 9.0, 0.1) var walk_sprint_speed := 6.5
## A sprint: quick steps, short contacts, high knees, more lean.
@export_range(2.5, 5.5, 0.05) var walk_cadence_sprint := 4.2
@export_range(0.15, 0.4, 0.01) var walk_duty_sprint := 0.24
@export_range(0.0, 0.5, 0.005) var walk_lift_sprint := 0.3
@export_range(0.0, 0.6, 0.01) var walk_sprint_lean := 0.2

# -------------------------------------------------------------------- sit
## Upper-body lean back when sitting (radians).
@export_range(-0.4, 0.6, 0.01) var sit_lean := 0.08
## How far in front of the seat edge the feet rest.
@export_range(0.1, 0.6, 0.01) var sit_feet := 0.38
## How quickly a person sits down or gets up (per second).
@export_range(1.0, 15.0, 0.5) var sit_speed := 5.0

# ------------------------------------------------------------------ crouch
## Hip height in a squat (metres off the floor).
@export_range(0.2, 0.7, 0.01) var crouch_hips := 0.38
## Hip height kneeling on one knee.
@export_range(0.3, 0.8, 0.01) var crouch_kneel_hips := 0.5
## Forward lean of the upper body crouched / kneeling (radians).
@export_range(0.0, 1.2, 0.01) var crouch_lean := 0.45
## Crouched walking and standing (VenueWalker.crouched): hip height and
## forward lean.
@export_range(0.3, 0.8, 0.01) var crouch_walk_hips := 0.52
@export_range(0.0, 1.0, 0.01) var crouch_walk_lean := 0.35

# ------------------------------------------------------------------- jump
## How high the feet tuck up under the body in the air.
@export_range(0.0, 0.5, 0.01) var jump_tuck := 0.25
## How far the arms swing up in a jump (radians).
@export_range(0.0, 2.0, 0.01) var jump_arms := 0.8
## How far the hips dip on landing, and how long the landing takes.
@export_range(0.0, 0.4, 0.01) var jump_land_dip := 0.16
@export_range(0.1, 0.8, 0.01) var jump_land_time := 0.32

# ------------------------------------------------------------------ reach
## How far the upper body bends and turns to bring a hand to a job part
## (share of what's needed, 1 = all the way).
@export_range(0.0, 1.0, 0.01) var reach_bend := 0.8
## How quickly a hand moves onto (or off) its target (per second).
@export_range(1.0, 30.0, 0.5) var reach_speed := 9.0
