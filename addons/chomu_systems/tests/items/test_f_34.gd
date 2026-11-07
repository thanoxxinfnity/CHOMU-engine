extends RefCounted

const Transport := preload("res://addons/chomu_systems/net/transport.gd")

func run(t: Node) -> void:
	var pair = Transport.loopback_pair()
	var a = pair[0]
	var b = pair[1]
	
	# Test peers() returns correct IDs
	t.check("F-34 peers A", a.peers() == [2], "Transport A sees peer 2")
	t.check("F-34 peers B", b.peers() == [1], "Transport B sees peer 1")
	
	# Test round-trip A -> B
	var payload_a = PackedByteArray([0x01, 0x02, 0x03, 0x04])
	a.send(2, payload_a)
	await t.physics_frames(1)
	var msgs_b = b.poll()
	t.check("F-34 recv B count", msgs_b.size() == 1, "B received 1 message")
	t.check("F-34 recv B peer", msgs_b[0]["peer"] == 1, "B message from peer 1")
	t.check("F-34 recv B data", msgs_b[0]["data"] == payload_a, "B message data matches")
	
	# Test round-trip B -> A
	var payload_b = PackedByteArray([0x10, 0x20, 0x30, 0x40, 0x50])
	b.send(1, payload_b)
	await t.physics_frames(1)
	var msgs_a = a.poll()
	t.check("F-34 recv A count", msgs_a.size() == 1, "A received 1 message")
	t.check("F-34 recv A peer", msgs_a[0]["peer"] == 2, "A message from peer 2")
	t.check("F-34 recv A data", msgs_a[0]["data"] == payload_b, "A message data matches")
	
	# Test ordering: multiple sends arrive in order
	var seq = PackedByteArray()
	for i in range(10):
		seq.append(i)
	a.send(2, seq)
	a.send(2, PackedByteArray([0xFF, 0xEE]))
	a.send(2, PackedByteArray([0xDD]))
	await t.physics_frames(1)
	var ordered = b.poll()
	t.check("F-34 ordering count", ordered.size() == 3, "Three messages in order")
	t.check("F-34 ordering 0", ordered[0]["data"] == seq, "First message correct")
	t.check("F-34 ordering 1", ordered[1]["data"] == PackedByteArray([0xFF, 0xEE]), "Second message correct")
	t.check("F-34 ordering 2", ordered[2]["data"] == PackedByteArray([0xDD]), "Third message correct")
	
	# Test close stops delivery
	a.close()
	a.send(2, PackedByteArray([0x99]))
	await t.physics_frames(1)
	var after_close = b.poll()
	t.check("F-34 close stops delivery", after_close.size() == 0, "No messages after close")
	
	# Test peers() empty after close on both sides
	t.check("F-34 peers empty after close", a.peers().size() == 0, "Closed transport has no peers")
	t.check("F-34 other peers empty after close", b.peers().size() == 0, "Other transport also has no peers")
	
	# Cleanup (idempotent)
	b.close()
