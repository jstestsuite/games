class_name AnimalRig
extends Node3D
## A placeholder animal built from primitives, with procedural gait animation.
## Facing is -Z (Godot forward). Feet rest at y = 0.
##
## This is deliberately swappable: when real rigged models arrive (e.g. Quaternius
## CC0 animals), replace this node with the imported scene + an AnimationTree and keep
## the same `animate()` call signature so cheetah.gd / gazelle.gd don't change.

const COAT_SHADER := preload("res://shaders/coat.gdshader")

var p: Dictionary
var torso: Node3D
var neck: Node3D
var head: Node3D
var tail: Node3D
var legs: Array[Dictionary] = []   # {hip, knee, front: bool, side: float}
var phase := 0.0
var _crouch := 0.0
var _neck_pitch := 0.0


## Spec keys: body_len, body_r, leg_len, leg_r, neck_len, neck_r, neck_pitch, head_r,
## head_len, tail_len, ear, horns, coat (Dictionary of shader params), stride.
func build(spec: Dictionary) -> void:
	p = spec
	var coat := ShaderMaterial.new()
	coat.shader = COAT_SHADER
	for k in spec.coat.keys():
		coat.set_shader_parameter(k, spec.coat[k])
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.07, 0.05, 0.04)
	dark.roughness = 0.6

	var r: float = p.body_r
	var L: float = p.body_len
	var leg: float = p.leg_len

	torso = Node3D.new()
	torso.name = "Torso"
	torso.position.y = leg + r * 0.3
	add_child(torso)

	var body := _mesh(_capsule(r, L), coat)
	body.rotation.x = PI * 0.5
	torso.add_child(body)
	# Chest is slightly deeper than the waist.
	var chest := _mesh(_sphere(r * 1.12), coat)
	chest.position = Vector3(0, 0.02, -L * 0.28)
	chest.scale = Vector3(1.0, 1.05, 1.3)
	torso.add_child(chest)

	for front in [true, false]:
		for side in [-1.0, 1.0]:
			legs.append(_build_leg(front, side, coat, dark))

	neck = Node3D.new()
	neck.position = Vector3(0, r * 0.45, -L * 0.42)
	_neck_pitch = p.neck_pitch
	neck.rotation.x = _neck_pitch
	torso.add_child(neck)
	var nm := _mesh(_cyl(p.neck_r * 0.8, p.neck_r, p.neck_len), coat)
	nm.position.y = p.neck_len * 0.5
	neck.add_child(nm)

	head = Node3D.new()
	head.position.y = p.neck_len
	head.rotation.x = -_neck_pitch
	neck.add_child(head)
	var hm := _mesh(_sphere(p.head_r), coat)
	hm.scale = Vector3(0.95, 0.9, p.head_len)
	hm.position.z = -p.head_r * 0.4
	head.add_child(hm)
	var snout := _mesh(_sphere(p.head_r * 0.55), coat)
	snout.position = Vector3(0, -p.head_r * 0.25, -p.head_r * (0.6 + p.head_len * 0.55))
	snout.scale = Vector3(1.0, 0.8, 1.3)
	head.add_child(snout)
	var nose := _mesh(_sphere(p.head_r * 0.16), dark)
	nose.position = Vector3(0, -p.head_r * 0.15, -p.head_r * (0.95 + p.head_len * 0.6))
	head.add_child(nose)
	for side in [-1.0, 1.0]:
		var eye := _mesh(_sphere(p.head_r * 0.13), dark)
		eye.position = Vector3(side * p.head_r * 0.55, p.head_r * 0.25, -p.head_r * 0.55)
		head.add_child(eye)
		var ear := _mesh(_cyl(0.0, p.head_r * 0.28 * p.ear, p.head_r * 0.7 * p.ear, 5), coat)
		ear.position = Vector3(side * p.head_r * 0.55, p.head_r * 0.75, p.head_r * 0.1)
		ear.rotation.z = -side * 0.5
		head.add_child(ear)
		if p.get("horns", false):
			var horn := _mesh(_cyl(0.004, p.head_r * 0.12, p.head_r * 2.6, 5), dark)
			horn.position = Vector3(side * p.head_r * 0.3, p.head_r * 1.6, p.head_r * 0.45)
			horn.rotation = Vector3(-0.45, 0, -side * 0.12)
			head.add_child(horn)

	tail = Node3D.new()
	tail.position = Vector3(0, r * 0.35, L * 0.48)
	tail.rotation.x = 2.2
	torso.add_child(tail)
	var tm := _mesh(_cyl(p.leg_r * 0.35, p.leg_r * 0.6, p.tail_len), coat)
	tm.position.y = p.tail_len * 0.5
	tail.add_child(tm)
	if p.get("tail_tip", false):
		var tip := _mesh(_sphere(p.leg_r * 0.7), dark)
		tip.position.y = p.tail_len
		tail.add_child(tip)


func _build_leg(front: bool, side: float, coat: Material, dark: Material) -> Dictionary:
	var r: float = p.body_r
	var L: float = p.body_len
	var leg: float = p.leg_len
	var hip := Node3D.new()
	hip.position = Vector3(side * r * 0.55, -r * 0.3, (-L * 0.36) if front else (L * 0.36))
	torso.add_child(hip)
	var up := _mesh(_cyl(p.leg_r * 0.8, p.leg_r * (1.5 if not front else 1.2), leg * 0.52), coat)
	up.position.y = -leg * 0.26
	hip.add_child(up)
	var knee := Node3D.new()
	knee.position.y = -leg * 0.5
	hip.add_child(knee)
	var low := _mesh(_cyl(p.leg_r * 0.55, p.leg_r * 0.8, leg * 0.5), coat)
	low.position.y = -leg * 0.25
	knee.add_child(low)
	var foot := _mesh(_sphere(p.leg_r * 0.85), dark if p.get("hooves", false) else coat)
	foot.position = Vector3(0, -leg * 0.5, -p.leg_r * 0.4)
	foot.scale = Vector3(1, 0.6, 1.4)
	knee.add_child(foot)
	return {"hip": hip, "knee": knee, "front": front, "side": side}


## speed_norm: 0 idle .. ~0.3 walk .. 1 full gallop.
## crouch: 0..1. head_down: 0..1 (grazing). Call every frame.
func animate(delta: float, speed: float, speed_norm: float, crouch: float, head_down := 0.0) -> void:
	var stride: float = p.get("stride", 1.6)
	phase = fmod(phase + delta * (speed / stride) * TAU * 0.5 + delta * speed_norm * 2.0, TAU * 100.0)
	_crouch = lerpf(_crouch, crouch, 1.0 - exp(-10.0 * delta))
	var moving := clampf(speed / 1.0, 0.0, 1.0)
	var gallop := smoothstep(0.35, 0.75, speed_norm)
	var amp := lerpf(0.45, 1.0, gallop) * moving

	for l in legs:
		# Walk/trot: diagonal pairs. Gallop: front pair vs back pair, slightly offset L/R.
		var trot_off := 0.0 if (l.front == (l.side > 0)) else PI
		var gal_off := (0.0 if l.front else PI * 0.85) + (0.25 if l.side > 0 else 0.0)
		var ph := phase + lerpf(trot_off, gal_off, gallop)
		var swing := sin(ph) * amp
		var lift := maxf(0.0, cos(ph)) * amp
		var hip: Node3D = l.hip
		var knee: Node3D = l.knee
		hip.rotation.x = swing + _crouch * (0.6 if l.front else 0.9)
		var k := -lift * 1.1 - _crouch * 1.4
		if not l.front:
			k = -k * 0.8
		knee.rotation.x = k

	# Spine flex and bob at a gallop, lower body when crouched.
	torso.rotation.x = sin(phase * 2.0) * 0.07 * gallop
	var base_y: float = p.leg_len + p.body_r * 0.3
	torso.position.y = base_y - _crouch * p.leg_len * 0.38 + absf(sin(phase)) * 0.06 * amp
	var target_pitch: float = lerpf(p.neck_pitch, -1.9, head_down)
	target_pitch = lerpf(target_pitch, -1.25, gallop * 0.6) if head_down < 0.1 else target_pitch
	target_pitch -= _crouch * 0.3
	neck.rotation.x = lerpf(neck.rotation.x, target_pitch, 1.0 - exp(-6.0 * delta))
	head.rotation.x = -neck.rotation.x * (1.0 - head_down * 0.5)
	tail.rotation.x = 2.2 - gallop * 0.6 + sin(phase * 0.5) * 0.08
	tail.rotation.z = sin(phase * 0.7) * 0.25 * (1.0 - gallop * 0.5)


# --- mesh helpers -----------------------------------------------------------

func _mesh(m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 16
	c.rings = 6
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 7
	return s


func _cyl(top: float, bottom: float, h: float, seg := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c
