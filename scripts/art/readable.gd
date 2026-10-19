class_name Readable
extends Node3D
## A real, physical piece of writing in the world: a sticky note, a flyer, a
## sign, a plaque, a felt banner, a manual page. You read it by walking up to
## it (and leaning in), never through a UI panel. Each one is pixel art drawn
## in its author's or publisher's own hand (world-literature/pixel-large, the
## generator lives in world-literature/source) and lit by the scene like any
## other object. Defined in assets/readables/readables.json.
##
## The face looks along local +Z and the node's origin is the face's centre,
## so stick one to a surface with its basis Z along the surface normal.
## Readables sit on their own physics layer (READ_LAYER) for picking up and
## inspecting; the walker never collides with them.

const DEFS_PATH := "res://assets/readables/readables.json"
## Physics layer of a readable's pick shape (the venue's walls are 2).
const READ_LAYER := 11

const PAPER_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D front : source_color, filter_nearest;
uniform sampler2D back : source_color, filter_nearest;
uniform bool has_back = false;
uniform vec3 back_color : source_color = vec3(0.92, 0.9, 0.84);
// how far (m) the free bottom edge lifts off the surface: a sticky note curls
uniform float curl = 0.0;
// a hanging banner sways a little
uniform float sway = 0.0;
uniform float rough = 0.85;
uniform float metal = 0.0;
uniform float emit = 0.0;

void vertex() {
	float t = clamp((UV.y - 0.55) / 0.45, 0.0, 1.0);
	VERTEX.z += curl * t * t;
	if (sway > 0.0) {
		float w = sin(TIME * 0.7 + VERTEX.y * 2.0 + NODE_POSITION_WORLD.z) * sway * UV.y;
		VERTEX.z += w;
		VERTEX.x += w * 0.25;
	}
}

void fragment() {
	vec4 f = texture(front, UV);
	if (f.a < 0.5) {
		discard;
	}
	if (FRONT_FACING) {
		ALBEDO = f.rgb;
		EMISSION = f.rgb * emit;
	} else {
		ALBEDO = has_back ? texture(back, vec2(1.0 - UV.x, UV.y)).rgb : back_color;
	}
	ROUGHNESS = rough;
	METALLIC = metal;
}
"""

## Per kind: [backing thickness m, backing colour, roughness, metallic, curl m]
const KINDS := {
	"paper": [0.0, Color("e8e3d4"), 0.9, 0.0, 0.004],
	"sticky": [0.0, Color("e8d870"), 0.85, 0.0, 0.009],
	"card": [0.0, Color("f0ece0"), 0.85, 0.0, 0.002],
	"sticker": [0.0, Color("e8e3d4"), 0.45, 0.0, 0.0],
	"clipboard": [0.006, Color("8a5f33"), 0.75, 0.0, 0.0],
	"sign": [0.004, Color("2a2723"), 0.45, 0.0, 0.0],
	"board": [0.02, Color("4a3a2a"), 0.7, 0.0, 0.0],
	"plaque": [0.008, Color("6b4b1d"), 0.38, 0.75, 0.0],
	"paint": [0.0, Color("000000"), 0.8, 0.0, 0.0],
	"exit": [0.05, Color("d9d6cc"), 0.5, 0.0, 0.0],
	"banner": [0.0, Color("cfc9b9"), 0.95, 0.0, 0.0],
	"marks": [0.0, Color("ffffff"), 0.3, 0.0, 0.0],
}

static var _defs := {}
static var _shader: Shader

## Which readable this is (readables.json id).
var id := ""
## The world readables.json entry (data/world/readables.json) it belongs to,
## if any: a READ spot with that id inspects this object instead of a panel.
var story := ""
var kind := "paper"
var size := Vector2(0.1, 0.1)
## Can be picked up with the left mouse button and stuck somewhere else.
var movable := false
## Banners: metres of string from the top corners up to the rafters.
var string_length := 0.0
var _def := {}
var _face: MeshInstance3D


static func defs() -> Dictionary:
	if _defs.is_empty():
		var f := FileAccess.open(DEFS_PATH, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for e in d.get("items", []):
					_defs[e.id] = e
	return _defs


static func has_def(id_: String) -> bool:
	return defs().has(id_)


## A readable by id, `movable` for loose notes the player can take down.
static func make(id_: String, movable_ := false) -> Readable:
	var r := Readable.new()
	r.id = id_
	r.movable = movable_
	r._def = defs().get(id_, {})
	r.name = "Readable_" + id_
	if not r._def.is_empty():
		r.kind = r._def.get("kind", "paper")
		var s: Array = r._def.get("size", [0.1, 0.1])
		r.size = Vector2(s[0], s[1])
		r.story = r._def.get("story", "")
	return r


## Faces a wall whose outward normal is `normal`, upright.
static func on_wall(normal: Vector3) -> Basis:
	return Basis.looking_at(-normal, Vector3.UP)


## Lying face up on a table, its top edge toward `top` (away from the reader).
static func on_table(top: Vector3) -> Basis:
	return Basis(top.cross(Vector3.UP), top, Vector3.UP)


## Shorthand: makes one and adds it to `parent` at `xf` (face along xf's +Z).
static func stick(parent: Node, id_: String, xf: Transform3D, movable_ := false) -> Readable:
	var r := make(id_, movable_)
	r.transform = xf
	parent.add_child(r)
	return r


func _ready() -> void:
	add_to_group("readables")
	if _def.is_empty():
		push_warning("Readable: no definition for '%s'" % id)
		return
	_build()


func _build() -> void:
	var k: Array = KINDS.get(kind, KINDS.paper)
	var thick: float = k[0]
	var mat := ShaderMaterial.new()
	if _shader == null:
		_shader = Shader.new()
		_shader.code = PAPER_SHADER
	mat.shader = _shader
	var tex: Texture2D = load(_def.texture) if ResourceLoader.exists(_def.texture) else null
	mat.set_shader_parameter("front", tex)
	if _def.has("back") and ResourceLoader.exists(_def.back):
		mat.set_shader_parameter("back", load(_def.back))
		mat.set_shader_parameter("has_back", true)
	mat.set_shader_parameter("back_color", k[1] if thick == 0.0 else Color("3a352e"))
	mat.set_shader_parameter("rough", k[2])
	mat.set_shader_parameter("metal", k[3])
	mat.set_shader_parameter("curl", k[4] * (1.0 if movable or kind == "sticky" else 0.4))
	mat.set_shader_parameter("emit", 0.9 if kind == "exit" else 0.0)
	mat.set_shader_parameter("sway", 0.015 if kind == "banner" else 0.0)
	var q := QuadMesh.new()
	q.size = size
	# paper bends: subdivide so the curl (and a banner's sway) has vertices
	q.subdivide_depth = 6 if kind in ["sticky", "paper", "card", "banner"] else 0
	q.subdivide_width = 2 if kind == "banner" else 0
	q.material = mat
	_face = MeshInstance3D.new()
	_face.mesh = q
	_face.position.z = thick + 0.0008
	add_child(_face)
	if thick > 0.0:
		_backing(thick, k[1])
	if kind == "banner":
		_strings()
	if kind == "exit":
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.25, 0.2)
		l.light_energy = 0.6
		l.omni_range = 2.2
		l.position = Vector3(0, -size.y * 0.5, 0.25)
		Look.fixture(l, 18.0)
		add_child(l)
	_pick_shape(thick)
	no_shadows(self)


## Like the rest of the venue's dressing, readables cast no shadows.
static func no_shadows(n: Node) -> void:
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _backing(thick: float, col: Color) -> void:
	var b := BoxMesh.new()
	var margin := 0.01 if kind in ["board", "clipboard"] else 0.0
	b.size = Vector3(size.x + margin * 2.0, size.y + margin * 2.0, thick)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.7 if kind != "plaque" else 0.4
	m.metallic = 0.7 if kind == "plaque" else 0.0
	b.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.position.z = thick * 0.5
	add_child(mi)
	if kind == "clipboard":
		var clip := BoxMesh.new()
		clip.size = Vector3(size.x * 0.35, 0.03, 0.012)
		var cm := StandardMaterial3D.new()
		cm.albedo_color = Color("b9bcbf")
		cm.metallic = 0.8
		cm.roughness = 0.35
		clip.material = cm
		var ci := MeshInstance3D.new()
		ci.mesh = clip
		ci.position = Vector3(0, size.y * 0.5 - 0.01, thick + 0.006)
		add_child(ci)


## Two strings from the banner's top corners up to the rafters.
func _strings() -> void:
	if string_length <= 0.0:
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("d9d4c7")
	m.roughness = 0.9
	for sx in [-1.0, 1.0]:
		var c := CylinderMesh.new()
		c.top_radius = 0.004
		c.bottom_radius = 0.004
		c.height = string_length
		c.radial_segments = 4
		c.rings = 1
		c.material = m
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.position = Vector3(sx * size.x * 0.42, size.y * 0.5 + string_length * 0.5, 0.004)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _pick_shape(thick: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (READ_LAYER - 1)
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y, maxf(thick, 0.004) + 0.01)
	cs.shape = box
	cs.position.z = maxf(thick, 0.004) * 0.5
	body.add_child(cs)
	body.set_meta("readable", self)
	add_child(body)


## Takes it off its surface (held in the hand): no longer pickable.
func set_pickable(on: bool) -> void:
	for c in get_children():
		if c is StaticBody3D:
			c.collision_layer = (1 << (READ_LAYER - 1)) if on else 0


## Its face centre in world space.
func face_center() -> Vector3:
	return global_transform * Vector3(0, 0, KINDS.get(kind, KINDS.paper)[0])


## The readable a pick ray hit (its collider), or null.
static func from_collider(c: Object) -> Readable:
	if c and c is Node and (c as Node).has_meta("readable"):
		return (c as Node).get_meta("readable")
	return null
