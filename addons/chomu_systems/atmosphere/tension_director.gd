class_name ChomuTensionDirector
extends Node
## F-44 Tension director. tension in [0,1] from weighted threat proximity,
## line of sight, darkness, recent damage and time since the last scare,
## driven through a hysteretic BUILD_UP -> PEAK -> RELAX machine.

signal state_changed(new_state: int, old_state: int)
## Emitted (at most once per min_scare_interval) when a scare would land well.
signal scare_window_opened(tension: float)

enum State { BUILD_UP, PEAK, RELAX }
const STATE_NAMES := ["Build-up", "Peak", "Relax"]

@export var player: Node3D
## Threats are taken from this group when `threats` is empty.
@export var threat_group := &"chomu_threat"
@export var threats: Array[Node3D] = []
@export var threat_radius := 18.0
@export_group("Weights")
@export var w_proximity := 0.4
@export var w_los := 0.25
@export var w_darkness := 0.15
@export var w_damage := 0.1
@export var w_time := 0.1
@export_group("Timing")
@export var attack := 1.5     ## rise speed (1/s)
@export var release := 0.35   ## fall speed (1/s)
@export var time_ramp := 60.0 ## seconds without a scare to reach full time pressure
@export var peak_enter := 0.75
@export var peak_hold := 0.5
@export var peak_min := 3.0
@export var peak_max := 12.0
@export var peak_exit := 0.55
@export var relax_min := 6.0
@export var relax_exit := 0.3
@export var min_scare_interval := 20.0
@export_group("Darkness")
## When true the director samples ChomuLightProbe at the player.
@export var auto_darkness := true
@export var bright_luminance := 0.6

var tension := 0.0
var raw_tension := 0.0
var state: int = State.BUILD_UP
var darkness := 0.0
var time_since_scare := 0.0
var damage_level := 0.0
var factors := {}
var _state_time := 0.0
var _above_time := 0.0
var _last_window := -1000.0
var _clock := 0.0
## Optional override; when >= 0 it replaces the computed darkness.
var darkness_override := -1.0

func register_scare() -> void:
	time_since_scare = 0.0

func register_damage(amount: float) -> void:
	damage_level = clampf(damage_level + amount, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	step(delta)

## Advances the director by `delta` (callable manually for tests).
func step(delta: float) -> void:
	_clock += delta
	time_since_scare += delta
	damage_level = maxf(0.0, damage_level - delta * 0.1)
	var prox := 0.0
	var los := 0.0
	if player and is_instance_valid(player):
		var list: Array = threats if not threats.is_empty() else (get_tree().get_nodes_in_group(threat_group) if is_inside_tree() else [])
		var space: PhysicsDirectSpaceState3D = null
		if player.is_inside_tree():
			space = player.get_world_3d().direct_space_state
		for t in list:
			var th := t as Node3D
			if th == null or not is_instance_valid(th):
				continue
			var d := player.global_position.distance_to(th.global_position)
			var p := 1.0 - clampf(d / threat_radius, 0.0, 1.0)
			prox = maxf(prox, p * p * (3.0 - 2.0 * p))
			if d < threat_radius and _has_los(space, player, th):
				los = maxf(los, 1.0 - d / threat_radius * 0.5)
		if darkness_override >= 0.0:
			darkness = darkness_override
		elif auto_darkness and player.is_inside_tree():
			var lum := ChomuLightProbe.estimate(get_tree(), player.global_position + Vector3.UP * 1.5, null)
			darkness = 1.0 - clampf(lum / bright_luminance, 0.0, 1.0)
	elif darkness_override >= 0.0:
		darkness = darkness_override
	var tp := clampf(time_since_scare / time_ramp, 0.0, 1.0)
	factors = {"proximity": prox, "los": los, "darkness": darkness, "damage": damage_level, "time": tp}
	raw_tension = clampf(w_proximity * prox + w_los * los + w_darkness * darkness + w_damage * damage_level + w_time * tp, 0.0, 1.0)
	if state == State.RELAX:
		raw_tension *= 0.6 # the director actively damps during relax
	var rate := attack if raw_tension > tension else release
	tension = move_toward(tension, raw_tension, rate * delta)
	_update_state(delta)

func _has_los(space: PhysicsDirectSpaceState3D, a: Node3D, b: Node3D) -> bool:
	if space == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(a.global_position + Vector3.UP * 1.5, b.global_position + Vector3.UP * 1.2)
	var ex: Array[RID] = []
	if a is CollisionObject3D:
		ex.append((a as CollisionObject3D).get_rid())
	if b is CollisionObject3D:
		ex.append((b as CollisionObject3D).get_rid())
	q.exclude = ex
	return space.intersect_ray(q).is_empty()

func _update_state(delta: float) -> void:
	_state_time += delta
	match state:
		State.BUILD_UP:
			_above_time = _above_time + delta if tension >= peak_enter else 0.0
			if _above_time >= peak_hold:
				_set_state(State.PEAK)
			elif tension > 0.5 and time_since_scare > min_scare_interval and _clock - _last_window > min_scare_interval:
				_last_window = _clock
				scare_window_opened.emit(tension)
		State.PEAK:
			if (_state_time >= peak_min and tension < peak_exit) or _state_time >= peak_max:
				_set_state(State.RELAX)
		State.RELAX:
			if _state_time >= relax_min and tension <= relax_exit:
				_set_state(State.BUILD_UP)

func _set_state(s: int) -> void:
	var old := state
	state = s
	_state_time = 0.0
	_above_time = 0.0
	if s == State.RELAX:
		register_scare()
	state_changed.emit(s, old)

func state_name() -> String:
	return STATE_NAMES[state]
