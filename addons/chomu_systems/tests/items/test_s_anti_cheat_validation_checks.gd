extends RefCounted
const Impl := preload("res://addons/chomu_systems/sheet/anti_cheat_validation_checks.gd")

func run(t: Node) -> void:
	var validator: Impl = Impl.new()

	# F-S-54 register peer with default config
	validator.register_peer(1)
	var cfg: Impl.MovementConfig = validator.default_config
	t.check("F-S-54 default config has sane limits", cfg.max_speed > 0 and cfg.max_acceleration > 0, "max_speed=%f accel=%f" % [cfg.max_speed, cfg.max_acceleration])

	# F-S-54 valid movement passes
	var result: Impl.ValidationResult = validator.validate(1, 1, Vector3(0, 0, 0), 0)
	t.check("F-S-54 initial valid movement accepted", result.valid, "reason=%s" % result.reason)

	result = validator.validate(1, 2, Vector3(5, 0, 0), 1000)  # 5 units/sec
	t.check("F-S-54 normal speed accepted", result.valid, "reason=%s" % result.reason)

	# F-S-54 speed hack detected
	result = validator.validate(1, 3, Vector3(100, 0, 0), 2000)  # 95 units/sec > 10
	t.check("F-S-54 speed hack rejected", not result.valid, "reason=%s" % result.reason)
	t.check("F-S-54 speed hack corrected position", result.corrected_position.distance_to(Vector3(5, 0, 0)) < 1.0)

	# F-S-54 teleport detected
	validator.register_peer(2)
	result = validator.validate(2, 1, Vector3(0, 0, 0), 0)
	t.check("F-S-54 peer2 start ok", result.valid)
	result = validator.validate(2, 2, Vector3(1000, 0, 0), 1000)  # huge jump
	t.check("F-S-54 teleport rejected", not result.valid, "reason=%s" % result.reason)
	t.check("F-S-54 teleport snapped back", result.corrected_position == Vector3(0, 0, 0))

	# F-S-54 tick going backwards rejected
	validator.register_peer(3)
	validator.validate(3, 10, Vector3(0, 0, 0), 0)
	result = validator.validate(3, 5, Vector3(1, 0, 0), 1000)
	t.check("F-S-54 backwards tick rejected", not result.valid, "reason=%s" % result.reason)

	# F-S-54 unregistered peer rejected
	result = validator.validate(99, 1, Vector3.ZERO, 0)
	t.check("F-S-54 unregistered peer rejected", not result.valid, "reason=%s" % result.reason)

	# F-S-54 penalty tracking
	t.check("F-S-54 penalty points accumulate", validator.get_penalty_points(1) > 0)
	t.check("F-S-54 violation count", validator.get_violations(1) > 0)

	# F-S-54 save/load state roundtrip
	validator.register_peer(4)
	validator.validate(4, 1, Vector3(0, 0, 0), 0)
	validator.validate(4, 2, Vector3(50, 0, 0), 100)  # speed hack to create state
	var state: Dictionary = validator.save_state()
	var validator2: Impl = Impl.new()
	validator2.load_state(state)
	t.check("F-S-54 load_state restores penalty", validator2.get_penalty_points(4) > 0)
	t.check("F-S-54 load_state restores violations", validator2.get_violations(4) > 0)
	t.check("F-S-54 load_state restores total_validations", validator2.total_validations == validator.total_validations)

	# F-S-54 custom config stricter limits
	var strict: Impl.MovementConfig = Impl.MovementConfig.new()
	strict.max_speed = 1.0
	validator.register_peer(5, strict)
	result = validator.validate(5, 1, Vector3(0, 0, 0), 0)
	t.check("F-S-54 custom config start ok", result.valid)
	result = validator.validate(5, 2, Vector3(2, 0, 0), 1000)  # 2 units/sec > 1
	t.check("F-S-54 strict config rejects", not result.valid, "reason=%s" % result.reason)

	# F-S-54 disabled config allows everything
	var open_cfg: Impl.MovementConfig = Impl.MovementConfig.new()
	open_cfg.enabled = false
	validator.register_peer(6, open_cfg)
	result = validator.validate(6, 1, Vector3(0, 0, 0), 0)
	t.check("F-S-54 disabled start ok", result.valid)
	result = validator.validate(6, 2, Vector3(9999, 0, 0), 1000)
	t.check("F-S-54 disabled allows teleport", result.valid, "reason=%s" % result.reason)
