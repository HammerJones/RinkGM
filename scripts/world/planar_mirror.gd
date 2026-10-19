class_name PlanarMirror
extends Node3D
## A mirror that really reflects (playtest #30): a planar reflection. A
## camera in a SubViewport sits at the viewer's position mirrored across the
## glass, looking back out through it with an off-axis frustum whose near
## plane is the glass itself, so the wall behind never gets in; the result is
## drawn on the mirror's quad, flipped left to right.
##
## It costs nothing far away: the reflection only renders while the active
## camera is within `max_distance`, in front of the glass and has the mirror
## in view. Otherwise the viewport is switched off and the quad shows a dim
## silvered tint.
##
## The quad faces the node's local +Z (into the room) and is `size` wide
## (local X) and high (local Y), centred on the node.

## Visual layer 20 holds mirror glass, so mirrors never draw themselves.
const MIRROR_LAYER := 1 << 19

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D reflection : source_color, filter_linear, repeat_disable;
uniform float live = 0.0;
uniform vec3 tint : source_color = vec3(0.92, 0.95, 0.97);
uniform vec3 idle : source_color = vec3(0.42, 0.46, 0.5);
void fragment() {
	vec3 r = texture(reflection, vec2(1.0 - UV.x, UV.y)).rgb;
	// a faint sheen toward the top keeps the idle glass from reading flat
	vec3 still = idle * (0.85 + 0.25 * (1.0 - UV.y));
	ALBEDO = mix(still, r * tint, live);
}
"""

@export var size := Vector2(2.0, 2.0)
@export var max_distance := 9.0
## Texture resolution: pixels per metre of glass, capped by `max_pixels` on
## the long side.
@export var pixels_per_metre := 180.0
@export var max_pixels := 1536

var active := false
## Frames the reflection actually rendered (for tests and stats).
var renders := 0

var _vp: SubViewport
var _cam: Camera3D
var _quad: MeshInstance3D
var _mat: ShaderMaterial
static var _shader: Shader


static func make(size_: Vector2, max_distance_ := 9.0) -> PlanarMirror:
	var m := PlanarMirror.new()
	m.size = size_
	m.max_distance = max_distance_
	m.name = "Mirror"
	return m


func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_vp = SubViewport.new()
	_vp.name = "Reflection"
	var px := Vector2(size.x, size.y) * pixels_per_metre
	var k := minf(1.0, float(max_pixels) / maxf(px.x, px.y))
	_vp.size = Vector2i(maxi(16, int(px.x * k)), maxi(16, int(px.y * k)))
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.positional_shadow_atlas_size = 0
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_FRUSTUM
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.cull_mask = 0xFFFFF & ~MIRROR_LAYER
	_vp.add_child(_cam)
	_cam.current = true
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.set_shader_parameter("reflection", _vp.get_texture())
	_quad = MeshInstance3D.new()
	_quad.name = "Glass"
	_quad.mesh = _quad_mesh(size)
	_quad.material_override = _mat
	_quad.layers = MIRROR_LAYER
	add_child(_quad)


## The glass: one quad facing +Z, UV (0, 0) at its top left as seen from the front.
static func _quad_mesh(s: Vector2) -> ArrayMesh:
	var h := s * 0.5
	var verts := PackedVector3Array([Vector3(-h.x, h.y, 0), Vector3(h.x, h.y, 0), Vector3(h.x, -h.y, 0), Vector3(-h.x, -h.y, 0)])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var normals := PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _process(_dt: float) -> void:
	var viewer := get_viewport().get_camera_3d() if is_inside_tree() else null
	if viewer == null or viewer == _cam or not _should_render(viewer):
		_set_active(false)
		return
	_set_active(true)
	_follow(viewer.global_position)
	renders += 1


## True when the viewer is near, on the glass side and has the mirror in view.
func _should_render(viewer: Camera3D) -> bool:
	var xf := global_transform
	var n := xf.basis.z.normalized()
	var c := xf.origin
	var p := viewer.global_position
	if (p - c).dot(n) < 0.05 or p.distance_to(c) > max_distance + size.x * 0.5:
		return false
	var hx := xf.basis.x.normalized() * size.x * 0.5
	var hy := xf.basis.y.normalized() * size.y * 0.5
	for pt in [c, c + hx + hy, c + hx - hy, c - hx + hy, c - hx - hy, c + hx, c - hx]:
		if viewer.is_position_in_frustum(pt):
			return true
	return false


## Puts the reflection camera at the viewer's mirror image, looking out
## through the glass, its frustum cut to the glass rectangle.
func _follow(eye: Vector3) -> void:
	var xf := global_transform
	var n := xf.basis.z.normalized()
	var up := xf.basis.y.normalized()
	var c := xf.origin
	var dist := (eye - c).dot(n)
	var rp := eye - n * (2.0 * dist)
	var z := -n
	var x := up.cross(z).normalized()
	_cam.global_transform = Transform3D(Basis(x, up, z), rp)
	var d := c - rp
	var near := maxf(d.dot(n), 0.05)
	_cam.set_frustum(size.y, Vector2(d.dot(x), d.dot(up)), near, near + 40.0)


func _set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	_mat.set_shader_parameter("live", 1.0 if on else 0.0)
