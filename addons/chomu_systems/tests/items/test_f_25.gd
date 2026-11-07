extends RefCounted
const Impl := preload("res://addons/chomu_systems/tools/embedding_search.gd")

func run(t: Node) -> void:
	var search := Impl.new()
	
	# F-25.1: Basic embedding generation
	var emb1 := Impl.embed("test")
	t.check("F-25.1 embedding has correct dimension", emb1.size() == 256, "Expected 256 dimensions, got %d" % emb1.size())
	
	# F-25.2: Embeddings are L2 normalized
	var mag := 0.0
	for i in range(emb1.size()):
		mag += emb1[i] * emb1[i]
	t.check("F-25.2 embedding is L2 normalized", abs(sqrt(mag) - 1.0) < 0.001, "Magnitude: %f" % sqrt(mag))
	
	# F-25.3: Same text produces same embedding
	var emb2 := Impl.embed("basement flickering light")
	var emb3 := Impl.embed("basement flickering light")
	var same := true
	for i in range(emb2.size()):
		if emb2[i] != emb3[i]:
			same = false
			break
	t.check("F-25.3 deterministic embedding", same, "Same text should produce identical embeddings")
	
	# F-25.4: Different text produces different embedding
	var emb4 := Impl.embed("kitchen lamp")
	var diff := false
	for i in range(emb2.size()):
		if emb2[i] != emb4[i]:
			diff = true
			break
	t.check("F-25.4 different text different embedding", diff, "Different text should produce different embeddings")
	
	# F-25.5: Add items to index
	search.add(1, "basement flickering light")
	search.add(2, "kitchen lamp")
	search.add(3, "attic door")
	t.check("F-25.5 items added to index", search._nodes.size() == 3, "Expected 3 nodes, got %d" % search._nodes.size())
	
	# F-25.6: Search returns results
	var results := search.search("flickering lights in the basement", 5)
	t.check("F-25.6 search returns results", results.size() > 0, "Expected non-empty results")
	
	# F-25.7: Search returns dictionaries with id and score
	if results.size() > 0:
		t.check("F-25.7 result has id and score", results[0].has("id") and results[0].has("score"), "Result keys: %s" % str(results[0].keys()))
	
	# F-25.8: Basement flickering light ranks highest for basement query
	var basement_results := search.search("basement flickering light", 3)
	t.check("F-25.8 basement light ranks highest", basement_results[0].id == 1, "Top result id: %s, expected 1" % str(basement_results[0].id))
	
	# F-25.9: Brute force agrees with HNSW on top-1 for random queries
	var test_queries := [
		"flickering",
		"lamp",
		"door",
		"basement",
		"kitchen",
		"attic",
		"light",
		"flickering lamp",
		"basement door",
		"attic light"
	]
	
	var agreement_count := 0
	for query in test_queries:
		var hnsw_top := search.search(query, 1)
		var bf_top := search.brute_force(query, 1)
		if hnsw_top.size() > 0 and bf_top.size() > 0:
			if hnsw_top[0].id == bf_top[0].id:
				agreement_count += 1
	
	t.check("F-25.9 HNSW agrees with brute_force on top-1", agreement_count >= 8, "Agreed on %d/10 queries" % agreement_count)
	
	# F-25.10: Cosine scores are in valid range
	var all_results := search.search("light", 5)
	var valid_scores := true
	for r in all_results:
		if r.score < -1.0 or r.score > 1.0:
			valid_scores = false
	t.check("F-25.10 cosine scores in valid range", valid_scores, "Scores should be in [-1, 1]")
	
	# F-25.11: Results are sorted by score descending
	var sorted := true
	for i in range(all_results.size() - 1):
		if all_results[i].score < all_results[i + 1].score:
			sorted = false
	t.check("F-25.11 results sorted by score", sorted, "Results should be sorted by cosine similarity descending")
	
	# F-25.12: index_scene works with Node tree
	var root := Node.new()
	root.name = "Basement"
	root.add_to_group("interior")
	root.set_meta("description", "Dark basement with flickering light")
	
	var child1 := Node.new()
	child1.name = "Light"
	child1.add_to_group("light")
	root.add_child(child1)
	
	var child2 := Node.new()
	child2.name = "Door"
	child2.add_to_group("exit")
	root.add_child(child2)
	
	search.index_scene(root)
	t.check("F-25.12 scene indexing adds nodes", search._nodes.size() >= 5, "Expected at least 5 nodes after scene indexing, got %d" % search._nodes.size())
	
	root.queue_free()
	child1.queue_free()
	child2.queue_free()
	
	# F-25.13: Kitchen lamp ranks highest for kitchen query
	var kitchen_results := search.search("kitchen lamp", 3)
	t.check("F-25.13 kitchen lamp ranks highest", kitchen_results[0].id == 2, "Top result id: %s, expected 2" % str(kitchen_results[0].id))
