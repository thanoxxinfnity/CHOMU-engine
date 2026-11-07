extends RefCounted
class_name ChomuGenerationalHandles

## Generational handles system for stable entity references in an ECS.
## A handle is a packed 64-bit integer: [generation:32][index:32].
## When a slot is recycled, its generation increments so stale handles
## become invalid. Deterministic when seeded via `seed`.
##
## Public API:
##   alloc_handle() -> int
##   free_handle(handle: int) -> bool
##   is_valid(handle: int) -> bool
##   get_value(handle: int) -> Variant
##   set_value(handle: int, value: Variant) -> bool
##   count() -> int
##   capacity() -> int
##   seed(s: int) -> void
##   save_state() -> Dictionary
##   load_state(state: Dictionary) -> bool

const INDEX_MASK: int = 0xFFFFFFFF
const INDEX_SHIFT: int = 32

var _slots: Array[Variant] = []
var _generations: Array[int] = []
var _free_list: Array[int] = []
var _count: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 0

func _init(seed: int = 0) -> void:
	_seed = seed
	_rng.seed = _seed

## Allocate a new slot and return its handle.
## Reuses a freed slot if available, otherwise appends.
func alloc_handle() -> int:
	var idx: int
	if _free_list.size() > 0:
		idx = _free_list.pop_back()
	else:
		idx = _slots.size()
		_slots.append(null)
		_generations.append(0)
	_slots[idx] = null
	_count += 1
	return (_generations[idx] << INDEX_SHIFT) | (idx & INDEX_MASK)

## Free the slot referenced by `handle`. Returns false if invalid.
func free_handle(handle: int) -> bool:
	var idx: int = handle & INDEX_MASK
	if idx >= _slots.size() or not _is_valid_index(idx, handle):
		return false
	_slots[idx] = null
	_generations[idx] += 1
	_free_list.append(idx)
	_count -= 1
	return true

## Returns true if `handle` refers to a live slot.
func is_valid(handle: int) -> bool:
	var idx: int = handle & INDEX_MASK
	return _is_valid_index(idx, handle)

## Get the value stored at `handle`. Returns null if invalid.
func get_value(handle: int) -> Variant:
	var idx: int = handle & INDEX_MASK
	if not _is_valid_index(idx, handle):
		return null
	return _slots[idx]

## Set the value at `handle`. Returns false if invalid.
func set_value(handle: int, value: Variant) -> bool:
	var idx: int = handle & INDEX_MASK
	if not _is_valid_index(idx, handle):
		return false
	_slots[idx] = value
	return true

## Number of live allocated slots.
func count() -> int:
	return _count

## Total capacity (slots ever allocated, including freed).
func capacity() -> int:
	return _slots.size()

## Seed the deterministic RNG (used by any future randomized ops).
func seed(s: int) -> void:
	_seed = s
	_rng.seed = _seed

## Export full state as a Dictionary for save/load.
func save_state() -> Dictionary:
	var slots: Array[Variant] = []
	for s in _slots:
		slots.append(s)
	var gens: Array[int] = []
	for g in _generations:
		gens.append(g)
	var free: Array[int] = []
	for f in _free_list:
		free.append(f)
	return {
		"slots": slots,
		"generations": gens,
		"free_list": free,
		"count": _count,
		"seed": _seed,
	}

## Load state from a Dictionary produced by save_state().
## Returns false on malformed input.
func load_state(state: Dictionary) -> bool:
	if not state.has("slots") or not state.has("generations"):
		return false
	var slots: Array = state["slots"]
	var gens: Array = state["generations"]
	if slots.size() != gens.size():
		return false
	_slots = slots.duplicate()
	_generations = gens.duplicate()
	_free_list = []
	if state.has("free_list"):
		var fl: Array = state["free_list"]
		for f in fl:
			_free_list.append(f)
	_count = state.get("count", 0)
	if state.has("seed"):
		_seed = state["seed"]
		_rng.seed = _seed
	return true

func _is_valid_index(idx: int, handle: int) -> bool:
	if idx < 0 or idx >= _slots.size():
		return false
	var gen: int = handle >> INDEX_SHIFT
	return _generations[idx] == gen
