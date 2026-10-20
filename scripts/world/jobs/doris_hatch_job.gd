class_name DorisHatchJob
extends JobScene
## The shared frame of Doris's hatch jobs past the plug change (the carb
## clean, DorisCarb; the oil change, DorisOil): the same raised view into her
## engine bay as doris_plugs.gd, with its little bay room, Gus's note on the
## dash, the rag on its stand for the parts that come off, the drop light.
## In the venue they play in place through the service hatch on her right
## side (DorisModel.hatch_frame(), playtest W2): the room hides, the note is
## taped on her side by the hatch and the rag stands by her nose.
##
## Subclasses give _engine_id() and _note_text(), add their own parts in
## _build_parts(), and use bay(p) for points in the engine bay's space
## (JobParts' CARB_AT, DRAIN_AT, ...). Every mesh the scene builds casts
## shadows by Look.cast().

const BAY_AT := Vector3(0.0, 0.5, 0.0)
const RAG_AT := Vector3(0.66, 0.92, -0.32)
const NOTE_AT := Vector3(0.83, 0.9, -0.03)
const RAG_IN_PLACE := Vector3(-0.85, 0.92, -0.55)
const NOTE_IN_PLACE := Vector3(-0.75, 1.05, -0.21)
## A view from the bay floor into the whole engine (the start, the morning).
const WIDE_EYE := Vector3(0.0, 1.0, -1.1)

var rag_at := RAG_AT
var note_at := NOTE_AT
var _note: Label3D
var _paper: MeshInstance3D
var _rag: MeshInstance3D
var _rag_stand: MeshInstance3D
var _tool_node: MeshInstance3D


## A point in the engine bay's space (its pivot on the deck) in the scene's.
static func bay(p: Vector3) -> Vector3:
	return BAY_AT + p


func _engine_id() -> String:
	return "engine_bay"


func _note_text() -> String:
	return ""


## Where the drop light hangs (over what the job works on).
func _drop_light_at() -> Vector3:
	return Vector3(0.3, 1.25, -0.35)


## The job's own parts (after the bay, the note and the rag are up).
func _build_parts() -> void:
	pass


func _build() -> void:
	environment(Color("17181b"), 0.45)
	var n0 := get_child_count()
	slab(Vector3(6.0, 0.2, 5.0), Vector3(0, -0.1, 1.0), Color("6a665c"))
	slab(Vector3(6.0, 3.2, 0.2), Vector3(0, 1.6, 2.4), Wear.OLD_CREAM.darkened(0.15))
	slab(Vector3(6.0, 1.0, 0.21), Vector3(0, 0.5, 2.39), Color("3d6fb0").darkened(0.2))
	# Doris's back end round her engine bay: the chassis under it, the deck
	slab(Vector3(1.1, 0.5, 0.6), BAY_AT + Vector3(0, -0.25, 0.075), Wear.CHARCOAL)
	slab(Vector3(1.3, 0.12, 0.25), BAY_AT + Vector3(0, -0.06, -0.48), Wear.OLD_CREAM)
	var dash := slab(Vector3(0.36, 0.3, 0.05), Vector3(0.84, 0.88, 0.0), Wear.CHARCOAL)
	dash.rotation_degrees = Vector3(-25, -20, 0)
	light(Vector3(-0.6, 2.8, 0.6), 0.8, 6.0, Wear.SODIUM, false)
	light(Vector3(-0.9, 1.6, -0.6), 0.5, 2.5, Color(0.9, 0.95, 1.0), false)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-60.0, 200.0, 0.0)
	key.light_energy = 0.2
	add_child(key)
	for i in range(n0, get_child_count()):
		backdrop.append(get_child(i) as Node3D)
	part(_engine_id(), BAY_AT)
	# Gus's note on the dash, on its paper
	_note = note(_note_text(), NOTE_AT, -20.0, 0.00075, Color("1b2a4a"), Color("f3e7a2"), 0.26, 0.22)
	_note.rotation_degrees.x = -25.0
	_paper = get_child(get_child_count() - 1) as MeshInstance3D
	_paper.rotation_degrees.x = -25.0
	_rag = slab(Vector3(0.3, 0.01, 0.2), RAG_AT, Color("b03a2e"))
	_rag_stand = slab(Vector3(0.5, 0.42, 0.45), RAG_AT + Vector3(0, -0.215, 0.05), Wear.OLD_WOOD_DARK)
	_tool_node = MeshInstance3D.new()
	add_child(_tool_node)
	# the drop light hooked on the cowl, over the work
	light(_drop_light_at(), 1.1, 3.0, Color(1.0, 0.9, 0.72))
	_build_parts()
	for c in find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).cast_shadow = Look.cast()


## In place on Doris: the rag on its stand by her nose, the note on her side.
func _placed() -> void:
	rag_at = RAG_IN_PLACE
	note_at = NOTE_IN_PLACE
	_rag.position = rag_at
	_rag_stand.position = rag_at + Vector3(0, -0.215, 0.05)
	_note.position = note_at
	_note.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	_paper.position = note_at + Vector3(0, 0, 0.004)
	_paper.rotation_degrees = Vector3.ZERO
	_sync(0.0)


## The view onto Gus's note, wherever it's taped.
func note_view() -> void:
	view(note_at + Vector3(-0.28, 0.4, -0.62), note_at + Vector3(-0.01, 0.05, 0.03))


## Lays a thin box (built 1 m long in z) from `a` to `b`: a stream of oil.
static func lay(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	if d.length() < 0.001:
		mi.transform = Transform3D(Basis.from_scale(Vector3(1, 1, 0.001)), a)
		return
	var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(d, up) * Basis.from_scale(Vector3(1, 1, d.length())), (a + b) * 0.5)
