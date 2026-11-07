extends RefCounted

const Impl := preload("res://addons/chomu_systems/atmosphere/biometric_hooks.gd")

class FakeProvider:
	var hr: float = 60.0
	var eda: float = 10.0
	func poll() -> Dictionary:
		return {"heart_rate": hr, "eda": eda}

class RemoteProvider:
	var url: String = "http://api.bio.com"
	func poll() -> Dictionary:
		return {"heart_rate": 70.0, "eda": 20.0}

func run(t: Node) -> void:
	var hooks = Impl.new()
	t.add_child(hooks)
	
	# 1. Disabled by default returns 0 bias
	t.check("F-48 default bias is 0", hooks.tension_bias() == 0.0, "Should be 0 when disabled/no consent")
	
	# 2. Remote-looking provider rejected
	var remote = RemoteProvider.new()
	var registered_remote = hooks.register_provider(remote)
	t.check("F-48 reject remote provider", registered_remote == false, "Providers with 'url' must be rejected")
	
	# 3. High HR raises bias with consent
	var local = FakeProvider.new()
	hooks.register_provider(local)
	hooks.enabled = true
	hooks.consent_given = true
	local.hr = 180.0 # High HR
	local.eda = 90.0 # High EDA
	
	# Sample enough times to overcome EMA smoothing
	for i in range(50):
		hooks.sample()
	
	var bias = hooks.tension_bias()
	t.check("F-48 high HR increases bias", bias > 0.1, "Bias should be significant for high biometric values")
	
	# 4. Out-of-range values clamp
	local.hr = 500.0 # Way over 220
	local.eda = -50.0 # Way under 0
	var data = hooks.sample()
	t.check("F-48 HR clamp max", data.heart_rate <= 220.0, "HR should be clamped to 220")
	t.check("F-48 EDA clamp min", data.eda >= 0.0, "EDA should be clamped to 0")
	
	# 5. Revoke clears history
	hooks.revoke_consent()
	t.check("F-48 revoke clears consent", hooks.consent_given == false, "Consent should be false")
	t.check("F-48 revoke resets bias", hooks.tension_bias() == 0.0, "Bias must be 0 after revoke")
	
	hooks.queue_free()
