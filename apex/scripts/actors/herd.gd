class_name Herd
extends RefCounted
## A group of prey sharing a grazing area. Panic and vigilance spread through it.

var center: Vector3
var members: Array[Prey] = []


func alive_members() -> Array[Prey]:
	var out: Array[Prey] = []
	for m in members:
		if is_instance_valid(m) and not m.is_dead:
			out.append(m)
	return out
