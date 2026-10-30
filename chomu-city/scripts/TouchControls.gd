extends Control
## Multi-touch controls drawn in one Control:
##  - floating joystick (left side), camera swipe (anywhere else, mainly right half)
##  - on foot: JUMP, SPRINT (toggle), ENTER (near a car)
##  - driving: steer ◀ ▶ (left), GAS / BRAKE pedals (right), EXIT, HORN, handbrake
## Works with a mouse too (project emulates touch from mouse).

const JOY_R := 95.0
var touches := {}            # index -> {role, start, pos}
var sprint_lock := false
var _font: Font
var _pressed_flash := {}     # id -> time

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

func _vsize() -> Vector2:
	return get_viewport_rect().size

func _buttons() -> Array:
	var s := _vsize()
	var b: Array = []
	if Game.driving:
		b.append({"id": "left", "pos": Vector2(120, s.y - 130), "r": 78.0, "label": "", "tri": -1, "hold": true})
		b.append({"id": "right", "pos": Vector2(310, s.y - 130), "r": 78.0, "label": "", "tri": 1, "hold": true})
		b.append({"id": "gas", "pos": Vector2(s.x - 125, s.y - 150), "r": 88.0, "label": "GAS", "hold": true, "color": Color(0.2, 0.75, 0.35)})
		b.append({"id": "brake", "pos": Vector2(s.x - 320, s.y - 110), "r": 70.0, "label": "BRAKE", "hold": true, "color": Color(0.85, 0.25, 0.2)})
		b.append({"id": "handbrake", "pos": Vector2(s.x - 330, s.y - 270), "r": 46.0, "label": "DRIFT", "hold": true})
		b.append({"id": "enter", "pos": Vector2(s.x - 110, s.y - 360), "r": 52.0, "label": "EXIT", "hold": false, "color": Color(1.0, 0.72, 0.18)})
		b.append({"id": "horn", "pos": Vector2(s.x - 230, s.y - 400), "r": 42.0, "label": "HORN", "hold": false})
	else:
		b.append({"id": "jump", "pos": Vector2(s.x - 130, s.y - 140), "r": 80.0, "label": "JUMP", "hold": true})
		b.append({"id": "sprint", "pos": Vector2(s.x - 310, s.y - 95), "r": 66.0, "label": "RUN", "hold": false, "toggle": true})
		if Game.near_car:
			b.append({"id": "enter", "pos": Vector2(s.x - 140, s.y - 340), "r": 66.0, "label": "ENTER", "hold": false, "color": Color(1.0, 0.72, 0.18)})
	b.append({"id": "pause", "pos": Vector2(60, 60), "r": 36.0, "label": "II", "hold": false})
	return b

func _hit(p: Vector2) -> Dictionary:
	for b in _buttons():
		if p.distance_to(b.pos) <= b.r * 1.12:
			return b
	return {}

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			var b := _hit(e.position)
			var role := ""
			if not b.is_empty():
				role = "btn:" + b.id
				_press(b)
			elif not Game.driving and e.position.x < _vsize().x * 0.42 and e.position.y > _vsize().y * 0.3:
				role = "joy"
			else:
				role = "cam"
			touches[e.index] = {"role": role, "start": e.position, "pos": e.position}
			get_viewport().set_input_as_handled()
		else:
			if touches.has(e.index):
				_release(touches[e.index])
				touches.erase(e.index)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if touches.has(d.index):
			var t: Dictionary = touches[d.index]
			t.pos = d.position
			if t.role == "joy":
				var v: Vector2 = (t.pos - t.start) / JOY_R
				if v.length() > 1.0:
					# floating joystick: drag the base along when pulling past the edge
					t.start = t.pos - v.normalized() * JOY_R
					v = v.normalized()
				Game.move = v
			elif t.role == "cam":
				Game.look_delta += d.relative
			get_viewport().set_input_as_handled()

func _press(b: Dictionary) -> void:
	_pressed_flash[b.id] = 0.25
	if b.get("hold", false):
		Game.btn[b.id] = true
	elif b.get("toggle", false):
		sprint_lock = not sprint_lock
		Game.btn.sprint = sprint_lock
	else:
		Game.emit_signal("action", b.id)

func _release(t: Dictionary) -> void:
	var role: String = t.role
	if role == "joy":
		Game.move = Vector2.ZERO
	elif role.begins_with("btn:"):
		var id := role.substr(4)
		if Game.btn.has(id) and id != "sprint":
			Game.btn[id] = false

func release_all() -> void:
	touches.clear()
	Game.move = Vector2.ZERO
	for k in Game.btn:
		if k != "sprint":
			Game.btn[k] = false

func _process(delta: float) -> void:
	for k in _pressed_flash.keys():
		_pressed_flash[k] -= delta
		if _pressed_flash[k] <= 0.0:
			_pressed_flash.erase(k)
	# auto-release sprint lock when the player stops
	if sprint_lock and not Game.driving and Game.get_move_vector().length() < 0.1 and not _joy_active():
		sprint_lock = false
		Game.btn.sprint = false
	queue_redraw()

func _joy_active() -> bool:
	for t in touches.values():
		if t.role == "joy":
			return true
	return false

func _draw() -> void:
	# joystick
	if not Game.driving:
		var base := Vector2(200, _vsize().y - 190)
		var knob := base
		var active := false
		for t in touches.values():
			if t.role == "joy":
				base = t.start
				knob = t.start + Game.move * JOY_R
				active = true
		if not active and Game.demo and Game.move.length() > 0.05:
			knob = base + Game.move * JOY_R
			active = true
		draw_circle(base, JOY_R + 10, Color(0, 0, 0, 0.22 if active else 0.12))
		draw_arc(base, JOY_R + 10, 0, TAU, 48, Color(1, 1, 1, 0.35 if active else 0.18), 3.0, true)
		draw_circle(knob, 44, Color(1, 1, 1, 0.55 if active else 0.25))
	for b in _buttons():
		var held: bool = (b.get("hold", false) and Game.btn.get(b.id, false)) or _pressed_flash.has(b.id) \
			or (b.get("toggle", false) and sprint_lock)
		var col: Color = b.get("color", Color(1, 1, 1))
		draw_circle(b.pos, b.r, Color(col.r, col.g, col.b, 0.42 if held else 0.16))
		draw_arc(b.pos, b.r, 0, TAU, 48, Color(col.r, col.g, col.b, 0.85 if held else 0.45), 3.0, true)
		if b.has("tri"):
			var dx: float = b.tri * b.r * 0.38
			draw_colored_polygon(PackedVector2Array([b.pos + Vector2(dx, 0), b.pos + Vector2(-dx * 0.6, -b.r * 0.38), b.pos + Vector2(-dx * 0.6, b.r * 0.38)]), Color(1, 1, 1, 0.9))
			continue
		var fs := int(clampf(b.r * 0.36, 16, 30))
		var ts := _font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(_font, b.pos + Vector2(-ts.x * 0.5, fs * 0.35), b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(1, 1, 1, 0.95))
