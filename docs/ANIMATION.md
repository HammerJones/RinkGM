# Animations

Skaters are animated procedurally by `SkaterRig` (`scripts/game/skater_rig.gd`):
nothing is keyframed. Each frame the rig reads the skater's state (speed,
pushing, turning, braking, the blade's place on its arc, wind-ups, checks,
knockdowns) and poses the jointed voxel body with two-bone IK. Every number
that shapes those poses lives in `AnimTuning` (`scripts/anim/anim_tuning.gd`).

## Holding the stick

Sean's grip notes (2026-10-18): a player's handedness is the side the stick
lies on, and the top hand is the other one. The top hand stays on the knob
the whole time; wrist movement swings the stick through a wide, weak arc.
The bottom hand slides up and down the shaft: higher to stickhandle, lower
for power on a shot, and it lets go for a long poke check or a wide sweep.
`_pose_stick` does exactly that: the knob is placed as near the top hand's
preferred spot as the top arm can hold it, and the bottom hand takes the
shaft `grip_bottom*` metres below the knob, slides up if that spot is out of
reach and lets go if the shaft is out of reach or the blade is past the
front 90 degrees. The stick's size is tuned with the `stick_*` values (the
voxel players are blocky, so the stick is thicker than a real one).

The stick is one rigid piece: the blade model's heel curves up into a hosel
at a fixed lie (World's `Models.blade`), the shaft carries straight on from
it, and the blade never re-levels itself, so it tips onto its heel or toe
when the hands are higher or lower than a flat lie. The top hand mostly goes
to the height that lays the blade flat (`grip_top_flat`), sways with the
blade (`grip_top_sway`), and with both hands on, the shoulders turn and dip
towards the stick (`grip_shoulder_*`). Limb lengths come from World's
character sheet (`Models.THIGH_V`, `UPPER_ARM_V` and so on: 28 V tall on
skates, 27 V in shoes), and a blade about 1.2 m out
(`AnimPuppet.READY_BLADE`) lets the bottom hand reach the shaft.

The drawn blade sits exactly on the simulated one (`Skater.blade_pos` and
`blade_height`) every frame; only the body and arms are smoothed. The
exceptions: the blade rises with a shot's follow-through after the puck has
gone, and until Physics' physical puck reaches this branch a carried puck
(still placed at `blade_pos`) gets the blade drawn beside it, face on, rather
than through it. Once Skater has `blade_yaw`, the blade is drawn along
Physics' own contact axis and that offset is off.

## Stickhandling

The studio's stickhandling clip uses a loose, physical puck: AnimPuppet
slides it on the ice and bounces it off the drawn blade (substepped, so a
quick blade can't pass through it), and the blade never carries it. The
clip catches the puck on one face, pushes it across, lifts over it while it
slides, sets down on the far side and catches it on the other face; the
wrists angle the blade (`SkaterRig.blade_turn`) so each push also steers the
puck back to its spot out front. In games the puck is still Physics' to move.

## Skating backwards

When a skater's velocity points behind them (faster than `back_speed`),
the stride turns into C-cuts: each skate in turn sweeps out and forward on
its inside edge with the toe turned in, then glides back in under the hips,
both skates staying on the ice. The skater sits lower and more upright
(`back_*` tunables). The studio clip is "Skating backwards".

## On foot

`PersonRig` (scripts/game/person_rig.gd) is the skater's body without the
stick: the same parts, joints and two-bone IK, so a person is the same rig
with or without skates. Owner, staff, coaches and public skaters all use it
and differ only by palette. It only draws: a `VenueWalker` capsule is the
simulated body, and `update_person(walker.velocity, dt)` poses the rig from
it every frame.

- **Walking and running.** Each foot stays planted while it carries weight
  and slides back under the body at exactly the walker's speed, so stride
  length always matches speed and feet never skate on the floor. The hips
  drop as far as the legs need to reach both feet. A run has a flight phase
  (`walk_duty_run` below 0.5). The body turns to face the way it walks.
- **Sprint, jump and crouch.** Past `walk_run_full` the run turns into a
  sprint (`walk_*_sprint`: quick short contacts, high knees, more lean).
  Set `airborne` while the walker is off the floor (`not is_on_floor()`):
  the knee drives up on the way up, the feet reach down on the way down,
  and the frame it lands the hips dip and spring back (`jump_*`). Set
  `crouched` from `VenueWalker.crouched` to stand and walk low
  (`crouch_walk_*`).
- **Poses.** Set `pose` to `SIT` (with `seat` at the seat's front edge;
  the person sits facing away from it), `CROUCH` (a squat at a low panel)
  or `KNEEL` (one knee down, for work low on Doris or a compressor).
- **Reach and grab.** Put a world point in `reach[0]` (left) or `reach[1]`
  (right) and that hand goes there. When it is out of arm's length, the
  upper body bends and turns to bring it in (`reach_bend`). `look` turns the
  head to a point.
- **First person.** `FirstPersonArms` (scripts/game/first_person_arms.gd)
  is a child of the first-person camera: slimmer copies of the same arms
  that rest low in the view and reach to `reach` points with the same IK.
  They draw on render layer `FirstPersonArms.VIEW_LAYER`. Call
  `PersonRig.hide_from_view(layer)` and leave that layer out of the
  first-person camera so the body's own head and arms don't block the view.

The numbers live in AnimTuning's `walk`, `sit`, `crouch` and `reach` groups.
The studio's "On foot" clips (walk, run, sprint, jump, crouch walk, walk
and turn, idle, sit, crouch, kneel, reach and grab, first-person arms) run on `AnimPerson`, which has a
bench, a machine panel and a valve wheel to work at. `--test=anim` checks
that planted feet don't slide, that a runner leaves the floor, that
sitting lands on the seat, that a knee touches down, and that hands land on
their targets and stay there.

## The studio

`scenes/anim/anim_studio.tscn` puts one skater on a treadmill: the skater stays
in place and the ice markings slide underneath, so each animation can be
watched from every side without the skater skating away. A big three-quarter
view sits beside side and front views.

- `LEFT` / `RIGHT` change clip, `SPACE` pauses, `S` cycles slow motion
  (1, 1/2, 1/4), `T` turns the turntable on or off, `C` changes the main camera.
- `TAB` opens the tuning panel: sliders for every `AnimTuning` value the clip
  uses. Changes show at once. `SAVE` writes `assets/anim/anim_tuning.tres`,
  which games load from then on; `RESET CLIP` puts the clip's values back to
  the defaults in `anim_tuning.gd`.

The clips live in `scripts/anim/anim_clips.gd`: ready stance, stickhandling,
wide reach, poke check, easy and full-speed strides, dash, glide, crossovers both ways,
hockey stop, wrist shot, snapshot, slapshot, backhand, backhand snap,
forehand and backhand passes, body check, backward and forward knockdowns,
and three goal celebrations. A clip only says what the skater is doing; the
rig does the animating, so the studio shows exactly what a game shows.

## Review reels

```
godot --path . --write-movie reel.avi --fixed-fps 30 --resolution 1280x720 \
  res://scenes/anim/anim_studio.tscn -- --reel [--clips=wrist_shot,check] [--loops=2]
```

prints `SEG <seconds> <clip>` at each clip's start for cutting single clips.
In the cloud container this runs under `xvfb-run` with
`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json`. `-- --test=anim` is the
headless CI check: every clip plays, the skater never leaves the treadmill,
no part gets a broken transform, the skates stay on the ice, and each action
(follow-through, pass, check, fall, celebration, stop, crossover) happens.

## In games

- Shots: `Skater._fire()` calls `rig.follow_through()`; move shots (snapshot,
  backhand snap, toe-drag shot) are picked up from the shot count.
- Passes: the rig sees the puck leave its blade without a shot and plays a
  short, low follow-through.
- Checks: `Skater.check_timer` drives the shoulder drive.
- Falls: `Skater.stun_timer` knocks the skater down; skaters moving forward
  faster than `fall_forward_speed` go down face first, others backwards.
- Celebrations: the rig listens to `game.events.goal`. The scorer plays one
  of `SkaterRig.CELEBRATIONS` (picked by jersey number, so no random numbers
  are drawn and seeded games replay the same), teammates raise their arms.
