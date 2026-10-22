class_name Herd
extends RefCounted
## A group of prey sharing a grazing area. Panic and vigilance spread through it.

var center: Vector3
var members: Array[Prey] = []
var wariness := 0.0          # goes up each time the herd is attacked
var _last_attack_ms := -100000


## Called when a member bolts. One stampede counts once.
func attacked() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_attack_ms > 8000:
		wariness += 1.0
	_last_attack_ms = now


## Sight multiplier from wariness: burned herds watch harder.
func vigilance() -> float:
	return 1.0 + Tuning.HERD_WARINESS * wariness


func alive_members() -> Array[Prey]:
	var out: Array[Prey] = []
	for m in members:
		if is_instance_valid(m) and not m.is_dead:
			out.append(m)
	return out
