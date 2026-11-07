extends RefCounted
const Impl := preload("res://addons/chomu_systems/sheet/procedural_camera_shake.gd")

func run(t: Node) -> void:
	var shake: ChomuProceduralCameraShake = Impl.new()

	# F-S-23-1: register and trigger a named template produces offset
	var cfg: Impl.ShakeConfig = Impl.ShakeConfig.new()
	cfg.amplitude = 2.0
	cfg.frequency = 10.0
	cfg.decay = 2.0
	cfg.duration = 0.5
	cfg.seed = 42
	shake.register_template("explosion", cfg)
	shake.trigger("explosion")
	var offset: Vector3 = shake.update(0.016)
	t.check("F-S-23-1 trigger produces non-zero offset", offset.length() > 0.0, "offset=%s" % str(offset))

	# F-S-23-2: explicit shake works
	shake.clear()
	shake.shake(1.0, 5.0, 1.0, 0.2, 7)
	offset = shake.update(0.016)
	t.check("F-S-23-2 explicit shake offset", offset.length() > 0.0, "offset=%s" % str(offset))

	# F-S-23-3: offset decays toward zero over duration
	shake.clear()
	shake.shake(5.0, 10.0, 2.0, 1.0, 99)
	var max_len: float = 0.0
	var end_len: float = 0.0
	var steps: int = 0
	while steps < 100:
		offset = shake.update(0.01)
		var l: float = offset.length()
		if l > max_len:
			max_len = l
		end_len = l
		steps += 1
	t.check("F-S-23-3 decay reduces offset", max_len > 0.0 and end_len < max_len * 0.5, "max=%s end=%s" % [str(max_len), str(end_len)])

	# F-S-23-4: shake finishes and clears itself
	shake.clear()
	shake.shake(1.0, 10.0, 2.0, 0.05, 5)
	var active_frames: int = 0
	while true:
		offset = shake.update(0.01)
		if offset.length() > 0.0:
			active_frames += 1
		else:
			break
		if active_frames > 1000:
			break
	t.check("F-S-23-4 shake expires", active_frames > 0 and offset.length() == 0.0, "active_frames=%s" % str(active_frames))

	# F-S-23-5: multiple shakes stack
	shake.clear()
	shake.shake(1.0, 10.0, 1.0, 1.0, 1)
	shake.shake(1.0, 10.0, 1.0, 1.0, 2)
	offset = shake.update(0.016)
	t.check("F-S-23-5 multiple shakes stack", offset.length() > 0.0, "offset=%s" % str(offset))

	# F-S-23-6: clear removes all
	shake.clear()
	offset = shake.update(0.016)
	t.check("F-S-23-6 clear yields zero offset", offset == Vector3.ZERO, "offset=%s" % str(offset))

	# F-S-23-7: deterministic seed produces identical offsets
	var a: ChomuProceduralCameraShake = Impl.new()
	var b: ChomuProceduralCameraShake = Impl.new()
	a.shake(2.0, 10.0, 1.0, 1.0, 123)
	b.shake(2.0, 10.0, 1.0, 1.0, 123)
	var same_seed_ok: bool = true
	for i in range(10):
		if a.update(0.016) != b.update(0.016):
			same_seed_ok = false
			break
	t.check("F-S-23-7 same seed deterministic", same_seed_ok, "")

	# F-S-23-8: different seeds differ
	var c: ChomuProceduralCameraShake = Impl.new()
	var d: ChomuProceduralCameraShake = Impl.new()
	c.shake(2.0, 10.0, 1.0, 1.0, 1)
	d.shake(2.0, 10.0, 1.0, 1.0, 2)
	var seeds_differ: bool = false
	for i in range(10):
		if c.update(0.016) != d.update(0.016):
			seeds_differ = true
			break
	t.check("F-S-23-8 different seeds differ", seeds_differ, "")

	# F-S-23-9: save/load preserves state
	shake.clear()
	shake.shake(3.0, 10.0, 2.0, 1.0, 55)
	shake.update(0.1)
	var saved: Dictionary = shake.save_state()
	var restored: ChomuProceduralCameraShake = Impl.new()
	restored.load_state(saved)
	var state_ok: bool = true
	for i in range(5):
		if shake.update(0.016) != restored.update(0.016):
			state_ok = false
			break
	t.check("F-S-23-9 save/load restores state", state_ok, "")

	# F-S-23-10: apply_to moves a Node3D
	var target: Node3D = Node3D.new()
	target.position = Vector3(10, 0, 0)
	t.add_child(target)
	shake.clear()
	shake.shake(1.0, 10.0, 1.0, 0.5, 3)
	var start: Vector3 = target.position
	shake.apply_to(target, 0.016)
	t.check("F-S-23-10 apply_to moves node", target.position != start, "start=%s end=%s" % [str(start), str(target.position)])
	target.queue_free()
