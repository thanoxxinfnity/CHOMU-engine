extends RefCounted
const Impl := preload("res://addons/chomu_systems/physics/bond_graph.gd")

func run(t: Node) -> void:
	var graph := Impl.new()
	t.add_child(graph)
	
	# Create 4 chunks: bottom (0) anchored, then 1, 2, 3
	var chunks: Array[RigidBody3D] = []
	for i in range(4):
		var body = RigidBody3D.new()
		body.mass = 1.0
		t.add_child(body)
		chunks.append(body)
	
	var idx0 = graph.add_chunk(chunks[0], true)   # anchored
	var idx1 = graph.add_chunk(chunks[1], false)
	var idx2 = graph.add_chunk(chunks[2], false)
	var idx3 = graph.add_chunk(chunks[3], false)
	
	t.check("F-56 chunks added", idx0 == 0 and idx1 == 1 and idx2 == 2 and idx3 == 3, "indices 0..3")
	
	# Non-anchored chunks start frozen
	t.check("F-56 chunk 1 frozen initially", chunks[1].freeze == true, "chunk 1 frozen")
	t.check("F-56 chunk 2 frozen initially", chunks[2].freeze == true, "chunk 2 frozen")
	t.check("F-56 chunk 3 frozen initially", chunks[3].freeze == true, "chunk 3 frozen")
	t.check("F-56 chunk 0 not frozen (anchored)", chunks[0].freeze == false, "anchored not frozen")
	
	# Add bonds: 0-1 (strong), 1-2 (weak), 2-3 (weak)
	graph.add_bond(0, 1, 100.0)  # strong
	graph.add_bond(1, 2, 10.0)   # weak
	graph.add_bond(2, 3, 10.0)   # weak
	
	t.check("F-56 bonds remaining 3", graph.bonds_remaining() == 3, "3 bonds")
	
	# Weak impact on top (chunk 3) - force 5, should not break bond 2-3 (strength 10)
	graph.apply_impact(3, 5.0)
	t.check("F-56 weak impact breaks nothing", graph.bonds_remaining() == 3, "bonds still 3")
	t.check("F-56 chunk 3 still frozen after weak hit", chunks[3].freeze == true, "chunk 3 frozen")
	t.check("F-56 chunk 2 still frozen after weak hit", chunks[2].freeze == true, "chunk 2 frozen")
	
	# Strong impact on top (chunk 3) - force 20, breaks bond 2-3 (strength 10)
	# Stress at 3: 20 > 10, bond 2-3 breaks
	# Stress at 2: 20*0.5=10, not > 10 (bond 1-2 strength 10), so 1-2 holds
	var released: Array[int] = []
	graph.chunk_released.connect(func(idx: int): released.append(idx))
	
	graph.apply_impact(3, 20.0)
	
	t.check("F-56 strong impact breaks 1 bond", graph.bonds_remaining() == 2, "bonds now 2")
	t.check("F-56 bond 2-3 broken", not graph.is_connected_to_anchor(3), "chunk 3 not connected to anchor")
	t.check("F-56 chunk 3 released", chunks[3].freeze == false, "chunk 3 unfrozen")
	t.check("F-56 chunk 2 still frozen (connected to anchor)", chunks[2].freeze == true, "chunk 2 frozen")
	t.check("F-56 chunk 1 still frozen", chunks[1].freeze == true, "chunk 1 frozen")
	t.check("F-56 chunk 0 still not frozen", chunks[0].freeze == false, "chunk 0 not frozen")
	t.check("F-56 released signal for chunk 3", released == [3], "released [3]")
	
	# Verify connectivity
	t.check("F-56 chunk 2 connected to anchor", graph.is_connected_to_anchor(2), "2 connected")
	t.check("F-56 chunk 1 connected to anchor", graph.is_connected_to_anchor(1), "1 connected")
	t.check("F-56 chunk 0 connected to anchor", graph.is_connected_to_anchor(0), "0 connected")
	t.check("F-56 chunk 3 NOT connected to anchor", not graph.is_connected_to_anchor(3), "3 not connected")
	
	# Anchored chunk never released
	t.check("F-56 anchored never released", chunks[0].freeze == false, "anchored stays unfrozen")
	
	# Cleanup
	for c in chunks:
		c.queue_free()
	graph.queue_free()
