class_name Terrain
extends Node3D
## Procedural savanna: rolling hills, wind-blown grass, tall-grass cover patches,
## acacia trees and rocks. Everything is generated from `world_seed`.

const GRASS_SHADER := preload("res://shaders/grass.gdshader")
const CHUNK := 16.0

var world_seed := 0
var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
## Each patch: Vector3(x, z, radius)
var tall_patches: Array[Vector3] = []
var wind_dir := Vector2(1, 0)
var grass_materials: Array[ShaderMaterial] = []


func generate(seed_value: int) -> void:
	world_seed = seed_value
	rng.seed = seed_value
	noise.seed = seed_value
	noise.frequency = 0.008
	noise.fractal_octaves = 3
	detail.seed = seed_value + 7
	detail.frequency = 0.06
	var a := rng.randf() * TAU
	wind_dir = Vector2(cos(a), sin(a))

	_build_ground()
	_build_bounds()
	_place_tall_patches()
	_build_grass()
	_build_trees()
	_build_rocks()
	_build_backdrop()


# ---------------------------------------------------------------------------
# Queries used by gameplay
# ---------------------------------------------------------------------------

func height_at(x: float, z: float) -> float:
	var h := (noise.get_noise_2d(x, z) * 0.5 + 0.5) * Tuning.HILL_HEIGHT
	# Raise the rim so the play area reads as a valley.
	var half := Tuning.WORLD_SIZE * 0.5
	var edge := maxf(absf(x), absf(z)) / half
	h += pow(clampf((edge - 0.78) / 0.22, 0.0, 1.0), 2.0) * 14.0
	return h


func is_in_tall_grass(p: Vector3) -> bool:
	for patch in tall_patches:
		var dx := p.x - patch.x
		var dz := p.z - patch.y
		if dx * dx + dz * dz < patch.z * patch.z:
			return true
	return false


func random_open_point(margin := 30.0) -> Vector3:
	var half := Tuning.WORLD_SIZE * 0.5 - margin
	var x := rng.randf_range(-half, half)
	var z := rng.randf_range(-half, half)
	return Vector3(x, height_at(x, z), z)


func set_wind(dir: Vector2) -> void:
	wind_dir = dir.normalized()
	for m in grass_materials:
		m.set_shader_parameter("wind_dir", wind_dir)


# ---------------------------------------------------------------------------
# Ground
# ---------------------------------------------------------------------------

func _build_ground() -> void:
	var res := Tuning.TERRAIN_RES
	var size := Tuning.WORLD_SIZE
	var step := size / res
	var half := size * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var heights := PackedFloat32Array()
	heights.resize((res + 1) * (res + 1))

	for zi in res + 1:
		for xi in res + 1:
			var x := -half + xi * step
			var z := -half + zi * step
			heights[zi * (res + 1) + xi] = height_at(x, z)

	var dry := Color(0.64, 0.49, 0.27)
	var green := Color(0.43, 0.43, 0.21)
	var dirt := Color(0.52, 0.37, 0.24)
	for zi in res:
		for xi in res:
			var quad := [[xi, zi], [xi + 1, zi], [xi + 1, zi + 1], [xi, zi + 1]]
			var verts: Array[Vector3] = []
			var cols: Array[Color] = []
			for q in quad:
				var x: float = -half + q[0] * step
				var z: float = -half + q[1] * step
				var y: float = heights[q[1] * (res + 1) + q[0]]
				verts.append(Vector3(x, y, z))
				var n := detail.get_noise_2d(x, z) * 0.5 + 0.5
				var c := dry.lerp(green, clampf(n * 1.3 - 0.2, 0.0, 1.0))
				c = c.lerp(dirt, clampf((noise.get_noise_2d(x * 3.0, z * 3.0) - 0.35) * 2.0, 0.0, 0.6))
				cols.append(c)
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(cols[idx])
				st.add_vertex(verts[idx])
	st.generate_normals()
	var mesh := st.commit()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

	# Collision uses the exact same height samples.
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var shape := HeightMapShape3D.new()
	shape.map_width = res + 1
	shape.map_depth = res + 1
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(step, 1.0, step)
	body.add_child(cs)
	add_child(body)


func _build_bounds() -> void:
	var half := Tuning.WORLD_SIZE * 0.5 - 12.0
	var body := StaticBody3D.new()
	body.name = "Bounds"
	for n in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var wall := WorldBoundaryShape3D.new()
		wall.plane = Plane(-n, -half)
		var cs := CollisionShape3D.new()
		cs.shape = wall
		body.add_child(cs)
	add_child(body)


# ---------------------------------------------------------------------------
# Grass
# ---------------------------------------------------------------------------

func _place_tall_patches() -> void:
	tall_patches.clear()
	for i in Tuning.TALL_GRASS_PATCHES:
		var p := random_open_point(28.0)
		tall_patches.append(Vector3(p.x, p.z, rng.randf_range(6.0, 13.0)))


func _blade_mesh(width: float, height: float) -> ArrayMesh:
	# A tapered blade in 2 segments; UV.y = 0 at root, 1 at tip (used for wind).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [
		[Vector3(-width * 0.5, 0, 0), 0.0], [Vector3(width * 0.5, 0, 0), 0.0],
		[Vector3(-width * 0.32, height * 0.5, 0.02), 0.5], [Vector3(width * 0.32, height * 0.5, 0.02), 0.5],
		[Vector3(0, height, 0.06), 1.0],
	]
	for tri in [[0, 1, 3], [0, 3, 2], [2, 3, 4]]:
		for i in tri:
			st.set_uv(Vector2(0.5, pts[i][1]))
			st.set_normal(Vector3(0, 0.3, 1).normalized())
			st.add_vertex(pts[i][0])
	return st.commit()


func _grass_material(base: Color, tip: Color, strength: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GRASS_SHADER
	m.set_shader_parameter("wind_dir", wind_dir)
	m.set_shader_parameter("wind_strength", strength)
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("tip_color", tip)
	grass_materials.append(m)
	return m


func _build_grass() -> void:
	var root := Node3D.new()
	root.name = "Grass"
	add_child(root)

	var short_mesh := _blade_mesh(0.045, 0.42)
	var short_mat := _grass_material(Color(0.30, 0.22, 0.09), Color(0.86, 0.70, 0.38), 0.18)
	var tall_mesh := _blade_mesh(0.07, 1.4)
	var tall_mat := _grass_material(Color(0.26, 0.19, 0.08), Color(0.92, 0.76, 0.42), 0.45)

	var half := Tuning.WORLD_SIZE * 0.5 - 14.0
	var chunks := int(ceil(half * 2.0 / CHUNK))
	for cz in chunks:
		for cx in chunks:
			var origin := Vector2(-half + cx * CHUNK, -half + cz * CHUNK)
			_grass_chunk(root, origin, short_mesh, short_mat, 1600, 0.6, 60.0, false)

	# Tall grass: one multimesh per patch, visible from far away (it's gameplay info).
	for patch in tall_patches:
		var r := patch.z
		var count := int(PI * r * r * 14.0)
		_grass_patch(root, patch, tall_mesh, tall_mat, count)


func _grass_chunk(parent: Node3D, origin: Vector2, mesh: Mesh, mat: Material,
		count: int, scale_var: float, vis_range: float, _tall: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var x := origin.x + rng.randf() * CHUNK
		var z := origin.y + rng.randf() * CHUNK
		var y := height_at(x, z)
		var s := rng.randf_range(1.0 - scale_var * 0.5, 1.0 + scale_var)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.7, 1.3), s))
		b = b.rotated(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized(), rng.randf() * 0.25)
		mm.set_instance_transform(i, Transform3D(b, Vector3(x, y - 0.02, z)))
		var v := rng.randf_range(0.8, 1.1)
		mm.set_instance_color(i, Color(v, v * rng.randf_range(0.95, 1.05), v * 0.95))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = vis_range
	mmi.visibility_range_end_margin = 10.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mmi)


func _grass_patch(parent: Node3D, patch: Vector3, mesh: Mesh, mat: Material, count: int) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		# sqrt for uniform disc distribution, slightly thinner at the rim
		var ang := rng.randf() * TAU
		var d := sqrt(rng.randf()) * patch.z
		var x := patch.x + cos(ang) * d
		var z := patch.y + sin(ang) * d
		var edge := d / patch.z
		var s := rng.randf_range(0.75, 1.25) * lerpf(1.0, 0.55, edge * edge)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		b = b.rotated(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized(), rng.randf() * 0.3)
		mm.set_instance_transform(i, Transform3D(b, Vector3(x, height_at(x, z) - 0.05, z)))
		var v := rng.randf_range(0.85, 1.1)
		mm.set_instance_color(i, Color(v, v, v * 0.9))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


# ---------------------------------------------------------------------------
# Props
# ---------------------------------------------------------------------------

func _build_trees() -> void:
	var root := Node3D.new()
	root.name = "Trees"
	add_child(root)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.33, 0.24, 0.17)
	bark.roughness = 1.0
	var leaves := StandardMaterial3D.new()
	leaves.albedo_color = Color(0.29, 0.36, 0.16)
	leaves.roughness = 0.9

	var placed := 0
	var attempts := 0
	while placed < Tuning.TREE_COUNT and attempts < 500:
		attempts += 1
		var p := random_open_point(24.0)
		if is_in_tall_grass(p):
			continue
		root.add_child(_acacia(p, bark, leaves))
		placed += 1


func _acacia(p: Vector3, bark: Material, leaves: Material) -> Node3D:
	var tree := StaticBody3D.new()
	tree.position = p
	tree.rotation.y = rng.randf() * TAU
	var s := rng.randf_range(0.8, 1.35)
	var trunk_h := 3.6 * s

	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12 * s
	cyl.bottom_radius = 0.28 * s
	cyl.height = trunk_h
	cyl.radial_segments = 7
	trunk.mesh = cyl
	trunk.material_override = bark
	trunk.position.y = trunk_h * 0.5
	trunk.rotation.z = rng.randf_range(-0.12, 0.12)
	tree.add_child(trunk)

	# Two forked branches + flat canopy layers: the classic acacia silhouette.
	for side in [-1.0, 1.0]:
		var br := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = 0.06 * s
		bc.bottom_radius = 0.12 * s
		bc.height = 1.8 * s
		bc.radial_segments = 6
		br.mesh = bc
		br.material_override = bark
		br.position = Vector3(side * 0.55 * s, trunk_h + 0.45 * s, 0)
		br.rotation.z = -side * 0.7
		tree.add_child(br)

	for layer in 3:
		var canopy := MeshInstance3D.new()
		var sph := SphereMesh.new()
		var r := (2.6 - layer * 0.6) * s * rng.randf_range(0.9, 1.15)
		sph.radius = r
		sph.height = r * 0.42
		sph.radial_segments = 12
		sph.rings = 5
		canopy.mesh = sph
		canopy.material_override = leaves
		canopy.position = Vector3(rng.randf_range(-0.6, 0.6) * s, trunk_h + 1.0 * s + layer * 0.35 * s, rng.randf_range(-0.6, 0.6) * s)
		tree.add_child(canopy)

	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.35 * s
	cs.height = trunk_h
	col.shape = cs
	col.position.y = trunk_h * 0.5
	tree.add_child(col)
	return tree


func _build_rocks() -> void:
	var root := Node3D.new()
	root.name = "Rocks"
	add_child(root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.50, 0.46)
	mat.roughness = 0.95
	for i in Tuning.ROCK_COUNT:
		var p := random_open_point(22.0)
		var body := StaticBody3D.new()
		body.position = p
		var r := rng.randf_range(0.6, 2.2)
		var mi := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = r
		sph.height = r * 2.0
		sph.radial_segments = 7
		sph.rings = 4
		mi.mesh = sph
		mi.material_override = mat
		mi.scale = Vector3(rng.randf_range(0.8, 1.5), rng.randf_range(0.45, 0.8), rng.randf_range(0.8, 1.4))
		mi.rotation = Vector3(rng.randf() * 0.3, rng.randf() * TAU, rng.randf() * 0.3)
		body.add_child(mi)
		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = r * 0.8
		col.shape = shape
		body.add_child(col)
		root.add_child(body)


func _build_backdrop() -> void:
	# Distant mesas and an outer plain, softened by fog, for depth.
	var root := Node3D.new()
	root.name = "Backdrop"
	add_child(root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.50, 0.36, 0.27)
	mat.roughness = 1.0

	# Four strips around the square so the outer plain never pokes into the play area.
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.58, 0.45, 0.27)
	pmat.roughness = 1.0
	var half := Tuning.WORLD_SIZE * 0.5 - 2.0
	var far := 1200.0
	var strips := [
		[Vector2(far * 2, far - half), Vector3(0, 0, (far + half) * 0.5)],
		[Vector2(far * 2, far - half), Vector3(0, 0, -(far + half) * 0.5)],
		[Vector2(far - half, half * 2), Vector3((far + half) * 0.5, 0, 0)],
		[Vector2(far - half, half * 2), Vector3(-(far + half) * 0.5, 0, 0)],
	]
	for s in strips:
		var plain := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = s[0]
		plain.mesh = pm
		plain.material_override = pmat
		plain.position = s[1] + Vector3(0, 12.0, 0)
		plain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(plain)

	for i in 26:
		var a := float(i) / 26.0 * TAU + rng.randf_range(-0.1, 0.1)
		var d := rng.randf_range(420.0, 750.0)
		var mesa := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		var w := rng.randf_range(40.0, 120.0)
		cyl.top_radius = w * rng.randf_range(0.5, 0.85)
		cyl.bottom_radius = w
		cyl.height = rng.randf_range(30.0, 90.0)
		cyl.radial_segments = 9
		mesa.mesh = cyl
		mesa.material_override = mat
		mesa.position = Vector3(cos(a) * d, cyl.height * 0.5 + 4.0, sin(a) * d)
		mesa.scale = Vector3(1.0, 1.0, rng.randf_range(0.5, 1.0))
		mesa.rotation.y = rng.randf() * TAU
		mesa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesa)
