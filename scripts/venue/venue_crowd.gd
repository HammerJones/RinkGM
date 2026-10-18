class_name VenueCrowd
extends MultiMeshInstance3D
## Seated voxel fans, one MultiMesh draw for the whole building. How many
## seats fill comes from the venue's attendance (a beer-league game is a few
## partners and friends near centre ice; minor pro is most of the house).
## Idle fidgeting and goal cheers run in the vertex shader, so a full house
## costs no CPU per frame.

const SKIN := [Color("f1c7a5"), Color("d9a37e"), Color("a86f4c"), Color("6b4430")]
const CASUAL := [Color("39424e"), Color("6d7b8c"), Color("2f5e8a"), Color("8a2f2f"), Color("3e6b3a"),
	Color("c9c2b0"), Color("1d1d22"), Color("b8732d"), Color("5c3d7a"), Color("d9d4c7")]

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform float hype = 0.0;
uniform vec3 skin0; uniform vec3 skin1; uniform vec3 skin2; uniform vec3 skin3;

void vertex() {
	float ph = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
	vec3 c = COLOR.rgb;
	if (UV.x < 0.5) {
		c *= INSTANCE_CUSTOM.rgb;
	} else if (UV.x < 1.5) {
		int k = int(INSTANCE_CUSTOM.a * 4.0 + 0.1);
		c = k == 0 ? skin0 : (k == 1 ? skin1 : (k == 2 ? skin2 : skin3));
	}
	COLOR.rgb = pow(c, vec3(2.2));  // colours are authored in sRGB
	// idle: lean and shift a little
	float t = TIME * (0.6 + ph * 0.5) + ph * 40.0;
	VERTEX.x += sin(t) * 0.012 * VERTEX.y;
	// cheer: the excited fraction of the crowd jumps up with arms raised
	float up = step(1.0 - hype, ph) * hype;
	float jump = up * (0.18 + 0.12 * abs(sin(TIME * 7.0 + ph * 20.0)));
	VERTEX.y += jump;
	VERTEX.y += UV.y * up * 0.45;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
}
"""

var hype := 0.0
var _mat: ShaderMaterial


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	for i in 4:
		_mat.set_shader_parameter("skin%d" % i, Vector3(SKIN[i].r, SKIN[i].g, SKIN[i].b))
	material_override = _mat


## Seats `seats` ([[position, facing], ...] in venue space, facing = toward
## the ice) with a share `fill` of fans. Home colours are worn by about half.
func fill(seats: Array, fill_: float, primary: Color, secondary: Color, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var n := int(round(seats.size() * fill_))
	if fill_ > 0.0:
		n = maxi(n, mini(8, seats.size()))
	# weighted pick: people sit near centre ice and low down first
	var keyed := []
	for i in seats.size():
		var p: Vector3 = seats[i][0]
		var w := 1.0 / (1.0 + absf(p.x) * 0.09) * (1.0 / (1.0 + p.y * 0.18))
		keyed.append([pow(rng.randf(), 1.0 / w), i])
	keyed.sort_custom(func(a, b): return a[0] > b[0])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _fan_mesh()
	mm.instance_count = n
	for k in n:
		var s: Array = seats[keyed[k][1]]
		var facing: Vector3 = s[1]
		var basis := Basis.looking_at(facing, Vector3.UP).scaled(Vector3.ONE * rng.randf_range(0.92, 1.06))
		mm.set_instance_transform(k, Transform3D(basis, s[0]))
		var shirt: Color
		var r := rng.randf()
		if r < 0.32:
			shirt = primary
		elif r < 0.5:
			shirt = secondary
		else:
			shirt = CASUAL[rng.randi() % CASUAL.size()]
		shirt = VoxelMeshBuilder.jitter_color(shirt, k, 0.08)
		mm.set_instance_custom_data(k, Color(shirt.r, shirt.g, shirt.b, float(rng.randi() % 4) / 4.0))
	multimesh = mm
	var taken := []
	for k in n:
		taken.append(seats[keyed[k][1]])
	_build_colliders(taken)


## Cheap colliders for the fans, so a puck over the glass hits people, not
## just seats: one box per run of neighbouring fans in a row (head height,
## torso depth), on the venue layer like the rest of the building.
func _build_colliders(taken: Array) -> void:
	var old := get_node_or_null("FanColliders")
	if old:
		old.free()
	if taken.is_empty():
		return
	var rows := {}
	for s in taken:
		var p: Vector3 = s[0]
		var key := Vector2i(roundi(p.y * 100.0), roundi(p.z * 100.0))
		if not rows.has(key):
			rows[key] = []
		rows[key].append(p.x)
	var body := StaticBody3D.new()
	body.name = "FanColliders"
	body.collision_layer = 1 << (VenueKit.VENUE_LAYER - 1)
	body.collision_mask = 0
	for key in rows:
		var xs: Array = rows[key]
		xs.sort()
		var y: float = key.x / 100.0
		var z: float = key.y / 100.0
		var a: float = xs[0]
		var b: float = xs[0]
		for i in range(1, xs.size() + 1):
			if i < xs.size() and xs[i] - b < 0.8:
				b = xs[i]
				continue
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(b - a + 0.45, 0.96, 0.32)
			cs.shape = box
			cs.position = Vector3((a + b) * 0.5, y + 0.48, z)
			body.add_child(cs)
			if i < xs.size():
				a = xs[i]
				b = xs[i]
	add_child(body)


func count() -> int:
	return multimesh.instance_count if multimesh else 0


## A goal: `amount` 1 for a home goal (the building erupts), less for away.
func cheer(amount: float) -> void:
	hype = maxf(hype, amount)


func _process(dt: float) -> void:
	if hype > 0.0:
		hype = maxf(0.0, hype - dt * 0.22)
		_mat.set_shader_parameter("hype", hype)


## One seated fan, origin on the seat, facing -Z. UV.x picks the colour
## source (0 shirt, 1 skin, 2 fixed); UV.y = 1 marks arms (raised on cheers).
static func _fan_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pants := Color("2b2f3a")
	var hair := Color("3a2a1e")
	_box(st, Vector3(-0.19, 0.0, -0.42), Vector3(0.19, 0.15, 0.02), pants, 2, 0)   # thighs
	_box(st, Vector3(-0.18, -0.42, -0.48), Vector3(0.18, 0.02, -0.34), pants, 2, 0)  # shins
	_box(st, Vector3(-0.2, 0.12, -0.06), Vector3(0.2, 0.66, 0.16), Color.WHITE, 0, 0)  # torso
	_box(st, Vector3(-0.29, 0.3, -0.12), Vector3(-0.2, 0.64, 0.08), Color.WHITE, 0, 1)  # arms
	_box(st, Vector3(0.2, 0.3, -0.12), Vector3(0.29, 0.64, 0.08), Color.WHITE, 0, 1)
	_box(st, Vector3(-0.12, 0.66, -0.08), Vector3(0.12, 0.92, 0.14), Color.WHITE, 1, 0)  # head
	_box(st, Vector3(-0.13, 0.88, -0.06), Vector3(0.13, 0.96, 0.15), hair, 2, 0)
	return st.commit()


static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3, col: Color, part: int, arm: int) -> void:
	var c := (lo + hi) * 0.5
	var s := hi - lo
	for face in VoxelMeshBuilder.CUBE_FACES:
		var n: Vector3 = face[0]
		var q: Array = face[1]
		var pts: Array[Vector3] = []
		for v in q:
			pts.append(c + v * s)
		var order := [0, 1, 2, 0, 2, 3]
		if (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(n) > 0.0:
			order = [0, 2, 1, 0, 3, 2]
		for i in order:
			st.set_color(col)
			st.set_normal(n)
			# only the top of an arm rises, so arms stretch up on a cheer
			st.set_uv(Vector2(part, arm if pts[i].y > lo.y + s.y * 0.5 else 0))
			st.add_vertex(pts[i])
