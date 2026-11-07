extends RefCounted
class_name ChomuEmbeddingSearch

const DIM := 256
const M := 8
const EF := 32

class NodeRecord:
	var id: Variant
	var vector: PackedFloat32Array
	var neighbors: Array[int] = []
	
	func _init(p_id: Variant, p_vector: PackedFloat32Array) -> void:
		id = p_id
		vector = p_vector

var _nodes: Array[NodeRecord] = []
var _entry_point: int = -1

static func embed(text: String) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(DIM)
	
	var words := text.to_lower().split(" ", true)
	var trigrams := _extract_trigrams(text.to_lower())
	
	var word_hash := 0.0
	for i in range(words.size()):
		word_hash = fmod(word_hash + words[i].hash() * 0.001, 1.0)
	
	var trigram_hash := 0.0
	for trigram in trigrams:
		trigram_hash = fmod(trigram_hash + trigram.hash() * 0.0001, 1.0)
	
	for i in range(DIM):
		var val := fmod(sin(float(i) * 12.9898 + word_hash * 78.233 + trigram_hash * 37.719) * 43758.5453, 1.0)
		result[i] = val
	
	_normalize(result)
	return result

static func _extract_trigrams(text: String) -> Array[String]:
	var trigrams: Array[String] = []
	if text.length() < 3:
		return trigrams
	
	for i in range(text.length() - 2):
		trigrams.append(text.substr(i, 3))
	return trigrams

static func _normalize(v: PackedFloat32Array) -> void:
	var mag := 0.0
	for i in range(v.size()):
		mag += v[i] * v[i]
	mag = sqrt(mag)
	if mag > 0.0001:
		for i in range(v.size()):
			v[i] = v[i] / mag

static func _l2_distance(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var sum := 0.0
	for i in range(a.size()):
		var diff := a[i] - b[i]
		sum += diff * diff
	return sqrt(sum)

static func _cosine_similarity(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var dot := 0.0
	for i in range(a.size()):
		dot += a[i] * b[i]
	return dot

func add(id: Variant, text: String) -> void:
	var vector := embed(text)
	var record := NodeRecord.new(id, vector)
	
	if _nodes.size() == 0:
		_entry_point = 0
		_nodes.append(record)
		return
	
	var neighbors := _find_nearest(vector, M * 2)
	
	for neighbor_idx in neighbors:
		var neighbor := _nodes[neighbor_idx]
		neighbor.neighbors.append(_nodes.size())
		record.neighbors.append(neighbor_idx)
	
	_nodes.append(record)

func _find_nearest(query: PackedFloat32Array, count: int) -> Array[int]:
	if _nodes.size() == 0:
		return []
	
	var candidates: Array[int] = []
	var distances: Array[float] = []
	
	for i in range(_nodes.size()):
		var d := _l2_distance(query, _nodes[i].vector)
		candidates.append(i)
		distances.append(d)
	
	candidates.sort_custom(func(a, b): return distances[a] < distances[b])
	
	return candidates.slice(0, min(count, candidates.size()))

func search(query: String, k: int = 5) -> Array[Dictionary]:
	if _nodes.size() == 0:
		return []
	
	var query_vec := embed(query)
	
	var visited := {}
	var best: Array[Dictionary] = []
	
	for i in range(k):
		best.append({ "id": null, "score": -1.0 })
	
	var candidates: Array[Dictionary] = []
	candidates.append({ "idx": _entry_point, "dist": _l2_distance(query_vec, _nodes[_entry_point].vector) })
	
	while candidates.size() > 0:
		candidates.sort_custom(func(a, b): return a.dist < b.dist)
		var current := candidates.pop_front()
		
		if visited.has(current.idx):
			continue
		visited[current.idx] = true
		
		var score := _cosine_similarity(query_vec, _nodes[current.idx].vector)
		
		for i in range(k):
			if score > best[i].score:
				best[i] = { "id": _nodes[current.idx].id, "score": score }
				break
		
		for neighbor_idx in _nodes[current.idx].neighbors:
			if not visited.has(neighbor_idx):
				var neighbor_dist := _l2_distance(query_vec, _nodes[neighbor_idx].vector)
				if neighbor_dist < current.dist * 1.5:
					candidates.append({ "idx": neighbor_idx, "dist": neighbor_dist })
	
	best.sort_custom(func(a, b): return a.score > b.score)
	return best

func brute_force(query: String, k: int = 5) -> Array[Dictionary]:
	if _nodes.size() == 0:
		return []
	
	var query_vec := embed(query)
	var results: Array[Dictionary] = []
	
	for node in _nodes:
		var score := _cosine_similarity(query_vec, node.vector)
		results.append({ "id": node.id, "score": score })
	
	results.sort_custom(func(a, b): return a.score > b.score)
	return results.slice(0, k)

func index_scene(root: Node) -> void:
	_add_nodes_from_scene(root)

func _add_nodes_from_scene(node: Node) -> void:
	if node == null:
		return
	
	var text_parts: Array[String] = []
	
	if node.name != "":
		text_parts.append(node.name.to_lower())
	
	if node.get_class() != "Node":
		text_parts.append(node.get_class().to_lower())
	
	for group in node.get_groups():
		text_parts.append(group)
	
	if node.has_meta("description"):
		text_parts.append(str(node.get_meta("description")).to_lower())
	
	var combined_text := " ".join(text_parts)
	if combined_text != "":
		add(node.get_instance_id(), combined_text)
	
	for child in node.get_children():
		_add_nodes_from_scene(child)
