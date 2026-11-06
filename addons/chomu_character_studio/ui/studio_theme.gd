@tool
extends RefCounted
## CHoMU Character Studio dark theme.
## Palette rule: blue, teal, orange and grey accents only (never pink / magenta / rose).

const BG := Color("#14171b")
const PANEL := Color("#1b1f25")
const PANEL2 := Color("#232830")
const PANEL3 := Color("#2c323b")
const LINE := Color("#363d47")
const TEXT := Color("#d8dde3")
const MUTED := Color("#8a94a0")
const BLUE := Color("#3d8bfd")
const TEAL := Color("#22b3a6")
const ORANGE := Color("#f08a24")
const GREY := Color("#6b7682")
const OK := Color("#3fbf7f")
const WARN := Color("#f0b429")

## Weight heat map: 0 -> deep blue, 0.33 -> teal, 0.66 -> yellow, 1 -> orange.
static func heat(w: float) -> Color:
	w = clampf(w, 0.0, 1.0)
	var stops = [Color("#1d3b8f"), Color("#22b3a6"), Color("#e8d33a"), Color("#f08a24")]
	var f = w * 3.0
	var i = mini(int(f), 2)
	return (stops[i] as Color).lerp(stops[i + 1], f - float(i))

static func flat(c: Color, radius := 6, border := Color(0, 0, 0, 0), bw := 0, pad := 6) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.content_margin_left = pad + 2
	s.content_margin_right = pad + 2
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s

static func build() -> Theme:
	var t = Theme.new()
	var base_font_size = 14
	t.default_font_size = base_font_size
	# Buttons
	t.set_stylebox("normal", "Button", flat(PANEL3, 6))
	t.set_stylebox("hover", "Button", flat(PANEL3.lightened(0.08), 6, BLUE, 1))
	t.set_stylebox("pressed", "Button", flat(BLUE.darkened(0.35), 6, BLUE, 1))
	t.set_stylebox("hover_pressed", "Button", flat(BLUE.darkened(0.25), 6, BLUE, 1))
	t.set_stylebox("focus", "Button", flat(Color(0, 0, 0, 0), 6, BLUE.darkened(0.2), 1))
	t.set_stylebox("disabled", "Button", flat(PANEL2, 6))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	t.set_color("icon_normal_color", "Button", TEXT)
	t.set_color("icon_hover_color", "Button", Color.WHITE)
	t.set_color("icon_pressed_color", "Button", Color.WHITE)
	t.set_constant("h_separation", "Button", 8)
	# Labels
	t.set_color("font_color", "Label", TEXT)
	# Line edits / spin boxes
	t.set_stylebox("normal", "LineEdit", flat(BG, 5, LINE, 1, 4))
	t.set_stylebox("focus", "LineEdit", flat(BG, 5, BLUE, 1, 4))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", ORANGE)
	t.set_color("selection_color", "LineEdit", BLUE.darkened(0.3))
	# Option button / popups
	t.set_stylebox("normal", "OptionButton", flat(PANEL3, 6))
	t.set_stylebox("hover", "OptionButton", flat(PANEL3.lightened(0.08), 6, BLUE, 1))
	t.set_stylebox("pressed", "OptionButton", flat(PANEL3, 6, BLUE, 1))
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_stylebox("panel", "PopupMenu", flat(PANEL2, 6, LINE, 1, 4))
	t.set_stylebox("hover", "PopupMenu", flat(BLUE.darkened(0.3), 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	# Sliders
	var grab = flat(ORANGE, 8)
	t.set_stylebox("slider", "HSlider", flat(BG, 3, LINE, 1, 2))
	t.set_stylebox("grabber_area", "HSlider", flat(TEAL.darkened(0.15), 3, Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(TEAL, 3, Color(0, 0, 0, 0), 0, 2))
	# Panels / containers
	t.set_stylebox("panel", "PanelContainer", flat(PANEL, 8, LINE, 1, 8))
	t.set_stylebox("panel", "Panel", flat(BG, 0))
	t.set_stylebox("panel", "Tree", flat(BG, 6, LINE, 1, 4))
	t.set_color("font_color", "Tree", TEXT)
	t.set_color("font_selected_color", "Tree", Color.WHITE)
	t.set_stylebox("selected", "Tree", flat(BLUE.darkened(0.35), 4))
	t.set_stylebox("selected_focus", "Tree", flat(BLUE.darkened(0.25), 4))
	t.set_stylebox("panel", "ItemList", flat(BG, 6, LINE, 1, 4))
	t.set_stylebox("selected", "ItemList", flat(BLUE.darkened(0.35), 4))
	t.set_stylebox("selected_focus", "ItemList", flat(BLUE.darkened(0.25), 4))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_stylebox("normal", "CheckBox", flat(Color(0, 0, 0, 0), 4, Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("hover", "CheckBox", flat(PANEL3, 4, Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("pressed", "CheckBox", flat(Color(0, 0, 0, 0), 4, Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("hover_pressed", "CheckBox", flat(PANEL3, 4, Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("separator", "HSeparator", flat(LINE, 0, Color(0, 0, 0, 0), 0, 0))
	t.set_constant("separation", "HSeparator", 10)
	t.set_stylebox("panel", "TooltipPanel", flat(PANEL2, 5, LINE, 1, 5))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("tab_selected", "TabBar", flat(PANEL3, 5, Color(0, 0, 0, 0), 0, 5))
	t.set_stylebox("tab_unselected", "TabBar", flat(PANEL, 5, Color(0, 0, 0, 0), 0, 5))
	t.set_color("font_selected_color", "TabBar", Color.WHITE)
	t.set_color("font_unselected_color", "TabBar", MUTED)
	return t
