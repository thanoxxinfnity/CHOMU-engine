@tool
extends RefCounted
## Scene helpers shared by all studio tools: finding the character parts and undoable edits.

static func root() -> Node:
	return EditorInterface.get_edited_scene_root()

static func selected() -> Array:
	return EditorInterface.get_selection().get_selected_nodes()

static func first_selected(type_name: String) -> Node:
	for n in selected():
		if n.is_class(type_name):
			return n
	return null

static func find_child_of_type(n: Node, type_name: String) -> Node:
	if n == null:
		return null
	if n.is_class(type_name):
		return n
	for c in n.get_children():
		var r = find_child_of_type(c, type_name)
		if r:
			return r
	return null

static func find_all_of_type(n: Node, type_name: String, out: Array = []) -> Array:
	if n == null:
		return out
	if n.is_class(type_name):
		out.append(n)
	for c in n.get_children():
		find_all_of_type(c, type_name, out)
	return out

## The "character": the top-level node under the scene root that contains `n`.
static func character_of(n: Node) -> Node:
	var r = root()
	if n == null or r == null:
		return r
	if n == r:
		return r
	var cur = n
	while cur.get_parent() and cur.get_parent() != r:
		cur = cur.get_parent()
	return cur

## Skeleton for a node: the node itself, a MeshInstance3D's skeleton path, a descendant, or one in the same character.
static func find_skeleton(n: Node) -> Skeleton3D:
	if n == null:
		n = root()
	if n == null:
		return null
	if n is Skeleton3D:
		return n
	if n is MeshInstance3D and not (n as MeshInstance3D).skeleton.is_empty():
		var s = n.get_node_or_null((n as MeshInstance3D).skeleton)
		if s is Skeleton3D:
			return s
	var p = n
	while p:
		if p is Skeleton3D:
			return p
		p = p.get_parent()
	var r = find_child_of_type(n, "Skeleton3D")
	if r:
		return r
	return find_child_of_type(character_of(n), "Skeleton3D")

static func find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	return find_child_of_type(n, "MeshInstance3D")

static func find_anim_player(n: Node) -> AnimationPlayer:
	var ch = character_of(n)
	return find_child_of_type(ch, "AnimationPlayer")

static func _set_owner_recursive(n: Node, owner: Node) -> Array:
	var list = [n]
	for c in n.get_children():
		# children that belong to an instanced scene keep their own owner
		if c.owner == null or c.owner == n or c.owner == owner:
			list.append_array(_set_owner_recursive(c, owner))
	return list

## Adds `node` (and its fresh children) under `parent` as one undoable action.
static func add_node(ur: EditorUndoRedoManager, action: String, parent: Node, node: Node, select := false) -> Node:
	var r = root()
	var owned = _set_owner_recursive(node, r)
	ur.create_action(action, UndoRedo.MERGE_DISABLE, r)
	ur.add_do_method(parent, "add_child", node, true)
	for o in owned:
		ur.add_do_method(o, "set_owner", r)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()
	if select:
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(node)
	return node

static func set_prop(ur: EditorUndoRedoManager, action: String, obj: Object, prop: String, value: Variant) -> void:
	ur.create_action(action, UndoRedo.MERGE_DISABLE, obj)
	ur.add_do_property(obj, prop, value)
	ur.add_undo_property(obj, prop, obj.get(prop))
	ur.commit_action()

static func unique_name(parent: Node, base: String) -> String:
	if parent == null or not parent.has_node(NodePath(base)):
		return base
	var i = 2
	while parent.has_node(NodePath("%s%d" % [base, i])):
		i += 1
	return "%s%d" % [base, i]

static func ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
