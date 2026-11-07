extends Control
## Demo overlay: preset buttons, post-FX and rain toggles, live fps / renderer / tier readout.
## Lives on CanvasLayer 110 (above the ChomuPost grade at 100), so the UI is never colour-graded.
## Palette: slate, amber, teal, blue (no pink / magenta / rose).

signal preset_chosen(preset: String)
signal post_toggled(on: bool)
signal rain_toggled(on: bool)

const C_PANEL := Color(0.07, 0.09, 0.13, 0.82)
const C_LINE := Color("2a3348")
const C_TEXT := Color("eef1f7")
const C_MUTED := Color("9aa3b8")
const C_AMBER := Color("ffb02e")
const C_TEAL := Color("2bb3c0")

var _info: Label
var _fps: Label
var _buttons := {}
var _t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := clampf(get_viewport_rect().size.y / 720.0, 1.0, 2.5)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16) * s
	panel.add_theme_stylebox_override("panel", _box(C_PANEL, C_LINE, 14 * s, 12 * s))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(8 * s))
	panel.add_child(v)
	var title := Label.new()
	title.text = "CHoMU Ultra"
	title.add_theme_font_size_override("font_size", int(22 * s))
	title.add_theme_color_override("font_color", C_AMBER)
	v.add_child(title)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", int(13 * s))
	_info.add_theme_color_override("font_color", C_MUTED)
	v.add_child(_info)
	_fps = Label.new()
	_fps.add_theme_font_size_override("font_size", int(15 * s))
	_fps.add_theme_color_override("font_color", C_TEAL)
	v.add_child(_fps)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", int(6 * s))
	row.add_theme_constant_override("v_separation", int(6 * s))
	row.custom_minimum_size.x = 520 * s
	v.add_child(row)
	for p in ["Auto", "Low", "Medium", "Mobile Ultra", "PC Cinematic"]:
		var b := _button(p, s)
		b.pressed.connect(func(): preset_chosen.emit(p))
		row.add_child(b)
		_buttons[p] = b
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", int(14 * s))
	v.add_child(row2)
	var post := CheckButton.new()
	post.text = "Post FX"
	post.button_pressed = true
	post.add_theme_font_size_override("font_size", int(14 * s))
	post.toggled.connect(func(on: bool): post_toggled.emit(on))
	row2.add_child(post)
	var rain := CheckButton.new()
	rain.text = "Rain / wet"
	rain.add_theme_font_size_override("font_size", int(14 * s))
	rain.toggled.connect(func(on: bool): rain_toggled.emit(on))
	row2.add_child(rain)

func _box(bg: Color, border: Color, radius: float, pad: float) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(int(radius))
	b.content_margin_left = pad
	b.content_margin_right = pad
	b.content_margin_top = pad
	b.content_margin_bottom = pad
	return b

func _button(text: String, s: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48 * s)  # thumb-sized on phones
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", int(15 * s))
	b.add_theme_stylebox_override("normal", _box(Color("1b2233"), C_LINE, 10 * s, 8 * s))
	b.add_theme_stylebox_override("hover", _box(Color("232c42"), C_TEAL, 10 * s, 8 * s))
	b.add_theme_stylebox_override("pressed", _box(Color("2b2414"), C_AMBER, 10 * s, 8 * s))
	b.add_theme_color_override("font_color", C_TEXT)
	return b

func set_report(r: Dictionary, tier: Dictionary) -> void:
	for p in _buttons:
		var on: bool = p == str(r.get("preset", "")) or (p == "Auto" and str(r.get("requested", "")) == "Auto")
		(_buttons[p] as Button).add_theme_color_override("font_color", C_AMBER if on else C_TEXT)
	_info.text = "Preset: %s   Renderer: %s\nDevice tier: %s (%s)" % [r.get("preset", "?"), r.get("renderer", "?"),
		tier.get("preset", "?"), tier.get("reason", "")]

func _process(delta: float) -> void:
	_t += delta
	if _t < 0.5:
		return
	_t = 0.0
	var vp := get_viewport()
	_fps.text = "%d fps   3D scale %.2f   %s" % [Engine.get_frames_per_second(), vp.scaling_3d_scale,
		"MSAA 2x" if vp.msaa_3d == Viewport.MSAA_2X else ("TAA" if vp.use_taa else ("FXAA" if vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA else "no AA"))]
