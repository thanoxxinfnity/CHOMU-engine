extends Control
## Loading screen: threaded ResourceLoader for the world scene + all models,
## then instantiates the world (which builds the city) and swaps scenes.

const TIPS := [
	"Swipe anywhere on the right half of the screen to look around.",
	"Hold SPRINT while moving to run. Tap JUMP to hop over curbs.",
	"Walk up to a car and tap ENTER to drive it.",
	"Street lights switch on automatically when the sun goes down.",
	"Pause menu → Settings to change graphics (Low → Ultra) and sensitivity.",
	"Try tilt steering in Settings for a racing-game feel.",
	"Drop your own .glb models into assets/custom/ to replace the hero car or player.",
]

var _paths: Array = []
var _bar: ProgressBar
var _status: Label
var _tip: Label
var _t := 0.0
var _tip_t := 0.0
var _tip_i := 0
var _phase := 0
var _shown := 0.0
var _world: Node

func _ready() -> void:
	theme = Util.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.149, 0.161, 0.184)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 22)
	center.add_child(v)

	var logo := TextureRect.new()
	logo.texture = load("res://splash.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(720, 400)
	v.add_child(logo)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(720, 18)
	_bar.show_percentage = false
	_bar.max_value = 100
	v.add_child(_bar)
	_status = Util.label("Loading city...", 22, Color(1, 1, 1, 0.7))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_status)
	_tip = Util.label("", 22, Util.ACCENT)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.custom_minimum_size = Vector2(900, 0)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_tip)
	_tip_i = randi() % TIPS.size()
	_tip.text = "TIP: " + TIPS[_tip_i]

	_paths = [Game.WORLD_SCENE]
	_paths.append_array(Assets.preload_list())
	for p in _paths:
		if ResourceLoader.exists(p):
			ResourceLoader.load_threaded_request(p, "", true)

func _process(delta: float) -> void:
	_t += delta
	_tip_t += delta
	if _tip_t > 3.5:
		_tip_t = 0.0
		_tip_i = (_tip_i + 1) % TIPS.size()
		_tip.text = "TIP: " + TIPS[_tip_i]
	match _phase:
		0:
			var total := 0.0
			var done := true
			for p in _paths:
				if not ResourceLoader.exists(p):
					total += 1.0
					continue
				var prog := []
				var st := ResourceLoader.load_threaded_get_status(p, prog)
				if st == ResourceLoader.THREAD_LOAD_LOADED:
					total += 1.0
				elif st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					total += float(prog[0]) if prog.size() > 0 else 0.0
					done = false
				else:
					total += 1.0
			var pct := total / float(_paths.size()) * 85.0
			_bar.value = maxf(_bar.value, minf(pct, _t / 2.0 * 85.0))
			_status.text = "Loading assets... %d%%" % int(_bar.value)
			if done and _t > 2.0:
				for p in _paths:
					if ResourceLoader.exists(p):
						var r = ResourceLoader.load_threaded_get(p)
						if r is PackedScene:
							Util._cache[p] = r
				_phase = 1
				_status.text = "Building streets..."
				_bar.value = 88
		1:
			# give the label one frame to draw, then build the world
			_phase = 2
		2:
			var ps: PackedScene = Util._cache.get(Game.WORLD_SCENE, load(Game.WORLD_SCENE))
			_world = ps.instantiate()
			_phase = 3
			_bar.value = 100
			_status.text = "Ready!"
			_shown = _t
		3:
			if _t - _shown > 0.3:
				_phase = 4
				var tree := get_tree()
				tree.root.add_child(_world)
				tree.current_scene = _world
				queue_free()
