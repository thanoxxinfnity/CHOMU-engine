extends RefCounted
class_name ChomuSquadFormationManager

## Squad Formation Manager (S-11)
## Maintains tactical military/monster formations during movement and combat.
## Data-driven, deterministic (seeded RNG), headless-safe, save/load via Dictionary.
## Mobile-first: NEON path, low RAM, no rendering dependency.

## FormationSlot: a single slot in a formation relative to the formation anchor.
class FormationSlot:
	var id: int = 0
	var offset: Vector3 = Vector3.ZERO
	var role: String = ""
	var occupied_by: String = ""  # agent id or ""

## FormationTemplate: named formation layout.
class FormationTemplate:
	var name: String = ""
	var slots: Array[FormationSlot] = []

## Member state
var _seed: int = 12345
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _anchor: Vector3 = Vector3.ZERO
var _forward: Vector3 = Vector3(0, 0, -1)
var _up: Vector3 = Vector3(0, 1, 0)
var _right: Vector3 = Vector3(1, 0, 0)
var _scale: float = 1.0
var _templates: Dictionary = {}  # name -> FormationTemplate
var _active_template: String = ""
var _assignments: Dictionary = {}  # agent_id -> slot id
var _slot_owners: Dictionary = {}  # slot id -> agent_id
var _next_slot_id: int = 1
var _next_agent_id: int = 1
var _auto_assign: bool = true
var _formation_changed: bool = false

## signal formation_changed (emitted when layout/assignments change)
signal formation_changed

## _init(seed:int=12345)
## Create manager with deterministic seed.
func _init(seed: int = 12345) -> void:
	_seed = seed
	_rng.seed = seed

## set_seed(seed:int) -> void
## Reseed the deterministic RNG.
func set_seed(seed: int) -> void:
	_seed = seed
	_rng.seed = seed

## get_seed() -> int
func get_seed() -> int:
	return _seed

## set_anchor(pos: Vector3) -> void
## Set the formation anchor (world position).
func set_anchor(pos: Vector3) -> void:
	_anchor = pos
	_formation_changed = true
	formation_changed.emit()

## get_anchor() -> Vector3
func get_anchor() -> Vector3:
	return _anchor

## set_orientation(forward: Vector3, up: Vector3 = Vector3(0, 1, 0)) -> void
## Set formation facing direction.
func set_orientation(forward: Vector3, up: Vector3 = Vector3(0, 1, 0)) -> void:
	_forward = forward.normalized()
	_up = up.normalized()
	_right = _forward.cross(_up).normalized()
	_up = _right.cross(_forward).normalized()
	_formation_changed = true
	formation_changed.emit()

## set_scale(s: float) -> void
## Uniform scale of all slot offsets.
func set_scale(s: float) -> void:
	_scale = clampf(s, 0.01, 100.0)
	_formation_changed = true
	formation_changed.emit()

## get_scale() -> float
func get_scale() -> float:
	return _scale

## register_template(name: String, slots: Array[Dictionary]) -> bool
## Register a named formation template. Each slot dict: {id, offset:Vector3, role:String}.
## Returns false if name already exists.
func register_template(name: String, slots: Array[Dictionary]) -> bool:
	if _templates.has(name):
		return false
	var t: FormationTemplate = FormationTemplate.new()
	t.slots = []
	for s in slots:
		var slot: FormationSlot = FormationSlot.new()
		slot.id = int(s.get("id", _next_slot_id))
		slot.offset = Vector3(s.get("offset", Vector3.ZERO))
		slot.role = String(s.get("role", ""))
		slot.occupied_by = ""
		t.slots.append(slot)
		if slot.id >= _next_slot_id:
			_next_slot_id = slot.id + 1
	_templates[name] = t
	return true

## get_template(name: String) -> FormationTemplate
## Returns template or null if missing.
func get_template(name: String) -> FormationTemplate:
	return _templates.get(name, null)

## set_active_template(name: String) -> bool
## Switch active formation layout. Clears assignments.
func set_active_template(name: String) -> bool:
	if not _templates.has(name):
		return false
	_active_template = name
	_assignments = {}
	_slot_owners = {}
	_formation_changed = true
	formation_changed.emit()
	return true

## get_active_template() -> String
func get_active_template() -> String:
	return _active_template

## set_auto_assign(enable: bool) -> void
## When true, add_agent auto-fills the nearest free slot.
func set_auto_assign(enable: bool) -> void:
	_auto_assign = enable

## get_auto_assign() -> bool
func get_auto_assign() -> bool:
	return _auto_assign

## add_agent(agent_id: String, preferred_role: String = "") -> int
## Register an agent and optionally assign to a slot. Returns slot id or -1.
func add_agent(agent_id: String, preferred_role: String = "") -> int:
	if _assignments.has(agent_id):
		return _assignments[agent_id]
	var slot_id: int = -1
	if _auto_assign and _active_template != "":
		slot_id = _find_free_slot(preferred_role)
	if slot_id != -1:
		_assign_agent_to_slot(agent_id, slot_id)
	return slot_id

## remove_agent(agent_id: String) -> bool
## Remove agent and free its slot.
func remove_agent(agent_id: String) -> bool:
	if not _assignments.has(agent_id):
		return false
	var slot_id: int = _assignments[agent_id]
	_assignments.erase(agent_id)
	if _slot_owners.has(slot_id):
		_slot_owners.erase(slot_id)
	var t: FormationTemplate = _templates.get(_active_template, null)
	if t != null:
		for s in t.slots:
			if s.id == slot_id:
				s.occupied_by = ""
				break
	_formation_changed = true
	formation_changed.emit()
	return true

## assign_agent(agent_id: String, slot_id: int) -> bool
## Manually assign agent to a specific slot (must be free).
func assign_agent(agent_id: String, slot_id: int) -> bool:
	if _assignments.has(agent_id):
		return false
	if _slot_owners.has(slot_id):
		return false
	if not _slot_exists(slot_id):
		return false
	return _assign_agent_to_slot(agent_id, slot_id)

## unassign_agent(agent_id: String) -> bool
## Free the agent's slot without removing the agent.
func unassign_agent(agent_id: String) -> bool:
	if not _assignments.has(agent_id):
		return false
	var slot_id: int = _assignments[agent_id]
	_assignments.erase(agent_id)
	if _slot_owners.has(slot_id):
		_slot_owners.erase(slot_id)
	var t: FormationTemplate = _templates.get(_active_template, null)
	if t != null:
		for s in t.slots:
			if s.id == slot_id:
				s.occupied_by = ""
				break
	_formation_changed = true
	formation_changed.emit()
	return true

## get_agent_slot(agent_id: String) -> int
## Returns slot id or -1.
func get_agent_slot(agent_id: String) -> int:
	return _assignments.get(agent_id, -1)

## get_slot_agent(slot_id: int) -> String
## Returns agent id or "".
func get_slot_agent(slot_id: int) -> String:
	return _slot_owners.get(slot_id, "")

## get_agent_world_pos(agent_id: String) -> Vector3
## Compute world position for an agent based on its slot.
func get_agent_world_pos(agent_id: String) -> Vector3:
	var slot_id: int = _assignments.get(agent_id, -1)
	if slot_id == -1:
		return _anchor
	return _compute_slot_world_pos(slot_id)

## get_all_agent_positions() -> Dictionary[agent_id, Vector3]
func get_all_agent_positions() -> Dictionary:
	var out: Dictionary = {}
	var keys: Array[Variant] = _assignments.keys()
	for i in range(keys.size()):
		var agent_id: String = String(keys[i])
		out[agent_id] = _compute_slot_world_pos(_assignments[agent_id])
	return out

## get_slot_world_pos(slot_id: int) -> Vector3
func get_slot_world_pos(slot_id: int) -> Vector3:
	return _compute_slot_world_pos(slot_id)

## step(delta: float) -> void
## Per-frame update placeholder (keeps formation_changed flag tidy).
func step(delta: float) -> void:
	pass

## save_state() -> Dictionary
## Serialize mutable state.
func save_state() -> Dictionary:
	var t: FormationTemplate = _templates.get(_active_template, null)
	var slots_data: Array[Dictionary] = []
	if t != null:
		for s in t.slots:
			slots_data.append({
				"id": s.id,
				"offset": s.offset,
				"role": s.role,
				"occupied_by": s.occupied_by,
			})
	var templates_data: Array[Dictionary] = []
	var t_keys: Array[Variant] = _templates.keys()
	for i in range(t_keys.size()):
		var name: Variant = t_keys[i]
		var tt: FormationTemplate = _templates[name]
		var ts: Array[Dictionary] = []
		for s in tt.slots:
			ts.append({"id": s.id, "offset": s.offset, "role": s.role})
		templates_data.append({"name": tt.name, "slots": ts})
	var assignments_copy: Dictionary = {}
	var a_keys: Array[Variant] = _assignments.keys()
	for i in range(a_keys.size()):
		var k: Variant = a_keys[i]
		assignments_copy[k] = _assignments[k]
	return {
		"seed": _seed,
		"anchor": _anchor,
		"forward": _forward,
		"up": _up,
		"scale": _scale,
		"active_template": _active_template,
		"auto_assign": _auto_assign,
		"assignments": assignments_copy,
		"templates": templates_data,
		"next_slot_id": _next_slot_id,
		"next_agent_id": _next_agent_id,
	}

## load_state(data: Dictionary) -> void
## Restore state from save_state() dictionary.
func load_state(data: Dictionary) -> void:
	_seed = int(data.get("seed", 12345))
	_rng.seed = _seed
	_anchor = Vector3(data.get("anchor", Vector3.ZERO))
	_forward = Vector3(data.get("forward", Vector3(0, 0, -1))).normalized()
	_up = Vector3(data.get("up", Vector3(0, 1, 0))).normalized()
	_right = _forward.cross(_up).normalized()
	_scale = float(data.get("scale", 1.0))
	_active_template = String(data.get("active_template", ""))
	_auto_assign = bool(data.get("auto_assign", true))
	_assignments = {}
	var raw_assign: Dictionary = data.get("assignments", {})
	var a_keys: Array[Variant] = raw_assign.keys()
	for i in range(a_keys.size()):
		var k: Variant = a_keys[i]
		_assignments[String(k)] = int(raw_assign[k])
	_slot_owners = {}
	var assign_keys: Array[Variant] = _assignments.keys()
	for i in range(assign_keys.size()):
		var agent_id: String = String(assign_keys[i])
		var slot_id: int = _assignments[agent_id]
		_slot_owners[slot_id] = agent_id
	_next_slot_id = int(data.get("next_slot_id", 1))
	_next_agent_id = int(data.get("next_agent_id", 1))
	_templates = {}
	var raw_templates: Array = data.get("templates", [])
	for i in range(raw_templates.size()):
		var td: Dictionary = raw_templates[i]
		var t: FormationTemplate = FormationTemplate.new()
		t.name = String(td.get("name", ""))
		t.slots = []
		var raw_slots: Array = td.get("slots", [])
		for j in range(raw_slots.size()):
			var sd: Dictionary = raw_slots[j]
			var s: FormationSlot = FormationSlot.new()
			s.id = int(sd.get("id", 0))
			s.offset = Vector3(sd.get("offset", Vector3.ZERO))
			s.role = String(sd.get("role", ""))
			s.occupied_by = ""
			t.slots.append(s)
		_templates[t.name] = t
	# restore occupants from assignments
	var assign_keys2: Array[Variant] = _assignments.keys()
	for i in range(assign_keys2.size()):
		var agent_id: String = String(assign_keys2[i])
		var slot_id: int = _assignments[agent_id]
		var t: FormationTemplate = _templates.get(_active_template, null)
		if t != null:
			for s in t.slots:
				if s.id == slot_id:
					s.occupied_by = agent_id
					break
	_formation_changed = true
	formation_changed.emit()

## ---------------- private ----------------

func _slot_exists(slot_id: int) -> bool:
	var t: FormationTemplate = _templates.get(_active_template, null)
	if t == null:
		return false
	for s in t.slots:
		if s.id == slot_id:
			return true
	return false

func _slot_offset(slot_id: int) -> Vector3:
	var t: FormationTemplate = _templates.get(_active_template, null)
	if t == null:
		return Vector3.ZERO
	for s in t.slots:
		if s.id == slot_id:
			return s.offset * _scale
	return Vector3.ZERO

func _compute_slot_world_pos(slot_id: int) -> Vector3:
	var offset: Vector3 = _slot_offset(slot_id)
	return _anchor + _right * offset.x + _up * offset.y - _forward * offset.z

func _find_free_slot(preferred_role: String) -> int:
	var t: FormationTemplate = _templates.get(_active_template, null)
	if t == null:
		return -1
	var best_id: int = -1
	var best_dist: float = 1e9
	for s in t.slots:
		if _slot_owners.has(s.id):
			continue
		if preferred_role != "" and s.role != preferred_role:
			continue
		var d: float = s.offset.length_squared()
		if d < best_dist:
			best_dist = d
			best_id = s.id
	if best_id != -1:
		return best_id
	# fallback: any free slot
	for s in t.slots:
		if not _slot_owners.has(s.id):
			return s.id
	return -1

func _assign_agent_to_slot(agent_id: String, slot_id: int) -> bool:
	_assignments[agent_id] = slot_id
	_slot_owners[slot_id] = agent_id
	var t: FormationTemplate = _templates.get(_active_template, null)
	if t != null:
		for s in t.slots:
			if s.id == slot_id:
				s.occupied_by = agent_id
				break
	_formation_changed = true
	formation_changed.emit()
	return true
