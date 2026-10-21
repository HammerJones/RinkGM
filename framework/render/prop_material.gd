class_name PropMaterial
extends RefCounted
## The shared ShaderMaterial for voxel props (framework/render/voxel_prop.gdshader):
## vertex-colour albedo with a per-instance tint and a look-at highlight.
## PropField puts it on every batch and live body; anything else that draws a
## prop and wants the same look uses `PropMaterial.shared()`.

const SHADER := "res://framework/render/voxel_prop.gdshader"

static var _material: ShaderMaterial


static func shared() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load(SHADER)
	return _material


## A live body's own copy, with its tint and highlight as plain uniforms.
static func for_body(tint: Color, highlight: float) -> ShaderMaterial:
	var m: ShaderMaterial = shared().duplicate()
	m.set_shader_parameter("inst_tint", tint)
	m.set_shader_parameter("inst_highlight", highlight)
	return m


## The custom-data colour for a MultiMesh instance: tint in rgb, highlight
## in a. A tint of pure black would read as "no custom data" in the
## shader, so it is nudged.
static func custom(tint: Color, highlight: float) -> Color:
	var t := tint
	if t.r + t.g + t.b <= 0.0:
		t = Color(0.004, 0.004, 0.004)
	return Color(t.r, t.g, t.b, clampf(highlight, 0.0, 1.0))
