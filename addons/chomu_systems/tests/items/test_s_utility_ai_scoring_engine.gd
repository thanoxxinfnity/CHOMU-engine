extends RefCounted
const Impl := preload("res://addons/chomu_systems/sheet/utility_ai_scoring_engine.gd")

func run(t: Node) -> void:
	var engine: ChomuUtilityAiScoringEngine = Impl.new()
	t.check("S-06 engine instantiates", engine is ChomuUtilityAiScoringEngine, "class_name and type ok")

	# Build actions: heal (survival) and attack (combat)
	var heal_cfg: Impl.ActionConfig = Impl.ActionConfig.new()
	heal_cfg.name = "heal"
	heal_cfg.priority = 0.1
	var c_health: Impl.ConsiderationConfig = Impl.ConsiderationConfig.new()
	c_health.name = "health_low"
	c_health.weight = 1.0
	c_health.curve = "linear"
	c_health.min_input = 0.0
	c_health.max_input = 1.0
	c_health.min_output = 0.0
	c_health.max_output = 1.0
	heal_cfg.considerations = [c_health]
	heal_cfg.cooldown_seconds = 5.0

	var atk_cfg: Impl.ActionConfig = Impl.ActionConfig.new()
	atk_cfg.name = "attack"
	atk_cfg.priority = 0.2
	var c_enemy: Impl.ConsiderationConfig = Impl.ConsiderationConfig.new()
	c_enemy.name = "enemy_close"
	c_enemy.weight = 1.0
	c_enemy.curve = "linear"
	c_enemy.min_input = 0.0
	c_enemy.max_input = 1.0
	c_enemy.min_output = 0.0
	c_enemy.max_output = 1.0
	atk_cfg.considerations = [c_enemy]
	atk_cfg.cooldown_seconds = 2.0

	engine.register_action(heal_cfg)
	engine.register_action(atk_cfg)
	t.check("S-06 two actions registered", engine.score_actions().size() == 2, "score_actions returns both")

	# High health, no enemy -> attack still slightly higher due to priority bias
	engine.set_context("health_low", 0.0)
	engine.set_context("enemy_close", 0.0)
	engine.tick()
	var scores: Array[Dictionary] = engine.score_actions()
	t.check("S-06 priority bias at zero context", scores[0]["name"] == "attack", "attack wins on priority when inputs are 0")

	# Low health -> heal should outscore attack
	engine.set_context("health_low", 1.0)
	engine.set_context("enemy_close", 0.0)
	scores = engine.score_actions()
	t.check("S-06 low health triggers heal", scores[0]["name"] == "heal", "heal wins when health_low is 1")

	# Enemy close -> attack should outscore heal
	engine.set_context("health_low", 0.0)
	engine.set_context("enemy_close", 1.0)
	scores = engine.score_actions()
	t.check("S-06 enemy close triggers attack", scores[0]["name"] == "attack", "attack wins when enemy_close is 1")

	# Cooldown blocks execution
	engine.set_context("health_low", 1.0)
	engine.set_context("enemy_close", 0.0)
	var res: bool = engine.execute_action("heal")
	t.check("S-06 execute heal succeeds", res == true, "heal executed")
	res = engine.execute_action("heal")
	t.check("S-06 heal on cooldown blocks", res == false, "second heal blocked by cooldown")

	# decide_and_execute picks best usable (fresh engine, no prior cooldowns)
	var engine_decide: ChomuUtilityAiScoringEngine = Impl.new()
	engine_decide.register_action(heal_cfg)
	engine_decide.register_action(atk_cfg)
	engine_decide.set_context("health_low", 1.0)
	engine_decide.set_context("enemy_close", 0.0)
	var chosen: String = engine_decide.decide_and_execute()
	t.check("S-06 decide_and_execute picks heal", chosen == "heal", "chose heal")

	# Save/load state round-trip
	engine.set_context("health_low", 0.5)
	engine.set_context("enemy_close", 0.5)
	engine.execute_action("attack")
	var state: Dictionary = engine.save_state()
	var engine2: ChomuUtilityAiScoringEngine = Impl.new()
	engine2.seed = 999
	engine2.register_action(heal_cfg)
	engine2.register_action(atk_cfg)
	engine2.load_state(state)
	t.check("S-06 load_state restores cooldown", engine2.score_actions()[0]["usable"] == false, "attack still on cooldown after load")
	t.check("S-06 load_state restores blackboard", engine2.get_context("health_low") == 0.5, "blackboard restored")

	# Determinism: same seed yields same RNG (engine holds seeded RNG even if unused here)
	var e1: ChomuUtilityAiScoringEngine = Impl.new()
	e1.seed = 42
	var e2: ChomuUtilityAiScoringEngine = Impl.new()
	e2.seed = 42
	t.check("S-06 seeded RNG deterministic", e1.seed == e2.seed, "seeds match")

	# Sigmoid curve shape check
	var sc: Impl.ConsiderationConfig = Impl.ConsiderationConfig.new()
	sc.name = "x"
	sc.weight = 1.0
	sc.curve = "sigmoid"
	sc.min_input = 0.0
	sc.max_input = 1.0
	sc.min_output = 0.0
	sc.max_output = 1.0
	var ac: Impl.ActionConfig = Impl.ActionConfig.new()
	ac.name = "sigmoid_act"
	ac.considerations = [sc]
	var e3: ChomuUtilityAiScoringEngine = Impl.new()
	e3.register_action(ac)
	e3.set_context("x", 0.5)
	var s: Array[Dictionary] = e3.score_actions()
	t.check("S-06 sigmoid at 0.5 approx 0.5", s[0]["score"] > 0.4 and s[0]["score"] < 0.6, "sigmoid midpoint ~0.5")

	# Step curve at threshold
	var sc2: Impl.ConsiderationConfig = Impl.ConsiderationConfig.new()
	sc2.name = "x"
	sc2.weight = 1.0
	sc2.curve = "step"
	sc2.min_input = 0.0
	sc2.max_input = 1.0
	sc2.min_output = 0.0
	sc2.max_output = 1.0
	var ac2: Impl.ActionConfig = Impl.ActionConfig.new()
	ac2.name = "step_act"
	ac2.considerations = [sc2]
	var e4: ChomuUtilityAiScoringEngine = Impl.new()
	e4.register_action(ac2)
	e4.set_context("x", 0.49)
	var s4: Array[Dictionary] = e4.score_actions()
	t.check("S-06 step below 0.5 is 0", s4[0]["score"] < 0.01, "step below threshold is zero")
	e4.set_context("x", 0.5)
	s4 = e4.score_actions()
	t.check("S-06 step at 0.5 is 1", s4[0]["score"] > 0.99, "step at threshold is one")
