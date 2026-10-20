class_name JobScene
extends Node3D
## The shared frame of the hands-on mini games (docs/world/RINK_SIM.md 4.1):
## a small diorama, a first-person camera that eases to what the current step
## works on, the JobInput verbs, a checklist of steps and the RinkOS HUD.
##
## The scene contract (agreed with Venue, which opens these as overlays):
##   begin(ctx)  ctx = {sim: RinkSim, job: String, target: String, room: String}
##   signal finished(result)  result = {quality: 0..1, ...the job's args}, or
##               {cancelled: true} if Back is pressed before the job is done
##               (nothing is charged). The caller runs sim.job(job, result).
##   In place (playtest W2): ctx may also carry "place" (Transform3D, global:
##   where the diorama's origin goes, e.g. DorisModel.hatch_frame() on the
##   bay's Doris), "host" (the machine: open_for_service(on) is called on
##   it) and "eye" (the walker's camera, Transform3D). The scene then plays
##   where it stands: no teleport, its own room (`backdrop`) hidden, and the
##   camera leans in from the walker's eye to the first view.
##
## Verbs (JobInput, BENCH context):
##   interact     do the step: read, fit, choose, "that's done"
##   grab + turn  work the fastener with the tool in hand (+ tightens)
##   grab + pump  the pump handle; grab held alone: a slow heavy lift
##   move x       pick the tool off the tray, or the screw / plug in front
##   move y       the second choice: a drawer, the torque wrench's dial
##   look         a little look around while not grabbing
##   back         leave (cancel) before it's done
##
## Subclasses fill `steps` in _setup(), build their diorama in _build(), work
## the current step in _work(frame, dt) and say what's done in _result().

signal finished(result: Dictionary)

const LOOK_YAW := 0.45
const LOOK_PITCH := 0.3

## The RinkSim (typed loosely so a job scene still loads while the sim is mid-edit).
var sim: Object
var job := ""
var target := ""
var room := ""
var skill := 0.3

var input: JobInput
var hud: JobHud
var cam: Camera3D
## Steps: {id: String, text: String}. `step` indexes the current one.
var steps: Array[Dictionary] = []
var step := 0
## The current line, in Gus's voice where a note applies, and the controls.
var prompt := ""
var hint := ""
## The tool tray for the current step and the one in hand.
var tools: PackedStringArray = []
var tool_idx := 0
## What move x / move y pick among in the current step (screws, plugs, drawers).
var selection := 0
var selection_y := 0
var title := "JOB"
## Set once the last step is done: the summary shows and interact closes it.
var complete := false
var closed := false
var result := {}
var log_lines: PackedStringArray = []
## The diorama's own room (floor, walls, its lamps): subclasses add to it in
## _build(); it hides when the job plays in place.
var backdrop: Array[Node3D] = []
var in_place := false
var host: Node3D

var _built := false
var _started := false
var _eye := Vector3(0, 1.5, -1.0)
var _look_at := Vector3.ZERO
var _cam_eye := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _mx := 0.0
var _my := 0.0
var _snap := true
var _env: WorldEnvironment

const TOOL_NAMES := {
	"hand": "HAND", "ratchet": "RATCHET", "filter_wrench": "FILTER_WRENCH",
	"torque_wrench": "TORQUE_WRENCH", "plug_socket": "PLUG_SOCKET",
}


func _ready() -> void:
	_ensure_built()
	if _env and get_viewport().find_world_3d().environment == null:
		add_child(_env)  # standalone: the venue's own environment wins when there is one
	cam.make_current()
	if get_tree().current_scene == self:
		# opened on its own (F6 in the editor): a quick default job
		if not _started:
			begin({"job": job, "target": target})
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The contract's entry point. Safe before or after the scene enters the tree.
func begin(ctx: Dictionary) -> void:
	var s: Variant = ctx.get("sim", null)
	sim = s as Object
	job = str(ctx.get("job", job))
	target = str(ctx.get("target", target))
	room = str(ctx.get("room", room))
	if sim:
		var sk: Variant = sim.get("skill")
		if sk is Dictionary:
			skill = float(sk.get("mechanic", 0.3))
	_ensure_built()
	_start()
	var place: Variant = ctx.get("place", null)
	if place is Transform3D:
		_place_in(place, ctx)


## Plays the job where it stands in the venue (see the contract above).
func _place_in(place: Transform3D, ctx: Dictionary) -> void:
	in_place = true
	if is_inside_tree():
		global_transform = place
	else:
		transform = place
	for n in backdrop:
		if is_instance_valid(n):
			n.visible = false
	host = ctx.get("host", null) as Node3D
	if host and host.has_method("open_for_service"):
		host.call("open_for_service", true)
	_placed()
	_enter_step(step)
	var eye: Variant = ctx.get("eye", null)
	if eye is Transform3D:
		var e: Transform3D = eye
		var inv := (global_transform if is_inside_tree() else transform).affine_inverse()
		_cam_eye = inv * e.origin
		_cam_look = inv * (e.origin - e.basis.z)
		_snap = false
	else:
		snap_camera()


## In place: the subclass moves what it keeps (a note onto the machine).
func _placed() -> void:
	pass


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	input = JobInput.new()
	input.name = "JobInput"
	add_child(input)
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.02
	add_child(cam)
	_build()
	hud = JobHud.new()
	add_child(hud)


func _start() -> void:
	_started = true
	complete = false
	closed = false
	step = 0
	steps.clear()
	_setup()
	_enter(0)
	_refresh()


# ---------------------------------------------------------------- virtuals

func _build() -> void:
	pass


func _setup() -> void:
	pass


## Called when step `i` becomes current: set the prompt, tools, camera.
func _enter_step(_i: int) -> void:
	pass


func _work(_f: JobInput.Frame, _dt: float) -> void:
	pass


## The result args (quality and the job's own), built when the job is done.
func _result() -> Dictionary:
	return {"quality": 1.0}


## Lines for the tool panel (BBCode).
func _tool_lines() -> PackedStringArray:
	return PackedStringArray()


## Keeps the 3D parts in step with the models (rotations, levels).
func _sync(_dt: float) -> void:
	pass


# ---------------------------------------------------------------- the loop

func _physics_process(dt: float) -> void:
	tick(dt)


## One tick of the job: poll the input and work the current step. Tests call
## this directly (with physics processing off) to drive the scene.
func tick(dt: float) -> void:
	if not _started or closed:
		return
	var f := input.poll(dt, JobInput.Context.BENCH)
	if complete:
		if f.interact_pressed or f.back_pressed:
			_close(result)
		_camera(f, dt)
		_refresh()
		return
	if f.back_pressed:
		_close({"cancelled": true})
		return
	_pick(f)
	_work(f, dt)
	_sync(dt)
	_camera(f, dt)
	_refresh()


func step_id() -> String:
	if complete or step >= steps.size():
		return "done"
	return str(steps[step].id)


func tool() -> String:
	return tools[tool_idx] if tool_idx < tools.size() else "hand"


func fastener_tool() -> Fastener.Tool:
	match tool():
		"hand":
			return Fastener.Tool.HAND
		"torque_wrench":
			return Fastener.Tool.TORQUE_WRENCH
	return Fastener.Tool.RATCHET


## Moves on to the next step (or finishes the job after the last one).
func advance(note := "") -> void:
	if not note.is_empty():
		log_lines.append(note)
	if step + 1 >= steps.size():
		step = steps.size()
		result = _result()
		complete = true
		_summary()
		return
	_enter(step + 1)


func _enter(i: int) -> void:
	step = i
	tools = PackedStringArray(["hand"])
	tool_idx = 0
	selection = 0
	selection_y = 0
	hint = ""
	_enter_step(i)


func _summary() -> void:
	var q := float(result.get("quality", 0.0))
	prompt = "Job done. Quality %d%%. %s" % [roundi(q * 100.0), _verdict(q)]
	hint = "%s close" % RinkOS.key("E")


static func _verdict(q: float) -> String:
	if q >= 0.9:
		return "Gus would nod at that."
	if q >= 0.75:
		return "It'll do. Mostly."
	return "It runs. Something in there will remember this."


func _close(r: Dictionary) -> void:
	if closed:
		return
	closed = true
	_unplace()
	finished.emit(r)


func _unplace() -> void:
	if in_place and is_instance_valid(host) and host.has_method("open_for_service"):
		host.call("open_for_service", false)
	host = null


# ---------------------------------------------------------------- input helpers

## Tray and selection picks on the edges of move x / move y.
func _pick(f: JobInput.Frame) -> void:
	var x := f.move.x
	var y := f.move.y
	if absf(x) > 0.5 and absf(_mx) <= 0.5:
		var d := 1 if x > 0.0 else -1
		if tools.size() > 1:
			tool_idx = posmod(tool_idx + d, tools.size())
		_on_pick_x(d)
	if absf(y) > 0.5 and absf(_my) <= 0.5:
		_on_pick_y(1 if y > 0.0 else -1)
	_mx = x
	_my = y


func _on_pick_x(_d: int) -> void:
	pass


func _on_pick_y(_d: int) -> void:
	pass


## Turns `f` by the frame's turn while grab is held, with the tool in hand.
## Loosening with fingers is refused once it's tighter than a hand can break.
## Returns the turns it took.
func work(fs: Fastener, fr: JobInput.Frame, wrench: TorqueWrench = null) -> float:
	if fr.grab <= 0.5 or fr.turn == 0.0:
		return 0.0
	if fr.turn < 0.0 and tool() == "hand" and fs.torque() > fs.hand_limit + 0.01:
		hint = "Too tight for fingers. %s for the wrench." % RinkOS.key("A/D")
		return 0.0
	if wrench and tool() == "torque_wrench" and fr.turn > 0.0:
		return wrench.pull(fr.turn)
	return fs.turn(fr.turn, fastener_tool())


## Broken free and backed off a little: the rest spins out by hand.
static func cracked(fs: Fastener) -> bool:
	return fs.past_seat <= 0.001 and fs.run <= fs.thread_turns - 0.25


## A fastener freshly done up to `extra` past its seat (an old part in place).
static func installed(fs: Fastener, deg_past_seat: float) -> Fastener:
	fs.run = fs.thread_turns
	fs.past_seat = deg_past_seat
	return fs


## Turns of `fs` in radians (for the part's rotation about its axis).
static func spin(fs: Fastener) -> float:
	return -(fs.run * TAU + deg_to_rad(fs.past_seat))


# ---------------------------------------------------------------- camera

## Where the camera eases to for this step.
func view(eye: Vector3, at: Vector3) -> void:
	_eye = eye
	_look_at = at


func _camera(f: JobInput.Frame, dt: float) -> void:
	if f.grab <= 0.5:
		_yaw = clampf(_yaw - f.look.x, -LOOK_YAW, LOOK_YAW)
		_pitch = clampf(_pitch + f.look.y, -LOOK_PITCH, LOOK_PITCH)
	var k := 1.0 if _snap else 1.0 - exp(-dt * 4.0)
	_snap = false
	_cam_eye = _cam_eye.lerp(_eye, k)
	_cam_look = _cam_look.lerp(_look_at, k)
	var dir := (_cam_look - _cam_eye).normalized()
	dir = dir.rotated(Vector3.UP, _yaw)
	var side := dir.cross(Vector3.UP).normalized()
	if side.length() > 0.1:
		dir = dir.rotated(side, _pitch)
	if in_place and is_inside_tree():
		# look_at_from_position works in world space; the views are the scene's
		cam.look_at_from_position(to_global(_cam_eye), to_global(_cam_eye + dir), Vector3.UP)
	else:
		cam.look_at_from_position(_cam_eye, _cam_eye + dir, Vector3.UP)


## Puts the camera straight onto the current view (previews and tests).
func snap_camera() -> void:
	_snap = true
	_camera(JobInput.Frame.new(), 0.0)


# ---------------------------------------------------------------- HUD

func _refresh() -> void:
	if hud == null:
		return
	var lines := PackedStringArray()
	for i in steps.size():
		var s: Dictionary = steps[i]
		var mark := "[x]" if i < step else ("[>]" if i == step else "[ ]")
		var col := RinkOS.GOOD if i < step else (RinkOS.ACTION if i == step else RinkOS.DIM)
		lines.append("[%s]%s %s[/color]" % [RinkOS.bb(col), mark, str(s.text)])
	var tl := _tool_lines()
	if tools.size() > 1 and not complete:
		var tray := PackedStringArray()
		for i in tools.size():
			var n: String = TOOL_NAMES.get(tools[i], tools[i].to_upper())
			tray.append("[%s]%s[/color]" % [RinkOS.bb(RinkOS.ACTION if i == tool_idx else RinkOS.DIM), ("[%s]" % n) if i == tool_idx else n])
		tl.insert(0, " ".join(tray))
	hud.show_state(title, lines, prompt, hint, tl, complete)


## A labelled meter line for the tool panel.
static func meter_line(label: String, v: float, col := RinkOS.READOUT, value := "") -> String:
	return "%s %s %s" % [RinkOS.dots(label, "", 10).strip_edges(), RinkOS.meter_bb(v, col, 12), value]


## A whole Fastener's feel: effort while it snugs up and the turns past hand
## tight, or the torque against its spec.
static func fastener_lines(fs: Fastener, wrench: TorqueWrench = null) -> PackedStringArray:
	var out := PackedStringArray()
	if not fs.seated():
		out.append(meter_line("THREAD", fs.run / fs.thread_turns, RinkOS.READOUT, "%.1f / %.0f turns" % [fs.run, fs.thread_turns]))
	out.append(meter_line("EFFORT", fs.effort(), RinkOS.ALERT if fs.effort() >= 1.0 else RinkOS.READOUT))
	if fs.target_torque > 0.0 and wrench:
		var d := wrench.dial()
		var col := RinkOS.GOOD if wrench.clicked else (RinkOS.ALERT if d > 1.1 else RinkOS.READOUT)
		out.append(meter_line("DIAL", d, col, "%d/%d ft-lb" % [roundi(fs.torque()), roundi(wrench.set_point)]))
		if wrench.clicked:
			out.append("[%s]// CLICK[/color]" % RinkOS.bb(RinkOS.GOOD))
	elif fs.target_torque <= 0.0 and fs.seated():
		var past := fs.turns_past_hand_tight()
		var v := clampf(past / maxf(fs.plus_turns, 0.01), 0.0, 1.5) / 1.5
		out.append(meter_line("PAST_HT", v, RinkOS.GOOD if absf(past - fs.plus_turns) <= fs.turns_tol else RinkOS.READOUT,
			"%+.2f/%+.2f" % [maxf(past, -1.0), fs.plus_turns]))
	if fs.cross_threaded:
		out.append("[%s]// BINDING. IT WENT IN CROOKED[/color]" % RinkOS.bb(RinkOS.ALERT))
	return out


# ---------------------------------------------------------------- diorama helpers

func part(id: String, pos: Vector3, parent: Node3D = null, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = JobParts.mesh(id)
	mi.transform = Transform3D(basis, pos)
	(parent if parent else self).add_child(mi)
	return mi


func prop(id: String, pos: Vector3, yaw_deg := 0.0, age := Wear.WORN) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Props.mesh(id, age)
	mi.position = pos
	mi.rotation_degrees.y = yaw_deg
	add_child(mi)
	return mi


func slab(size: Vector3, pos: Vector3, c: Color, emit := 0.0, parent: Node3D = null) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.9
	if emit > 0.0:
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = emit
	bm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi


## A paper note or a stencilled label in the world (pixel font, RinkOS).
func note(text: String, pos: Vector3, yaw_deg := 0.0, size := 0.004, col := Color("222222"), paper := Wear.PAPER, w := 0.0, h := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = RinkOS.PIXEL_FONT
	l.font_size = 16
	l.pixel_size = size
	l.modulate = col
	l.outline_size = 0
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.shaded = false
	l.double_sided = false
	l.width = 0.0
	l.position = pos
	l.rotation_degrees.y = yaw_deg + 180.0  # Label3D reads along +Z; props face -Z
	add_child(l)
	if w > 0.0:
		var back := slab(Vector3(w, h, 0.004), pos + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(0, 0, 0.004), paper)
		back.rotation_degrees.y = yaw_deg
	return l


func light(pos: Vector3, energy := 1.0, rng := 6.0, col := Color(1.0, 0.95, 0.86), shadows := true) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_energy = energy
	o.omni_range = rng
	o.light_color = col
	o.shadow_enabled = shadows
	add_child(o)
	return o


func environment(bg := Color("1a1b1e"), ambient := 0.35) -> void:
	var env := Look.make("studio")
	env.background_color = bg
	env.ambient_light_color = Color(0.92, 0.95, 1.0)
	env.ambient_light_energy = ambient
	_env = WorldEnvironment.new()
	_env.environment = env


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_unplace()
		if is_instance_valid(_env) and _env.get_parent() == null:
			_env.free()
