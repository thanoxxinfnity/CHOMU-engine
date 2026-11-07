extends RefCounted
class_name ChomuTransport

## Virtual API -----------------------------------------------------------------

func send(peer_id: int, data: PackedByteArray, reliable: bool = true) -> void:
	"""Send data to a peer. Override in subclass."""
	push_error("ChomuTransport.send() not implemented")
	
func poll() -> Array[Dictionary]:
	"""Poll for incoming messages. Returns array of {peer: int, data: PackedByteArray}. Override in subclass."""
	push_error("ChomuTransport.poll() not implemented")
	return []
	
func peers() -> Array[int]:
	"""Return list of connected peer IDs. Override in subclass."""
	push_error("ChomuTransport.peers() not implemented")
	return []
	
func close() -> void:
	"""Close the transport. Override in subclass."""
	push_error("ChomuTransport.close() not implemented")


## LoopbackTransport -----------------------------------------------------------

class LoopbackTransport extends ChomuTransport:
	var _peer_id: int
	var _other: LoopbackTransport
	var _inbox: Array[Dictionary] = []
	var _closed: bool = false
	var _peer_ids: Array[int]
	
	func _init(my_id: int, other: LoopbackTransport, peer_ids: Array[int]) -> void:
		_peer_id = my_id
		_other = other
		_peer_ids = peer_ids
	
	func send(peer_id: int, data: PackedByteArray, reliable: bool = true) -> void:
		if _closed:
			return
		if peer_id != _other._peer_id:
			push_error("LoopbackTransport: unknown peer %d" % peer_id)
			return
		# Queue directly into other's inbox
		_other._inbox.append({"peer": _peer_id, "data": data.duplicate()})
	
	func poll() -> Array[Dictionary]:
		if _closed:
			return []
		var msgs = _inbox.duplicate()
		_inbox.clear()
		return msgs
	
	func peers() -> Array[int]:
		if _closed:
			return []
		return _peer_ids.duplicate()
	
	func close() -> void:
		if _closed:
			return
		_closed = true
		_inbox.clear()
		# Notify the other side that this connection is closed
		if _other:
			_other._notify_peer_closed()
		_other = null
	
	func _notify_peer_closed() -> void:
		"""Called by the other transport when it closes."""
		_closed = true
		_inbox.clear()
		_other = null


## Static factories ------------------------------------------------------------

static func loopback_pair() -> Array[LoopbackTransport]:
	"""Create a pair of connected in-process transports with peer IDs 1 and 2."""
	var t1 = LoopbackTransport.new(1, null, [2])
	var t2 = LoopbackTransport.new(2, null, [1])
	t1._other = t2
	t2._other = t1
	return [t1, t2]

static func enet_server(port: int) -> ChomuTransport:
	"""Create an ENet server transport wrapper. (Stub - requires ENetConnection implementation)"""
	push_error("enet_server not implemented - requires ENetConnection")
	return ChomuTransport.new()

static func enet_client(host: String, port: int) -> ChomuTransport:
	"""Create an ENet client transport wrapper. (Stub - requires ENetConnection implementation)"""
	push_error("enet_client not implemented - requires ENetConnection")
	return ChomuTransport.new()
