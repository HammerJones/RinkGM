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
towards the stick (`grip_shoulder_*`). The voxel arms are short for a 2 m
skater, so `grip_arm_length` stretches them to a real proportion; that and
a blade about 1.2 m out (`AnimPuppet.READY_BLADE`) are what let the bottom
hand reach the shaft.

A carried puck is drawn against the blade's face (forehand, or backhand
when the blade is out on that side) rather than through its middle.

## Stickhandling

The studio's stickhandling clip uses a loose, physical puck: AnimPuppet
slides it on the ice and bounces it off the drawn blade (substepped, so a
quick blade can't pass through it), and the blade never carries it. The
clip catches the puck on one face, pushes it across, lifts over it while it
slides, sets down on the far side and catches it on the other face; the
wrists angle the blade (`SkaterRig.blade_turn`) so each push also steers the
puck back to its spot out front. In games the puck is still Physics' to move.

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
