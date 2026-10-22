class_name Herd
extends RefCounted
## A group of prey sharing a grazing area. Panic and vigilance spread through it.

var center: Vector3
var members: Array[Gazelle] = []


func alive_members() -> Array[Gazelle]:
	var out: Array[Gazelle] = []
	for m in members:
		if is_instance_valid(m) and not m.is_dead:
			out.append(m)
	return out
