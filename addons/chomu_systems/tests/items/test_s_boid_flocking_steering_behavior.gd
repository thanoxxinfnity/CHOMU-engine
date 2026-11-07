extends RefCounted
const Impl := preload("res://addons/chomu_systems/sheet/boid_flocking_steering_behavior.gd")

func run(t: Node) -> void:
	var flock: ChomuBoidFlockingSteeringBehavior = Impl.new()
	flock.flock_size = 16
	flock.seed = 42
	flock.world_bounds = AABB(Vector3(-10, -5, -10), Vector3(20, 10, 20))
	flock.wrap_world = true
	flock.initialize()

	t.check("S-07 flock initialized with correct count", flock.get_boids().size() == 16, "expected 16 boids")

	# All boids should start inside world bounds.
	var all_inside: bool = true
	for boid in flock.get_boids():
		if not flock.world_bounds.has_point(boid.position):
			all_inside = false
			break
	t.check("S-07 all boids start inside world bounds", all_inside, "some boid outside bounds")

	# Determinism: same seed should produce identical initial positions.
	var flock2: ChomuBoidFlockingSteeringBehavior = Impl.new()
	flock2.flock_size = 16
	flock2.seed = 42
	flock2.world_bounds = flock.world_bounds
	flock2.wrap_world = true
	flock2.initialize()
	var deterministic: bool = true
	for i in range(16):
		var b1: Impl.BoidState = flock.get_boid(i)
		var b2: Impl.BoidState = flock2.get_boid(i)
		if b1 == null or b2 == null or b1.position != b2.position:
			deterministic = false
			break
	t.check("S-07 same seed yields identical initial positions", deterministic, "positions differ with same seed")

	# Different seed should (very likely) produce different positions.
	var flock3: ChomuBoidFlockingSteeringBehavior = Impl.new()
	flock3.flock_size = 16
	flock3.seed = 99
	flock3.world_bounds = flock.world_bounds
	flock3.wrap_world = true
	flock3.initialize()
	var different: bool = false
	for i in range(16):
		var b3: Impl.BoidState = flock.get_boid(i)
		var b4: Impl.BoidState = flock3.get_boid(i)
		if b3 != null and b4 != null and b3.position != b4.position:
			different = true
			break
	t.check("S-07 different seed yields different initial positions", different, "positions identical despite different seed")

	# Step the flock and verify outputs are produced.
	var outputs: Array[Impl.SteeringOutput] = flock.step(0.016)
	t.check("S-07 step returns one output per boid", outputs.size() == 16, "output count mismatch")

	# Velocities should be clamped to max_speed after stepping.
	var max_speed: float = flock.default_config.max_speed
	var speeds_clamped: bool = true
	for out in outputs:
		if out.velocity.length() > max_speed + 0.001:
			speeds_clamped = false
			break
	t.check("S-07 velocities clamped to max_speed", speeds_clamped, "some velocity exceeds max_speed")

	# Set a target and verify boids steer toward it (target steering component nonzero).
	flock.set_target_position(Vector3(100, 0, 100))
	outputs = flock.step(0.016)
	var has_target_steer: bool = false
	for out in outputs:
		if out.target.length_squared() > 0.0:
			has_target_steer = true
			break
	t.check("S-07 target seeking produces steering force", has_target_steer, "no target steering generated")

	# Add an obstacle and verify avoidance steering is generated.
	flock.clear_obstacles()
	flock.add_obstacle(Vector3(0, 0, 0), 2.0)
	# Place a boid near the obstacle manually.
	var boid: Impl.BoidState = flock.get_boid(0)
	if boid != null:
		boid.position = Vector3(1, 0, 1)
	outputs = flock.step(0.016)
	var has_obstacle_steer: bool = false
	for out in outputs:
		if out.obstacle.length_squared() > 0.0:
			has_obstacle_steer = true
			break
	t.check("S-07 obstacle avoidance produces steering force", has_obstacle_steer, "no obstacle steering generated")

	# Save/load state round-trip.
	var state: Dictionary = flock.save_state()
	flock2.load_state(state)
	var roundtrip: bool = true
	for i in range(16):
		var a: Impl.BoidState = flock.get_boid(i)
		var b: Impl.BoidState = flock2.get_boid(i)
		if a == null or b == null or a.position != b.position or a.velocity != b.velocity:
			roundtrip = false
			break
	t.check("S-07 save/load state round-trip preserves positions and velocities", roundtrip, "state mismatch after load")

	# Per-boid config override.
	var custom_cfg: Impl.BoidConfig = Impl.BoidConfig.new()
	custom_cfg.max_speed = 2.0
	flock.set_boid_config(0, custom_cfg)
	var cfg_applied: bool = flock.get_boid(0).config.max_speed == 2.0
	t.check("S-07 set_boid_config applies custom config", cfg_applied, "custom config not applied")

	# get_boid returns null for missing id.
	var missing: Impl.BoidState = flock.get_boid(9999)
	t.check("S-07 get_boid returns null for unknown id", missing == null, "expected null for unknown id")
