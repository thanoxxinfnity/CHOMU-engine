@tool
extends EditorPlugin
## CHoMU Store - built into CHoMU Engine 1.3 (replaces the old asset library tab).
## Looks tab (1.3): the 12 Chomu Shader Pack looks (incl. Special Grade Realistic / Anime), one tap to apply.
## Free CC0 HDRIs, PBR textures and 3D models from Poly Haven (https://polyhaven.com).
## Data comes from the public Poly Haven API (https://api.polyhaven.com, no key); files are
## downloaded straight from the Poly Haven CDN by this client. API answers and thumbnails are
## cached in the editor cache folder, downloads are kept inside the project (res://chomu_assets/).
## One tap import: HDRI -> WorldEnvironment sky, texture -> StandardMaterial3D, model -> glTF scene.

const STORE_VERSION := "1.5"

var _view: Control

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "CHoMU Store"

func _get_plugin_icon() -> Texture2D:
	var th := EditorInterface.get_editor_theme()
	if th and th.has_icon("AssetLib", "EditorIcons"):
		return th.get_icon("AssetLib", "EditorIcons")
	return null

func _enter_tree() -> void:
	_view = StoreView.new()
	_view.plugin = self
	_view.name = "CHoMUStore"
	EditorInterface.get_editor_main_screen().add_child(_view)
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.hide()

func _exit_tree() -> void:
	if is_instance_valid(_view):
		_view.queue_free()
	_view = null

func _make_visible(visible: bool) -> void:
	if is_instance_valid(_view):
		_view.visible = visible
		if visible:
			_view.on_shown()


# =============================================================================== look & feel
class UI:
	const BG := Color("0f1117")
	const PANEL := Color("161a24")
	const CARD := Color("1b2030")
	const CARD_HOVER := Color("232a3f")
	const LINE := Color("2a3146")
	const TEXT := Color("eef0f6")
	const MUTED := Color("8f97ad")
	const ACCENT := Color("ff5a36")   # CHoMU orange
	const ACCENT2 := Color("ff2e88")  # CHoMU pink
	const GOOD := Color("3ddc97")
	const WARN := Color("ffc24b")
	const BAD := Color("ff5d6c")

	static var s := 1.0  # editor scale

	static func px(v: float) -> int:
		return int(round(v * s))

	static func box(bg: Color, radius := 12.0, border := Color(0, 0, 0, 0), bw := 0.0, pad_x := 12.0, pad_y := 8.0) -> StyleBoxFlat:
		var b := StyleBoxFlat.new()
		b.bg_color = bg
		b.set_corner_radius_all(px(radius))
		b.border_color = border
		b.set_border_width_all(int(max(0.0, round(bw * s))) if bw > 0.0 else 0)
		b.content_margin_left = px(pad_x)
		b.content_margin_right = px(pad_x)
		b.content_margin_top = px(pad_y)
		b.content_margin_bottom = px(pad_y)
		b.anti_aliasing = true
		return b

	static func font(bold := false) -> Font:
		var th := EditorInterface.get_editor_theme()
		if th:
			var n := "bold" if bold else "main"
			if th.has_font(n, "EditorFonts"):
				return th.get_font(n, "EditorFonts")
		return null

	static func label(text: String, size := 15.0, col := TEXT, bold := false) -> Label:
		var l := Label.new()
		l.text = text
		l.add_theme_font_size_override("font_size", px(size))
		l.add_theme_color_override("font_color", col)
		var f := font(bold)
		if f:
			l.add_theme_font_override("font", f)
		return l

	static func chip(text: String, col: Color, size := 12.0) -> Label:
		var l := label(text, size, col, true)
		var st := box(Color(col.r, col.g, col.b, 0.16), 99.0, Color(col.r, col.g, col.b, 0.55), 1.0, 9.0, 3.0)
		l.add_theme_stylebox_override("normal", st)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return l

	static func style_button(b: Button, primary := false, size := 15.0, radius := 12.0) -> void:
		var base := ACCENT if primary else CARD
		var hov := ACCENT.lightened(0.12) if primary else CARD_HOVER
		var line := ACCENT if primary else LINE
		b.add_theme_stylebox_override("normal", box(base, radius, line, 1.0, 16.0, 10.0))
		b.add_theme_stylebox_override("hover", box(hov, radius, line.lightened(0.1), 1.0, 16.0, 10.0))
		b.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.25), radius, ACCENT, 1.0, 16.0, 10.0))
		b.add_theme_stylebox_override("hover_pressed", box(ACCENT.darkened(0.15), radius, ACCENT, 1.0, 16.0, 10.0))
		b.add_theme_stylebox_override("disabled", box(base.darkened(0.45), radius, LINE, 1.0, 16.0, 10.0))
		b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), radius, ACCENT2, 2.0))
		b.add_theme_color_override("font_color", Color.WHITE if primary else TEXT)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_disabled_color", MUTED.darkened(0.2))
		b.add_theme_color_override("icon_normal_color", Color.WHITE if primary else TEXT)
		b.add_theme_font_size_override("font_size", px(size))
		var f := font(primary)
		if f:
			b.add_theme_font_override("font", f)
		b.custom_minimum_size.y = px(44)
		b.focus_mode = Control.FOCUS_NONE

	static func style_segment(b: Button) -> void:
		b.toggle_mode = true
		var off := box(Color(0, 0, 0, 0), 99.0, Color(0, 0, 0, 0), 0.0, 20.0, 9.0)
		var on := box(ACCENT, 99.0, ACCENT, 1.0, 20.0, 9.0)
		b.add_theme_stylebox_override("normal", off)
		b.add_theme_stylebox_override("hover", box(CARD_HOVER, 99.0, Color(0, 0, 0, 0), 0.0, 20.0, 9.0))
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", MUTED)
		b.add_theme_color_override("font_hover_color", TEXT)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
		b.add_theme_font_size_override("font_size", px(16))
		var f := font(true)
		if f:
			b.add_theme_font_override("font", f)
		b.custom_minimum_size.y = px(42)
		b.focus_mode = Control.FOCUS_NONE

	static func style_option(o: OptionButton) -> void:
		o.add_theme_stylebox_override("normal", box(CARD, 12.0, LINE, 1.0, 14.0, 9.0))
		o.add_theme_stylebox_override("hover", box(CARD_HOVER, 12.0, LINE, 1.0, 14.0, 9.0))
		o.add_theme_stylebox_override("pressed", box(CARD_HOVER, 12.0, ACCENT, 1.0, 14.0, 9.0))
		o.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		o.add_theme_color_override("font_color", TEXT)
		o.add_theme_color_override("font_hover_color", Color.WHITE)
		o.add_theme_font_size_override("font_size", px(15))
		o.custom_minimum_size.y = px(44)
		o.focus_mode = Control.FOCUS_NONE
		var pm := o.get_popup()
		pm.add_theme_stylebox_override("panel", box(PANEL, 12.0, LINE, 1.0, 6.0, 6.0))
		pm.add_theme_stylebox_override("hover", box(ACCENT.darkened(0.2), 8.0))
		pm.add_theme_font_size_override("font_size", px(16))
		pm.add_theme_constant_override("v_separation", px(14))
		pm.add_theme_color_override("font_color", TEXT)
		pm.add_theme_color_override("font_hover_color", Color.WHITE)

	static func style_line_edit(e: LineEdit) -> void:
		e.add_theme_stylebox_override("normal", box(Color("0a0c12"), 12.0, LINE, 1.0, 16.0, 9.0))
		e.add_theme_stylebox_override("focus", box(Color("0a0c12"), 12.0, ACCENT, 2.0, 16.0, 9.0))
		e.add_theme_stylebox_override("read_only", box(Color("0a0c12"), 12.0, LINE, 1.0, 16.0, 9.0))
		e.add_theme_color_override("font_color", TEXT)
		e.add_theme_color_override("font_placeholder_color", MUTED)
		e.add_theme_color_override("caret_color", ACCENT)
		e.add_theme_font_size_override("font_size", px(16))
		e.custom_minimum_size.y = px(44)

	static func style_progress(p: ProgressBar) -> void:
		p.add_theme_stylebox_override("background", box(Color(0, 0, 0, 0.45), 99.0, Color(0, 0, 0, 0), 0.0, 0.0, 0.0))
		var fill := box(ACCENT, 99.0, Color(0, 0, 0, 0), 0.0, 0.0, 0.0)
		p.add_theme_stylebox_override("fill", fill)
		p.show_percentage = false

	static func wordmark(size := 26.0) -> RichTextLabel:
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.scroll_active = false
		r.autowrap_mode = TextServer.AUTOWRAP_OFF
		r.add_theme_font_size_override("bold_font_size", px(size))
		r.add_theme_font_size_override("normal_font_size", px(size))
		var f := font(true)
		if f:
			r.add_theme_font_override("bold_font", f)
		r.text = "[b][color=#ffffff]CH[/color][color=#ff5a36]o[/color][color=#ffffff]MU[/color][/b]"
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		r.custom_minimum_size.x = px(size * 3.4)
		return r

	static func human_size(bytes: float) -> String:
		if bytes <= 0:
			return ""
		if bytes < 1024.0 * 1024.0:
			return "%d KB" % int(bytes / 1024.0)
		if bytes < 1024.0 * 1024.0 * 1024.0:
			return "%.1f MB" % (bytes / 1048576.0)
		return "%.2f GB" % (bytes / 1073741824.0)


# =============================================================================== Poly Haven client
class Client:
	extends Node
	## Async client: unique User-Agent, JSON cached 24 h, thumbnails cached forever,
	## retry with exponential backoff on network/408/429/5xx, max 4 parallel requests
	## (thumbnails may use at most 3 so one slot always stays free for downloads).
	signal file_progress(id: String, done: float, total: float)

	const API := "https://api.polyhaven.com"
	const USER_AGENT := "CHoMU-Engine-Store/1.2 (+https://chomu-engine.vercel.app)"
	const CACHE_TTL := 24 * 3600
	const MAX_PARALLEL := 4
	const MAX_THUMB_PARALLEL := 3
	const MAX_RETRIES := 3

	var cache_dir := ""
	var _active := 0
	var _active_thumbs := 0

	func _init() -> void:
		name = "PolyHavenClient"
		var base := EditorInterface.get_editor_paths().get_cache_dir()
		cache_dir = base.path_join("chomu_store")
		DirAccess.make_dir_recursive_absolute(cache_dir.path_join("api"))
		DirAccess.make_dir_recursive_absolute(cache_dir.path_join("thumbs"))

	func get_assets(type: String):
		return await _json("%s/assets?t=%s" % [API, type], "assets_%s.json" % type)

	func get_categories(type: String):
		return await _json("%s/categories/%s" % [API, type], "categories_%s.json" % type)

	func get_files(id: String):
		return await _json("%s/files/%s" % [API, id.uri_encode()], "files_%s.json" % id.validate_filename())

	func thumb_url(id: String, data: Dictionary, w: int, h: int) -> String:
		var u: String = str(data.get("thumbnail_url", ""))
		if u == "":
			u = "https://cdn.polyhaven.com/asset_img/thumbs/%s.png" % id
		var q := u.find("?")
		if q >= 0:
			u = u.substr(0, q)
		return "%s?width=%d&height=%d" % [u, w, h]

	## Returns an ImageTexture (cached on disk) or null.
	func get_thumb(id: String, url: String, tag := "512") -> Texture2D:
		var path := cache_dir.path_join("thumbs").path_join("%s_%s.img" % [id.validate_filename(), tag])
		if not FileAccess.file_exists(path):
			var r: Dictionary = await request(url, path, true)
			if not r.ok:
				return null
		var buf := FileAccess.get_file_as_bytes(path)
		var img := _decode(buf)
		if img == null:
			DirAccess.remove_absolute(path)
			return null
		img.generate_mipmaps()
		return ImageTexture.create_from_image(img)

	static func _decode(buf: PackedByteArray) -> Image:
		if buf.size() < 12:
			return null
		var img := Image.new()
		var err := ERR_FILE_UNRECOGNIZED
		if buf[0] == 0x89 and buf[1] == 0x50:
			err = img.load_png_from_buffer(buf)
		elif buf[0] == 0xFF and buf[1] == 0xD8:
			err = img.load_jpg_from_buffer(buf)
		elif buf[0] == 0x52 and buf[1] == 0x49 and buf[8] == 0x57:
			err = img.load_webp_from_buffer(buf)
		return img if err == OK else null

	## GET with retry + exponential backoff. save_path streams the body to a file.
	func request(url: String, save_path := "", is_thumb := false, progress_id := "") -> Dictionary:
		var result := {}
		for attempt in MAX_RETRIES + 1:
			result = await _request_once(url, save_path, is_thumb, progress_id)
			if result.ok:
				return result
			var code := int(result.code)
			var transient := code == 0 or code == 408 or code == 429 or code >= 500
			if not transient or attempt == MAX_RETRIES:
				break
			var wait := pow(2.0, attempt) + randf() * 0.5
			if code == 429:
				wait += 2.0
			await get_tree().create_timer(wait, true, false, true).timeout
		return result

	func _request_once(url: String, save_path: String, is_thumb: bool, progress_id: String) -> Dictionary:
		while _active >= MAX_PARALLEL or (is_thumb and _active_thumbs >= MAX_THUMB_PARALLEL):
			await get_tree().process_frame
		_active += 1
		if is_thumb:
			_active_thumbs += 1
		var http := HTTPRequest.new()
		http.timeout = 30.0 if is_thumb else 0.0
		http.body_size_limit = -1
		http.download_chunk_size = 262144
		http.use_threads = true
		var part := ""
		if save_path != "":
			DirAccess.make_dir_recursive_absolute(_abs(save_path.get_base_dir()))
			part = save_path + ".part"
			http.download_file = _abs(part)
		add_child(http)
		var result := {"ok": false, "code": 0, "body": PackedByteArray()}
		var err := http.request(url, PackedStringArray(["User-Agent: " + USER_AGENT]))
		if err == OK:
			var watching := progress_id != ""
			var done_sig := [false, []]
			http.request_completed.connect(func(r, c, h, b): done_sig[0] = true; done_sig[1] = [r, c, h, b], CONNECT_ONE_SHOT)
			while not done_sig[0]:
				await get_tree().process_frame
				if watching:
					file_progress.emit(progress_id, float(http.get_downloaded_bytes()), float(http.get_body_size()))
			var r: Array = done_sig[1]
			result.code = int(r[1])
			result.body = r[3]
			result.ok = int(r[0]) == HTTPRequest.RESULT_SUCCESS and int(r[1]) >= 200 and int(r[1]) < 300
		http.queue_free()
		_active -= 1
		if is_thumb:
			_active_thumbs -= 1
		if part != "":
			if result.ok:
				if FileAccess.file_exists(save_path):
					DirAccess.remove_absolute(_abs(save_path))
				DirAccess.rename_absolute(_abs(part), _abs(save_path))
			elif FileAccess.file_exists(part):
				DirAccess.remove_absolute(_abs(part))
		return result

	func _json(url: String, cache_name: String):
		var path := cache_dir.path_join("api").path_join(cache_name)
		var have := FileAccess.file_exists(path)
		if have and Time.get_unix_time_from_system() - FileAccess.get_modified_time(path) < CACHE_TTL:
			var c = JSON.parse_string(FileAccess.get_file_as_string(path))
			if c != null:
				return c
		var r: Dictionary = await request(url)
		if not r.ok:
			if have:  # offline: stale cache is better than nothing
				return JSON.parse_string(FileAccess.get_file_as_string(path))
			return null
		var text := (r.body as PackedByteArray).get_string_from_utf8()
		var parsed = JSON.parse_string(text)
		if parsed != null:
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f:
				f.store_string(text)
		return parsed

	static func _abs(p: String) -> String:
		return ProjectSettings.globalize_path(p) if (p.begins_with("res://") or p.begins_with("user://")) else p


# =============================================================================== main view
class StoreView:
	extends Control

	const TYPES := [["looks", "Looks"], ["hdris", "HDRIs"], ["textures", "Textures"], ["models", "Models"]]
	const RES_ALL := ["1k", "2k", "4k", "8k"]
	const PAGE := 36
	const ROOT_DIR := "res://chomu_assets"
	const SETTING_QUALITY := "chomu_store/graphics_quality"
	const SETTING_RES := "chomu_store/default_resolution"

	var plugin: EditorPlugin
	var client: Client
	var _type := "looks"
	var _data := {}          # type -> {id: info}
	var _cats := {}          # type -> {cat: count}
	var _list: Array = []    # filtered ids
	var _shown := 0
	var _loaded_once := false
	var _token := 0
	var _sel_id := ""
	var _sel_files := {}
	var _jobs := {}          # id -> {"done": bytes, "total": bytes}
	var _cards := {}         # id -> card dict
	var _quality := 0        # 0 = High, 1 = Mobile / Low
	var _cols := 4

	var _type_btns := {}
	var _search: LineEdit
	var _cat: OptionButton
	var _sort: OptionButton
	var _res: OptionButton
	var _quality_btn: OptionButton
	var _renderer_chip: Label
	var _scroll: ScrollContainer
	var _grid: GridContainer
	var _more: Button
	var _empty_box: VBoxContainer
	var _empty_label: Label
	var _status: Label
	var _status_bar: ProgressBar
	var _body: HBoxContainer
	var _preview: PanelContainer
	var _pv_img: TextureRect
	var _pv_name: Label
	var _pv_author: Label
	var _pv_chips: HFlowContainer
	var _pv_tags: Label
	var _pv_res: OptionButton
	var _pv_size: Label
	var _pv_get: Button
	var _pv_dl_only: Button
	var _pv_progress: ProgressBar
	var _pv_back: Button
	var _pv_credit: Label
	var _narrow := false
	var _filters: HFlowContainer
	var _looks_box: VBoxContainer
	var _looks_grid: GridContainer
	var _looks_cat: OptionButton
	var _looks_mode: OptionButton
	var _looks_info: Label
	var _looks_cards := {}
	var _looks_busy := false
	var _looks  # chomu_looks.gd helper (instance)

	func _init() -> void:
		UI.s = EditorInterface.get_editor_scale()
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		client = Client.new()
		add_child(client)
		client.file_progress.connect(_on_file_progress)
		var es := EditorInterface.get_editor_settings()
		var renderer := RenderingServer.get_current_rendering_method()
		_quality = 1 if renderer == "gl_compatibility" else 0
		if es.has_setting(SETTING_QUALITY):
			_quality = int(es.get_setting(SETTING_QUALITY))
		_build()
		resized.connect(_on_resized)

	# ------------------------------------------------------------------------- layout
	func _build() -> void:
		var bg := Panel.new()
		bg.add_theme_stylebox_override("panel", UI.box(UI.BG, 0.0))
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, UI.px(18 if side in ["left", "right"] else 14))
		add_child(margin)
		var root := VBoxContainer.new()
		root.add_theme_constant_override("separation", UI.px(12))
		margin.add_child(root)

		# Header ------------------------------------------------------------
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", UI.px(12))
		root.add_child(header)
		header.add_child(UI.wordmark(28))
		var title_box := VBoxContainer.new()
		title_box.add_theme_constant_override("separation", 0)
		title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title_box)
		title_box.add_child(UI.label("Store", 22, UI.TEXT, true))
		var sub := UI.label("One-tap Looks  ·  free CC0 HDRIs, PBR textures and 3D models from Poly Haven", 13, UI.MUTED)
		sub.clip_text = true
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sub.custom_minimum_size.x = UI.px(60)
		title_box.add_child(sub)
		_renderer_chip = UI.chip("", UI.GOOD, 12)
		_renderer_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(_renderer_chip)
		_quality_btn = OptionButton.new()
		_quality_btn.add_item("High quality", 0)
		_quality_btn.add_item("Mobile / Low", 1)
		_quality_btn.select(_quality)
		_quality_btn.tooltip_text = "High = 2K maps, full PBR, SSAO/SSR/glow on sky import.\nMobile / Low = 1K maps, lighter environment for weak phones."
		UI.style_option(_quality_btn)
		_quality_btn.item_selected.connect(_on_quality)
		_quality_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(_quality_btn)
		var refresh := Button.new()
		refresh.text = "Refresh"
		refresh.tooltip_text = "Reload the catalog from Poly Haven"
		UI.style_button(refresh, false, 14)
		refresh.pressed.connect(func(): _reload(true))
		refresh.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(refresh)

		# Category tabs (segmented) -----------------------------------------
		var tabs_row := HBoxContainer.new()
		tabs_row.add_theme_constant_override("separation", UI.px(10))
		root.add_child(tabs_row)
		var seg := PanelContainer.new()
		seg.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 99.0, UI.LINE, 1.0, 5.0, 5.0))
		tabs_row.add_child(seg)
		var seg_h := HBoxContainer.new()
		seg_h.add_theme_constant_override("separation", UI.px(4))
		seg.add_child(seg_h)
		var group := ButtonGroup.new()
		for t in TYPES:
			var b := Button.new()
			b.text = t[1]
			b.button_group = group
			UI.style_segment(b)
			b.pressed.connect(_set_type.bind(t[0]))
			seg_h.add_child(b)
			_type_btns[t[0]] = b
		_type_btns[_type].button_pressed = true
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs_row.add_child(sp)
		_search = LineEdit.new()
		_search.placeholder_text = "Search assets, tags…"
		_search.clear_button_enabled = true
		_search.custom_minimum_size.x = UI.px(160)
		_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_search.size_flags_stretch_ratio = 0.9
		UI.style_line_edit(_search)
		var deb := Timer.new()
		deb.one_shot = true
		deb.wait_time = 0.3
		add_child(deb)
		deb.timeout.connect(_apply_filter)
		_search.text_changed.connect(func(_t): deb.start())
		tabs_row.add_child(_search)

		# Filter row -----------------------------------------------------------
		var filters := HFlowContainer.new()
		filters.add_theme_constant_override("h_separation", UI.px(10))
		filters.add_theme_constant_override("v_separation", UI.px(8))
		root.add_child(filters)
		_filters = filters
		_cat = OptionButton.new()
		_cat.custom_minimum_size.x = UI.px(190)
		UI.style_option(_cat)
		_cat.item_selected.connect(func(_i): _apply_filter())
		filters.add_child(_labeled("Category", _cat))
		_sort = OptionButton.new()
		for s in ["Most popular", "Newest", "Name A–Z"]:
			_sort.add_item(s)
		_sort.custom_minimum_size.x = UI.px(160)
		UI.style_option(_sort)
		_sort.item_selected.connect(func(_i): _apply_filter())
		filters.add_child(_labeled("Sort", _sort))
		_res = OptionButton.new()
		for r in RES_ALL:
			_res.add_item(r.to_upper())
		_res.custom_minimum_size.x = UI.px(96)
		UI.style_option(_res)
		_res.select(_default_res_index())
		_res.item_selected.connect(func(_i): _sync_preview_res())
		filters.add_child(_labeled("Resolution", _res))

		# Body: grid + preview --------------------------------------------------
		_body = HBoxContainer.new()
		_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_body.add_theme_constant_override("separation", UI.px(14))
		root.add_child(_body)

		var grid_wrap := VBoxContainer.new()
		grid_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_body.add_child(grid_wrap)
		_scroll = ScrollContainer.new()
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.scroll_deadzone = UI.px(10)
		var vsb := _scroll.get_v_scroll_bar()
		vsb.add_theme_stylebox_override("scroll", UI.box(Color(1, 1, 1, 0.03), 99.0, Color(0, 0, 0, 0), 0.0, 5.0, 0.0))
		vsb.add_theme_stylebox_override("grabber", UI.box(Color(1, 1, 1, 0.18), 99.0, Color(0, 0, 0, 0), 0.0, 5.0, 0.0))
		vsb.add_theme_stylebox_override("grabber_highlight", UI.box(UI.ACCENT, 99.0, Color(0, 0, 0, 0), 0.0, 5.0, 0.0))
		vsb.add_theme_stylebox_override("grabber_pressed", UI.box(UI.ACCENT2, 99.0, Color(0, 0, 0, 0), 0.0, 5.0, 0.0))
		grid_wrap.add_child(_scroll)
		var inner := VBoxContainer.new()
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_theme_constant_override("separation", UI.px(14))
		_scroll.add_child(inner)
		_grid = GridContainer.new()
		_grid.columns = 4
		_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_theme_constant_override("h_separation", UI.px(14))
		_grid.add_theme_constant_override("v_separation", UI.px(14))
		inner.add_child(_grid)
		_more = Button.new()
		_more.text = "Show more"
		UI.style_button(_more, false, 15)
		_more.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_more.custom_minimum_size.x = UI.px(220)
		_more.pressed.connect(_show_more)
		inner.add_child(_more)
		_empty_box = VBoxContainer.new()
		_empty_box.alignment = BoxContainer.ALIGNMENT_CENTER
		_empty_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_empty_box.add_theme_constant_override("separation", UI.px(12))
		_empty_label = UI.label("", 17, UI.MUTED)
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_empty_box.add_child(_empty_label)
		var retry := Button.new()
		retry.text = "Try again"
		UI.style_button(retry, true, 15)
		retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		retry.pressed.connect(func(): _reload(true))
		_empty_box.add_child(retry)
		_empty_box.hide()
		grid_wrap.add_child(_empty_box)

		_build_preview()
		_body.add_child(_preview)
		_build_looks(root)

		# Status line ----------------------------------------------------------
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation", UI.px(12))
		root.add_child(foot)
		_status = UI.label("", 13, UI.MUTED)
		_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_status.clip_text = true
		foot.add_child(_status)
		_status_bar = ProgressBar.new()
		UI.style_progress(_status_bar)
		_status_bar.custom_minimum_size = Vector2(UI.px(180), UI.px(8))
		_status_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_status_bar.hide()
		foot.add_child(_status_bar)
		var credit := UI.label("Assets © their authors · CC0 · polyhaven.com", 13, UI.MUTED)
		foot.add_child(credit)
		_update_renderer_chip()

	func _labeled(text: String, c: Control) -> HBoxContainer:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", UI.px(8))
		var l := UI.label(text, 13, UI.MUTED, true)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
		h.add_child(c)
		return h

	func _build_preview() -> void:
		_preview = PanelContainer.new()
		_preview.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 18.0, UI.LINE, 1.0, 16.0, 16.0))
		_preview.custom_minimum_size.x = UI.px(340)
		_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.scroll_deadzone = UI.px(10)
		_preview.add_child(sc)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", UI.px(12))
		sc.add_child(v)
		_pv_back = Button.new()
		_pv_back.text = "‹  Back to store"
		UI.style_button(_pv_back, false, 15)
		_pv_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_pv_back.pressed.connect(_close_preview)
		_pv_back.hide()
		v.add_child(_pv_back)
		var img_panel := PanelContainer.new()
		img_panel.add_theme_stylebox_override("panel", UI.box(Color("0a0c12"), 14.0, Color(0, 0, 0, 0), 0.0, 0.0, 0.0))
		img_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		v.add_child(img_panel)
		_pv_img = TextureRect.new()
		_pv_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_pv_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_pv_img.custom_minimum_size.y = UI.px(220)
		img_panel.add_child(_pv_img)
		_pv_name = UI.label("Pick an asset", 22, UI.TEXT, true)
		_pv_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(_pv_name)
		_pv_author = UI.label("Tap any card to see details, then import it into your scene in one tap.", 14, UI.MUTED)
		_pv_author.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(_pv_author)
		_pv_chips = HFlowContainer.new()
		_pv_chips.add_theme_constant_override("h_separation", UI.px(6))
		_pv_chips.add_theme_constant_override("v_separation", UI.px(6))
		v.add_child(_pv_chips)
		_pv_tags = UI.label("", 13, UI.MUTED)
		_pv_tags.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(_pv_tags)
		var rrow := HBoxContainer.new()
		rrow.add_theme_constant_override("separation", UI.px(10))
		v.add_child(rrow)
		var rl := UI.label("Resolution", 13, UI.MUTED, true)
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rrow.add_child(rl)
		_pv_res = OptionButton.new()
		UI.style_option(_pv_res)
		_pv_res.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pv_res.item_selected.connect(func(_i): _update_size_label())
		rrow.add_child(_pv_res)
		_pv_size = UI.label("", 13, UI.MUTED)
		v.add_child(_pv_size)
		_pv_progress = ProgressBar.new()
		UI.style_progress(_pv_progress)
		_pv_progress.custom_minimum_size.y = UI.px(10)
		_pv_progress.hide()
		v.add_child(_pv_progress)
		_pv_get = Button.new()
		_pv_get.text = "Download & Import"
		UI.style_button(_pv_get, true, 17, 14)
		_pv_get.custom_minimum_size.y = UI.px(54)
		_pv_get.pressed.connect(func(): _get_selected(true))
		_pv_get.disabled = true
		v.add_child(_pv_get)
		_pv_dl_only = Button.new()
		_pv_dl_only.text = "Download only"
		UI.style_button(_pv_dl_only, false, 15)
		_pv_dl_only.pressed.connect(func(): _get_selected(false))
		_pv_dl_only.disabled = true
		v.add_child(_pv_dl_only)
		var site := Button.new()
		site.text = "View on polyhaven.com"
		site.flat = true
		UI.style_button(site, false, 14)
		site.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		site.add_theme_color_override("font_color", UI.ACCENT)
		site.pressed.connect(func():
			if _sel_id != "":
				OS.shell_open("https://polyhaven.com/a/" + _sel_id))
		v.add_child(site)
		_pv_credit = UI.label("", 12, UI.MUTED)
		_pv_credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(_pv_credit)

	# ------------------------------------------------------------------------- state
	func on_shown() -> void:
		_update_renderer_chip()
		if _type == "looks":
			_show_looks(true)
			return
		if not _loaded_once:
			_loaded_once = true
			_reload(false)
		call_deferred("_on_resized")

	func _default_res_index() -> int:
		var es := EditorInterface.get_editor_settings()
		var want := "1k" if _quality == 1 else "2k"
		if es.has_setting(SETTING_RES) and _quality == 0:
			want = str(es.get_setting(SETTING_RES))
		return max(0, RES_ALL.find(want))

	func _on_quality(i: int) -> void:
		_quality = i
		EditorInterface.get_editor_settings().set_setting(SETTING_QUALITY, i)
		_res.select(0 if i == 1 else 1)
		_sync_preview_res()
		_update_renderer_chip()
		_set_status("Graphics: " + ("Mobile / Low - 1K maps, light environment." if i == 1 else "High - 2K maps, full PBR, SSAO + SSR + glow on sky import."))

	func _update_renderer_chip() -> void:
		var m := RenderingServer.get_current_rendering_method()
		var names := {"forward_plus": "Forward+", "mobile": "Mobile renderer", "gl_compatibility": "Compatibility"}
		var col := UI.GOOD if m == "forward_plus" else (UI.WARN if m == "mobile" else UI.MUTED)
		_renderer_chip.text = "%s  ·  %s" % [names.get(m, m), "High" if _quality == 0 else "Low"]
		_renderer_chip.add_theme_color_override("font_color", col)
		_renderer_chip.add_theme_stylebox_override("normal", UI.box(Color(col.r, col.g, col.b, 0.14), 99.0, Color(col.r, col.g, col.b, 0.5), 1.0, 10.0, 4.0))

	func _set_status(t: String) -> void:
		_status.text = t

	func _set_type(t: String) -> void:
		for k in _type_btns:
			(_type_btns[k] as Button).set_pressed_no_signal(k == t)
		if t == _type:
			return
		_type = t
		if t == "looks":
			_show_looks(true)
			return
		_show_looks(false)
		_close_preview()
		_reset_preview()
		_loaded_once = true
		_reload(false)

	func _reset_preview() -> void:
		_pv_img.texture = null
		_pv_name.text = "Pick %s" % ("an HDRI" if _type == "hdris" else ("a texture" if _type == "textures" else "a model"))
		_pv_author.text = "Tap any card to see details, then import it into your scene in one tap."
		for c in _pv_chips.get_children():
			c.queue_free()
		_pv_tags.text = ""
		_pv_credit.text = ""
		_pv_size.text = ""
		_pv_res.clear()
		_pv_get.disabled = true
		_pv_dl_only.disabled = true

	func _reload(force: bool) -> void:
		if _type == "looks":
			_fill_looks()
			return
		_token += 1
		var tok := _token
		if force:
			_purge_api_cache()
			_data.erase(_type)
			_cats.erase(_type)
		_clear_grid()
		_empty_box.hide()
		_set_status("Loading %s from Poly Haven…" % _type_label(_type))
		_status_bar.show()
		_status_bar.value = 25
		if not _data.has(_type):
			var d = await client.get_assets(_type)
			if tok != _token:
				return
			if d == null or not (d is Dictionary) or (d as Dictionary).is_empty():
				_status_bar.hide()
				_empty_label.text = "Couldn't reach Poly Haven.\nCheck your internet connection and try again."
				_empty_box.show()
				_more.hide()
				_set_status("Offline")
				return
			_data[_type] = d
			var c = await client.get_categories(_type)
			if tok != _token:
				return
			_cats[_type] = c if c is Dictionary else {}
		_status_bar.hide()
		_fill_categories()
		_apply_filter()

	func _purge_api_cache() -> void:
		var d := client.cache_dir.path_join("api")
		for f in DirAccess.get_files_at(d):
			if f.begins_with("assets_%s" % _type) or f.begins_with("categories_%s" % _type):
				DirAccess.remove_absolute(d.path_join(f))

	func _type_label(t: String) -> String:
		for x in TYPES:
			if x[0] == t:
				return x[1]
		return t

	func _fill_categories() -> void:
		_cat.clear()
		var d: Dictionary = _data.get(_type, {})
		_cat.add_item("All  (%d)" % d.size())
		_cat.set_item_metadata(0, "")
		var c: Dictionary = _cats.get(_type, {})
		var keys := c.keys()
		keys.sort_custom(func(a, b): return int(c[a]) > int(c[b]))
		for k in keys:
			if str(k) == "all":
				continue
			_cat.add_item("%s  (%d)" % [str(k).capitalize(), int(c[k])])
			_cat.set_item_metadata(_cat.item_count - 1, str(k))
		_cat.select(0)

	func _apply_filter() -> void:
		if _type == "looks":
			_fill_looks()
			return
		var d: Dictionary = _data.get(_type, {})
		var q := _search.text.strip_edges().to_lower()
		var cat := ""
		if _cat.item_count > 0 and _cat.selected >= 0:
			cat = str(_cat.get_item_metadata(_cat.selected))
		var out: Array = []
		for id in d:
			var a: Dictionary = d[id]
			if cat != "" and not (cat in a.get("categories", [])):
				continue
			if q != "":
				var hay := (str(id) + " " + str(a.get("name", "")) + " " + " ".join(PackedStringArray(a.get("tags", []))) + " " + " ".join(PackedStringArray(a.get("categories", [])))).to_lower()
				var ok := true
				for word in q.split(" ", false):
					if hay.find(word) < 0:
						ok = false
						break
				if not ok:
					continue
			out.append(id)
		match _sort.selected:
			0:
				out.sort_custom(func(x, y): return int(d[x].get("download_count", 0)) > int(d[y].get("download_count", 0)))
			1:
				out.sort_custom(func(x, y): return int(d[x].get("date_published", 0)) > int(d[y].get("date_published", 0)))
			_:
				out.sort_custom(func(x, y): return str(d[x].get("name", x)).naturalnocasecmp_to(str(d[y].get("name", y))) < 0)
		_list = out
		_clear_grid()
		if out.is_empty():
			_empty_label.text = "Nothing found. Try another search or category."
			_empty_box.show()
			_more.hide()
			_set_status("0 results")
			return
		_empty_box.hide()
		_show_more()
		_scroll.scroll_vertical = 0
		var dl := 0
		for id in out:
			if _is_downloaded(id):
				dl += 1
		_set_status("%d %s  ·  %d downloaded in this project" % [out.size(), _type_label(_type), dl])

	func _clear_grid() -> void:
		for c in _grid.get_children():
			c.queue_free()
		_cards.clear()
		_shown = 0

	func _show_more() -> void:
		var tok := _token
		var end: int = min(_list.size(), _shown + PAGE)
		for i in range(_shown, end):
			_add_card(_list[i], tok)
		_shown = end
		_more.visible = _shown < _list.size()
		_more.text = "Show more  (%d left)" % (_list.size() - _shown)

	# ------------------------------------------------------------------------- cards
	func _card_width() -> float:
		var w: float = max(UI.px(160), _grid.size.x)
		var sep := UI.px(14)
		return floor((w - sep * (_cols - 1)) / _cols)

	func _add_card(id: String, tok: int) -> void:
		var a: Dictionary = _data[_type][id]
		var card := Button.new()
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.focus_mode = Control.FOCUS_NONE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("normal", UI.box(UI.CARD, 16.0, UI.LINE, 1.0, 0.0, 0.0))
		card.add_theme_stylebox_override("hover", UI.box(UI.CARD_HOVER, 16.0, UI.LINE.lightened(0.15), 1.0, 0.0, 0.0))
		card.add_theme_stylebox_override("pressed", UI.box(UI.CARD_HOVER, 16.0, UI.ACCENT, 2.0, 0.0, 0.0))
		card.add_theme_stylebox_override("hover_pressed", UI.box(UI.CARD_HOVER, 16.0, UI.ACCENT, 2.0, 0.0, 0.0))
		card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		card.toggle_mode = true
		card.button_pressed = id == _sel_id
		var thumb_h := UI.px(120)
		card.custom_minimum_size = Vector2(UI.px(150), thumb_h + UI.px(78))
		card.pressed.connect(_select.bind(id))
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		card.add_child(v)
		var img_holder := PanelContainer.new()
		img_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var ih := UI.box(Color("0a0c12"), 16.0, Color(0, 0, 0, 0), 0.0, 0.0, 0.0)
		ih.corner_radius_bottom_left = 0
		ih.corner_radius_bottom_right = 0
		img_holder.add_theme_stylebox_override("panel", ih)
		img_holder.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		v.add_child(img_holder)
		var tr := TextureRect.new()
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.custom_minimum_size.y = thumb_h
		img_holder.add_child(tr)
		var overlay := MarginContainer.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right", "top", "bottom"]:
			overlay.add_theme_constant_override("margin_" + side, UI.px(8))
		img_holder.add_child(overlay)
		var ov := VBoxContainer.new()
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(ov)
		var badge_row := HBoxContainer.new()
		badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_row.alignment = BoxContainer.ALIGNMENT_END
		ov.add_child(badge_row)
		var badge := UI.chip("✓ Downloaded", UI.GOOD, 11)
		badge.add_theme_stylebox_override("normal", UI.box(Color(0.04, 0.12, 0.08, 0.85), 99.0, UI.GOOD, 1.0, 8.0, 2.0))
		badge.visible = _is_downloaded(id)
		badge_row.add_child(badge)
		var fill := Control.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ov.add_child(fill)
		var prog := ProgressBar.new()
		UI.style_progress(prog)
		prog.custom_minimum_size.y = UI.px(6)
		prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prog.visible = _jobs.has(id)
		ov.add_child(prog)
		var info := MarginContainer.new()
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_theme_constant_override("margin_left", UI.px(12))
		info.add_theme_constant_override("margin_right", UI.px(12))
		info.add_theme_constant_override("margin_top", UI.px(9))
		info.add_theme_constant_override("margin_bottom", UI.px(10))
		v.add_child(info)
		var iv := VBoxContainer.new()
		iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		iv.add_theme_constant_override("separation", UI.px(2))
		info.add_child(iv)
		var nl := UI.label(str(a.get("name", id)), 15, UI.TEXT, true)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		iv.add_child(nl)
		var authors := PackedStringArray((a.get("authors", {}) as Dictionary).keys())
		var cats: Array = a.get("categories", [])
		var meta := "by " + (authors[0] if authors.size() > 0 else "Poly Haven")
		if cats.size() > 0:
			meta += "  ·  " + str(cats[0]).capitalize()
		var ml := UI.label(meta, 12, UI.MUTED)
		ml.clip_text = true
		ml.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		ml.mouse_filter = Control.MOUSE_FILTER_IGNORE
		iv.add_child(ml)
		_grid.add_child(card)
		_cards[id] = {"card": card, "tex": tr, "badge": badge, "prog": prog}
		_size_card(_cards[id])
		_load_thumb(id, a, tr, tok)

	func _load_thumb(id: String, a: Dictionary, tr: TextureRect, tok: int) -> void:
		var w := 512
		var h := 256 if _type == "hdris" else 512
		var t: Texture2D = await client.get_thumb(id, client.thumb_url(id, a, w, h), "%dx%d" % [w, h])
		if tok != _token or not is_instance_valid(tr):
			return
		if t:
			tr.texture = t
			tr.modulate = Color(1, 1, 1, 0)
			var tw := tr.create_tween()
			tw.tween_property(tr, "modulate:a", 1.0, 0.25)

	func _thumb_ratio() -> float:
		return 0.5 if _type == "hdris" else 0.72

	func _size_card(c: Dictionary) -> void:
		var w := _card_width()
		var th := floorf(w * _thumb_ratio())
		(c.tex as TextureRect).custom_minimum_size.y = th
		(c.card as Button).custom_minimum_size = Vector2(UI.px(150), th + UI.px(78))

	func _on_resized() -> void:
		if _grid == null:
			return
		var narrow := size.x < UI.px(980)
		if narrow != _narrow:
			_narrow = narrow
			if _narrow:
				_preview.visible = _sel_id != ""
				_scroll.get_parent().visible = _sel_id == ""
				_pv_back.visible = true
				_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			else:
				_preview.visible = true
				_scroll.get_parent().visible = true
				_pv_back.visible = false
				_preview.size_flags_horizontal = Control.SIZE_FILL
		var avail: float = size.x - (0.0 if _narrow else _preview.size.x + UI.px(14)) - UI.px(36)
		var target := UI.px(205)
		_cols = clampi(int(avail / target), 2, 8)
		_grid.columns = _cols
		await get_tree().process_frame
		for k in _cards:
			_size_card(_cards[k])

	# ------------------------------------------------------------------------- preview
	func _select(id: String) -> void:
		_sel_id = id
		for k in _cards:
			(_cards[k].card as Button).set_pressed_no_signal(k == id)
		var a: Dictionary = _data[_type][id]
		_pv_name.text = str(a.get("name", id))
		var authors := PackedStringArray((a.get("authors", {}) as Dictionary).keys())
		_pv_author.text = "by " + (", ".join(authors) if authors.size() > 0 else "Poly Haven")
		for c in _pv_chips.get_children():
			c.queue_free()
		_pv_chips.add_child(UI.chip("CC0  ·  free for any use", UI.GOOD))
		for c in (a.get("categories", []) as Array).slice(0, 3):
			_pv_chips.add_child(UI.chip(str(c).capitalize(), UI.MUTED))
		if _type == "hdris" and a.has("max_resolution"):
			var mr: Array = a["max_resolution"]
			if mr.size() > 0:
				_pv_chips.add_child(UI.chip("up to %dK" % int(round(float(mr[0]) / 1024.0)), UI.ACCENT))
		if _type == "models" and a.has("polycount"):
			_pv_chips.add_child(UI.chip("%s tris" % _fmt_int(int(a["polycount"])), UI.ACCENT))
		if _is_downloaded(id):
			_pv_chips.add_child(UI.chip("✓ Downloaded", UI.GOOD))
		var tags: Array = a.get("tags", [])
		_pv_tags.text = ("Tags: " + ", ".join(PackedStringArray(tags.slice(0, 10)))) if tags.size() > 0 else ""
		_pv_credit.text = "Credit (appreciated, not required): \"%s\" by %s, Poly Haven, CC0. A CREDIT.txt is saved next to the files." % [a.get("name", id), ", ".join(authors) if authors.size() > 0 else "Poly Haven"]
		_pv_get.text = "Import into scene" if _is_downloaded(id) else "Download & Import"
		_pv_get.disabled = true
		_pv_dl_only.disabled = true
		_pv_dl_only.visible = not _is_downloaded(id)
		_pv_res.clear()
		_pv_res.add_item("Loading sizes…")
		_pv_size.text = ""
		if _cards.has(id):
			_pv_img.texture = (_cards[id].tex as TextureRect).texture
		if _narrow:
			_scroll.get_parent().visible = false
			_preview.visible = true
		# Sharp big preview + file list.
		var tok := _token
		var big: Texture2D = await client.get_thumb(id, client.thumb_url(id, a, 1024, 512 if _type == "hdris" else 1024), "big")
		if _sel_id == id and big and tok == _token:
			_pv_img.texture = big
		var files = await client.get_files(id)
		if _sel_id != id:
			return
		_sel_files = files if files is Dictionary else {}
		_fill_res_options()
		_pv_get.disabled = _sel_files.is_empty() and not _is_downloaded(id)
		_pv_dl_only.disabled = _sel_files.is_empty()

	func _close_preview() -> void:
		if _narrow:
			_preview.visible = false
			_scroll.get_parent().visible = true
		_sel_id = ""
		for k in _cards:
			(_cards[k].card as Button).set_pressed_no_signal(false)

	func _main_file_block() -> Dictionary:
		match _type:
			"hdris":
				return _sel_files.get("hdri", {})
			"models":
				return _sel_files.get("gltf", {})
			_:
				return _sel_files.get("Diffuse", {})

	func _fill_res_options() -> void:
		_pv_res.clear()
		var block := _main_file_block()
		var keys: Array = block.keys()
		keys.sort_custom(func(x, y): return int(str(x).trim_suffix("k")) < int(str(y).trim_suffix("k")))
		if keys.is_empty():
			_pv_res.add_item("No files")
			return
		for k in keys:
			_pv_res.add_item(str(k).to_upper())
			_pv_res.set_item_metadata(_pv_res.item_count - 1, str(k))
		_sync_preview_res()

	func _sync_preview_res() -> void:
		if _pv_res.item_count == 0 or _pv_res.get_item_metadata(0) == null:
			return
		var want: String = RES_ALL[_res.selected]
		var best := 0
		for i in _pv_res.item_count:
			var k := str(_pv_res.get_item_metadata(i))
			if int(k.trim_suffix("k")) <= int(want.trim_suffix("k")):
				best = i
		_pv_res.select(best)
		_update_size_label()

	func _chosen_res() -> String:
		if _pv_res.item_count == 0 or _pv_res.get_item_metadata(_pv_res.selected) == null:
			return RES_ALL[_res.selected]
		return str(_pv_res.get_item_metadata(_pv_res.selected))

	func _update_size_label() -> void:
		var jobs := _plan_jobs(_chosen_res())
		var total := 0.0
		for j in jobs:
			total += float(j.size)
		_pv_size.text = ("%d files  ·  %s download" % [jobs.size(), UI.human_size(total)]) if jobs.size() > 0 else ""

	static func _fmt_int(n: int) -> String:
		var s := str(n)
		var out := ""
		while s.length() > 3:
			out = "," + s.right(3) + out
			s = s.left(s.length() - 3)
		return s + out

	# ------------------------------------------------------------------------- download + import
	func _asset_dir(type: String, id: String) -> String:
		return ROOT_DIR.path_join(type).path_join(id.validate_filename())

	func _is_downloaded(id: String) -> bool:
		return FileAccess.file_exists(_asset_dir(_type, id).path_join("CREDIT.txt"))

	## [{url, path, size, key}] for the chosen resolution.
	func _plan_jobs(res: String) -> Array:
		var jobs: Array = []
		var dir := _asset_dir(_type, _sel_id)
		match _type:
			"hdris":
				var h: Dictionary = _sel_files.get("hdri", {})
				if h.has(res) and (h[res] as Dictionary).has("hdr"):
					var f: Dictionary = h[res]["hdr"]
					jobs.append({"url": f.url, "path": dir.path_join(str(f.url).get_file()), "size": f.get("size", 0), "key": "hdri"})
			"textures":
				var maps := {"Diffuse": "albedo", "nor_gl": "normal", "Rough": "roughness", "AO": "ao"}
				if _quality == 0:
					maps["Displacement"] = "height"
				for k in maps:
					if not _sel_files.has(k):
						continue
					var block: Dictionary = _sel_files[k]
					var r := res if block.has(res) else _closest(block, res)
					if r == "":
						continue
					var fm: Dictionary = block[r]
					var e: Dictionary = fm.get("jpg", fm.get("png", {}))
					if e.is_empty():
						continue
					jobs.append({"url": e.url, "path": dir.path_join(str(e.url).get_file()), "size": e.get("size", 0), "key": maps[k]})
			"models":
				var g: Dictionary = _sel_files.get("gltf", {})
				var r2 := res if g.has(res) else _closest(g, res)
				if r2 != "":
					var main: Dictionary = g[r2]["gltf"]
					jobs.append({"url": main.url, "path": dir.path_join(str(main.url).get_file()), "size": main.get("size", 0), "key": "model"})
					var inc: Dictionary = main.get("include", {})
					for rel in inc:
						jobs.append({"url": inc[rel].url, "path": dir.path_join(str(rel)), "size": inc[rel].get("size", 0), "key": ""})
		return jobs

	static func _closest(block: Dictionary, want: String) -> String:
		var best := ""
		var wv := int(want.trim_suffix("k"))
		var bd := 1 << 30
		for k in block:
			var d: int = abs(int(str(k).trim_suffix("k")) - wv)
			if d < bd:
				bd = d
				best = str(k)
		return best

	func _get_selected(do_import: bool) -> void:
		var id := _sel_id
		var type := _type
		if id == "" or _jobs.has(id):
			return
		var a: Dictionary = _data[type][id]
		var res := _chosen_res()
		var jobs := _plan_jobs(res)
		if jobs.is_empty() and not _is_downloaded(id):
			_toast("No downloadable files for %s at %s." % [a.get("name", id), res.to_upper()], 1)
			return
		_jobs[id] = {"done": 0.0, "total": 0.0, "files": {}}
		for j in jobs:
			_jobs[id].total += float(j.size)
		_pv_get.disabled = true
		_pv_dl_only.disabled = true
		_pv_progress.show()
		_pv_progress.value = 0
		if _cards.has(id):
			_cards[id].prog.show()
		var result := {"main": "", "maps": {}}
		var failed := ""
		var pending := [jobs.size()]
		for j in jobs:
			if j.key == "hdri" or j.key == "model":
				result.main = j.path
			elif j.key != "":
				result.maps[j.key] = j.path
		# Up to 4 files in parallel (the client enforces the global limit).
		for j in jobs:
			_download_one(id, j, pending, func(err):
				if err != "" and failed == "":
					failed = err)
		while pending[0] > 0:
			await get_tree().process_frame
		_jobs.erase(id)
		_pv_progress.hide()
		if _cards.has(id):
			_cards[id].prog.hide()
		if failed != "":
			_toast("Download failed: %s" % failed, 2)
			_pv_get.disabled = false
			_pv_dl_only.disabled = false
			return
		if jobs.size() > 0:
			_write_credit(type, id, a, res)
		if _cards.has(id):
			_cards[id].badge.show()
		if result.main == "" and result.maps.is_empty():
			result = _find_existing(type, id)
		_set_status("Importing %s…" % a.get("name", id))
		var ok := await _wait_import(result)
		if not ok:
			_toast("%s downloaded, but the import is still running. Tap Import again in a moment." % a.get("name", id), 1)
		elif do_import:
			_apply(type, id, a, result)
		else:
			_toast("%s saved to %s" % [a.get("name", id), _asset_dir(type, id)], 0)
		if _sel_id == id:
			_select(id)

	func _download_one(id: String, j: Dictionary, pending: Array, done_cb: Callable) -> void:
		var err := ""
		if not FileAccess.file_exists(j.path):
			var r: Dictionary = await client.request(j.url, j.path, false, id + "|" + j.path)
			if not r.ok:
				err = "HTTP %s on %s" % [r.code, str(j.url).get_file()]
		if _jobs.has(id):
			_jobs[id].files[j.path] = float(j.size)
			_update_job_progress(id)
		pending[0] -= 1
		done_cb.call(err)

	func _on_file_progress(key: String, done: float, _total: float) -> void:
		var id := key.get_slice("|", 0)
		var path := key.substr(id.length() + 1)
		if _jobs.has(id):
			_jobs[id].files[path] = done
			_update_job_progress(id)

	func _update_job_progress(id: String) -> void:
		var j: Dictionary = _jobs[id]
		var sum := 0.0
		for p in j.files:
			sum += float(j.files[p])
		var pct := 0.0 if j.total <= 0.0 else clampf(sum / j.total * 100.0, 0.0, 100.0)
		if _cards.has(id):
			_cards[id].prog.value = pct
		if id == _sel_id:
			_pv_progress.value = pct
		_set_status("Downloading %s  ·  %d%%  (%s / %s)" % [id, int(pct), UI.human_size(sum), UI.human_size(j.total)])
		_status_bar.show()
		_status_bar.value = pct
		if pct >= 100.0:
			_status_bar.hide()

	func _find_existing(type: String, id: String) -> Dictionary:
		var dir := _asset_dir(type, id)
		var out := {"main": "", "maps": {}}
		var files := _list_files(dir)
		for f in files:
			var low := f.to_lower()
			if type == "hdris" and (low.ends_with(".hdr") or low.ends_with(".exr")):
				out.main = f
			elif type == "models" and low.ends_with(".gltf"):
				out.main = f
			elif type == "textures":
				if low.find("_diff_") >= 0:
					out.maps["albedo"] = f
				elif low.find("_nor_gl_") >= 0:
					out.maps["normal"] = f
				elif low.find("_rough_") >= 0:
					out.maps["roughness"] = f
				elif low.find("_ao_") >= 0:
					out.maps["ao"] = f
				elif low.find("_disp_") >= 0 and _quality == 0:
					out.maps["height"] = f
		return out

	func _list_files(dir: String) -> PackedStringArray:
		var out := PackedStringArray()
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".import") and not f.ends_with(".part"):
				out.append(dir.path_join(f))
		for sub in DirAccess.get_directories_at(dir):
			out.append_array(_list_files(dir.path_join(sub)))
		return out

	func _write_credit(type: String, id: String, a: Dictionary, res: String) -> void:
		var f := FileAccess.open(_asset_dir(type, id).path_join("CREDIT.txt"), FileAccess.WRITE)
		if f == null:
			return
		var authors := PackedStringArray((a.get("authors", {}) as Dictionary).keys())
		f.store_string("%s (%s, %s)\nAuthor(s): %s\nSource: https://polyhaven.com/a/%s\nLicense: CC0 1.0 (public domain) - Poly Haven\nDownloaded with CHoMU Store %s\n" % [
			a.get("name", id), type, res.to_upper(), ", ".join(authors), id, STORE_VERSION])

	## Lets the editor import the new files, then waits until the main resource is loadable.
	func _wait_import(result: Dictionary) -> bool:
		var paths: Array = []
		if result.main != "":
			paths.append(result.main)
		for k in result.maps:
			paths.append(result.maps[k])
		if paths.is_empty():
			return false
		var efs := EditorInterface.get_resource_filesystem()
		var need := false
		for p in paths:
			if not ResourceLoader.exists(p):
				need = true
		if not need:
			return true
		# Let the editor notice the new files on its own first; only scan if it hasn't started.
		await get_tree().create_timer(0.5, true, false, true).timeout
		if not efs.is_scanning():
			efs.scan()
		var t := 0.0
		while t < 600.0:
			await get_tree().create_timer(0.3, true, false, true).timeout
			t += 0.3
			if efs.is_scanning():
				continue
			var all_ok := true
			for p in paths:
				if not ResourceLoader.exists(p):
					all_ok = false
			if all_ok:
				return true
			# A file that is still missing after a scan settled: ask once more (rarely needed).
			if fmod(t, 20.0) < 0.31 and not efs.is_scanning():
				efs.scan()
		return false

	func _apply(type: String, id: String, a: Dictionary, result: Dictionary) -> void:
		var root := EditorInterface.get_edited_scene_root()
		var name := str(a.get("name", id))
		match type:
			"hdris":
				var env := _make_environment(result.main, id)
				if env == null:
					_toast("Couldn't load the HDRI texture.", 2)
					return
				if root == null:
					_toast("Sky saved as %s. Open a 3D scene and import again to apply it." % env.resource_path, 1)
					return
				_apply_environment(root, env, name)
			"textures":
				var mat := _make_material(result.maps, id)
				if root == null:
					_toast("Material saved as %s." % mat.resource_path, 0)
					return
				_apply_material(root, mat, name)
			"models":
				var ps = load(result.main)
				if not (ps is PackedScene):
					_toast("Couldn't load the model scene.", 2)
					return
				if root == null:
					_toast("Model imported at %s. Open a scene to place it." % result.main, 0)
					return
				_add_model(root, ps, name)
		EditorInterface.mark_scene_as_unsaved()

	func _make_environment(hdr_path: String, id: String) -> Environment:
		var tex = load(hdr_path)
		if not (tex is Texture2D):
			return null
		var high := _quality == 0
		var method := RenderingServer.get_current_rendering_method()
		var sky_mat := PanoramaSkyMaterial.new()
		sky_mat.panorama = tex
		sky_mat.filter = true
		var sky := Sky.new()
		sky.sky_material = sky_mat
		sky.radiance_size = Sky.RADIANCE_SIZE_256 if high else Sky.RADIANCE_SIZE_64
		sky.process_mode = Sky.PROCESS_MODE_QUALITY if high else Sky.PROCESS_MODE_INCREMENTAL
		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.tonemap_mode = Environment.TONE_MAPPER_AGX if high else Environment.TONE_MAPPER_FILMIC
		env.tonemap_white = 6.0
		if high:
			env.glow_enabled = method != "gl_compatibility"
			env.glow_intensity = 0.6
			env.glow_bloom = 0.05
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			if method == "forward_plus":
				env.ssao_enabled = true
				env.ssao_radius = 1.2
				env.ssao_intensity = 1.6
				env.ssr_enabled = true
				env.ssr_max_steps = 64
				env.ssil_enabled = false
		var path := _asset_dir("hdris", id).path_join(id.validate_filename() + "_environment.tres")
		var err := ResourceSaver.save(env, path)
		if err == OK:
			env.take_over_path(path)
		return env

	func _apply_environment(root: Node, env: Environment, name: String) -> void:
		var ur := plugin.get_undo_redo()
		var we := _find_first(root, "WorldEnvironment") as WorldEnvironment
		ur.create_action("CHoMU Store: Sky \"%s\"" % name)
		if we:
			ur.add_do_property(we, "environment", env)
			ur.add_undo_property(we, "environment", we.environment)
		else:
			we = WorldEnvironment.new()
			we.name = "Sky"
			we.environment = env
			ur.add_do_method(root, "add_child", we, true)
			ur.add_do_method(we, "set_owner", root)
			ur.add_do_reference(we)
			ur.add_undo_method(root, "remove_child", we)
		var sun_added := false
		if root is Node3D and _find_first(root, "DirectionalLight3D") == null:
			var sun := DirectionalLight3D.new()
			sun.name = "Sun"
			sun.shadow_enabled = true
			sun.light_energy = 1.0
			sun.rotation_degrees = Vector3(-50, 35, 0)
			if _quality == 0:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			else:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			ur.add_do_method(root, "add_child", sun, true)
			ur.add_do_method(sun, "set_owner", root)
			ur.add_do_reference(sun)
			ur.add_undo_method(root, "remove_child", sun)
			sun_added = true
		ur.commit_action()
		var fx := "SSAO + SSR + glow" if (_quality == 0 and RenderingServer.get_current_rendering_method() == "forward_plus") else ("glow" if _quality == 0 else "light mode")
		_toast("Sky \"%s\" applied (%s%s)." % [name, fx, ", sun added" if sun_added else ""], 0)

	func _make_material(maps: Dictionary, id: String) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.resource_name = id
		if maps.has("albedo"):
			m.albedo_texture = load(maps.albedo)
		if maps.has("normal"):
			m.normal_enabled = true
			m.normal_texture = load(maps.normal)
		if maps.has("roughness"):
			m.roughness_texture = load(maps.roughness)
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			m.roughness = 1.0
		if maps.has("ao"):
			m.ao_enabled = true
			m.ao_texture = load(maps.ao)
			m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		if maps.has("height") and _quality == 0:
			m.heightmap_enabled = true
			m.heightmap_texture = load(maps.height)
			m.heightmap_scale = 1.5
			m.heightmap_deep_parallax = true
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var path := _asset_dir("textures", id).path_join(id.validate_filename() + "_material.tres")
		if ResourceSaver.save(m, path) == OK:
			m.take_over_path(path)
		return m

	func _apply_material(root: Node, mat: Material, name: String) -> void:
		var targets: Array = []
		for n in EditorInterface.get_selection().get_selected_nodes():
			if n is GeometryInstance3D:
				targets.append(n)
		var ur := plugin.get_undo_redo()
		ur.create_action("CHoMU Store: Material \"%s\"" % name)
		if targets.size() > 0:
			for n in targets:
				ur.add_do_property(n, "material_override", mat)
				ur.add_undo_property(n, "material_override", n.material_override)
			ur.commit_action()
			_toast("Material \"%s\" applied to %d selected object(s)." % [name, targets.size()], 0)
			return
		var parent := root
		var mi := MeshInstance3D.new()
		mi.name = name.validate_node_name().replace(" ", "")
		var sm := SphereMesh.new()
		sm.radial_segments = 96
		sm.rings = 48
		mi.mesh = sm
		mi.material_override = mat
		ur.add_do_method(parent, "add_child", mi, true)
		ur.add_do_method(mi, "set_owner", root)
		ur.add_do_reference(mi)
		ur.add_undo_method(parent, "remove_child", mi)
		ur.commit_action()
		_toast("Material \"%s\" created. Select a mesh and import again to apply it there." % name, 0)

	func _add_model(root: Node, ps: PackedScene, name: String) -> void:
		var inst := ps.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		if inst == null:
			_toast("Couldn't instance the model.", 2)
			return
		inst.name = name.validate_node_name().replace(" ", "")
		var ur := plugin.get_undo_redo()
		ur.create_action("CHoMU Store: Add model \"%s\"" % name)
		ur.add_do_method(root, "add_child", inst, true)
		ur.add_do_method(inst, "set_owner", root)
		ur.add_do_reference(inst)
		ur.add_undo_method(root, "remove_child", inst)
		ur.commit_action()
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(inst)
		_toast("Model \"%s\" added to the scene." % name, 0)

	func _find_first(n: Node, cls: String) -> Node:
		if n.is_class(cls):
			return n
		for c in n.get_children():
			var f := _find_first(c, cls)
			if f:
				return f
		return null

	func _toast(msg: String, severity := 0) -> void:
		_set_status(msg)
		if EditorInterface.has_method("get_editor_toaster"):
			var t = EditorInterface.call("get_editor_toaster")
			if t and t.has_method("push_toast"):
				t.push_toast(msg, severity)
				return
		print("CHoMU Store: ", msg)

	# ------------------------------------------------------------------------- Looks tab (CHoMU 1.3)
	func _looks_helper():
		if _looks == null:
			var path: String = plugin.get_script().resource_path.get_base_dir().path_join("chomu_looks.gd")
			var scr = load(path)
			if scr == null:
				return null
			_looks = scr.new()
			_looks.plugin = plugin
			_looks.host = self
		return _looks

	func _build_looks(root: VBoxContainer) -> void:
		_looks_box = VBoxContainer.new()
		_looks_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_looks_box.add_theme_constant_override("separation", UI.px(10))
		_looks_box.hide()
		root.add_child(_looks_box)
		root.move_child(_looks_box, _body.get_index() + 1)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", UI.px(10))
		row.add_theme_constant_override("v_separation", UI.px(8))
		_looks_box.add_child(row)
		_looks_cat = OptionButton.new()
		_looks_cat.custom_minimum_size.x = UI.px(190)
		UI.style_option(_looks_cat)
		_looks_cat.item_selected.connect(func(_i): _fill_looks())
		row.add_child(_labeled("Category", _looks_cat))
		_looks_mode = OptionButton.new()
		_looks_mode.add_item("Auto (match renderer)", 0)
		_looks_mode.add_item("Full quality", 1)
		_looks_mode.add_item("Mobile fallback", 2)
		_looks_mode.custom_minimum_size.x = UI.px(210)
		_looks_mode.tooltip_text = "Full = every effect the look has (SDFGI, SSIL, SSR, volumetric fog on Forward+).\nMobile fallback = the look's _mobile version: no Forward+-only effects, light sky, cheap post FX.\nAuto picks Mobile fallback when the project uses the Mobile / Compatibility renderer."
		UI.style_option(_looks_mode)
		var es := EditorInterface.get_editor_settings()
		if es.has_setting("chomu_store/looks_mode"):
			_looks_mode.select(int(es.get_setting("chomu_store/looks_mode")))
		_looks_mode.item_selected.connect(func(i):
			EditorInterface.get_editor_settings().set_setting("chomu_store/looks_mode", i)
			_update_looks_info())
		row.add_child(_labeled("Quality", _looks_mode))
		_looks_info = UI.label("", 13, UI.MUTED)
		_looks_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_looks_box.add_child(_looks_info)
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.scroll_deadzone = UI.px(10)
		_looks_box.add_child(sc)
		_looks_grid = GridContainer.new()
		_looks_grid.columns = 3
		_looks_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_looks_grid.add_theme_constant_override("h_separation", UI.px(14))
		_looks_grid.add_theme_constant_override("v_separation", UI.px(14))
		sc.add_child(_looks_grid)
		resized.connect(_size_looks)

	func _show_looks(on: bool) -> void:
		if _looks_box == null:
			return
		_looks_box.visible = on
		_filters.visible = not on
		_body.visible = not on
		if on:
			if _looks_cat.item_count == 0:
				var L = _looks_helper()
				if L:
					for c in L.categories():
						_looks_cat.add_item(c)
			_fill_looks()

	func _look_mobile() -> bool:
		match _looks_mode.selected:
			1:
				return false
			2:
				return true
		var L = _looks_helper()
		return L.auto_mobile() if L else false

	func _update_looks_info() -> void:
		var L = _looks_helper()
		if L == null:
			return
		var r: String = L.project_renderer()
		var names := {"forward_plus": "Forward+", "mobile": "Mobile", "gl_compatibility": "Compatibility"}
		var m := _look_mobile()
		_looks_info.text = "Applies to the open scene: sky, WorldEnvironment, sun, post FX%s. Undo with Ctrl+Z.   Project renderer: %s  ·  Using: %s" % [
			" and cel shading for anime looks", names.get(r, r), "Mobile fallback" if m else "Full quality"]
		for k in _looks_cards:
			var c: Dictionary = _looks_cards[k]
			(c.mode as Label).text = "Mobile fallback" if m else "Full quality"

	func _fill_looks() -> void:
		var L = _looks_helper()
		for c in _looks_grid.get_children():
			c.queue_free()
		_looks_cards.clear()
		if L == null:
			_set_status("Looks are not available (chomu_looks.gd missing).")
			return
		var cat := _looks_cat.get_item_text(_looks_cat.selected) if _looks_cat.selected >= 0 else "All"
		var q := _search.text.strip_edges().to_lower()
		var table: Dictionary = L.all()
		var n := 0
		for look in L.order():
			var p: Dictionary = table[look]
			if cat != "All" and L.category(look) != cat:
				continue
			if q != "" and (look + " " + str(p.get("desc", ""))).to_lower().find(q) < 0:
				continue
			_add_look_card(look, p)
			n += 1
		_update_looks_info()
		_size_looks()
		if not L.content_ok():
			_set_status("Look files not unpacked yet (%s). Restart the editor once." % L.content_dir())
		else:
			_set_status("%d looks  ·  open a 3D scene and tap Apply" % n)

	func _add_look_card(look: String, p: Dictionary) -> void:
		var L = _looks_helper()
		var special := str(p.get("badge", "")) != ""
		var sw: Array = p.get("swatch", [UI.CARD, UI.PANEL])
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UI.box(UI.CARD, 16.0, (sw[0] as Color) if special else UI.LINE, 2.0 if special else 1.0, 0.0, 0.0))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		card.add_child(v)
		var img_holder := PanelContainer.new()
		var ih := UI.box(Color("0a0c12"), 16.0, Color(0, 0, 0, 0), 0.0, 0.0, 0.0)
		ih.corner_radius_bottom_left = 0
		ih.corner_radius_bottom_right = 0
		img_holder.add_theme_stylebox_override("panel", ih)
		img_holder.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		v.add_child(img_holder)
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.custom_minimum_size.y = UI.px(130)
		var tp: String = L.thumb_path(look)
		var tex: Texture2D = null
		if FileAccess.file_exists(tp):
			var img := Image.load_from_file(tp)
			if img and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
		if tex == null:
			var g := Gradient.new()
			g.set_color(0, sw[0])
			g.set_color(1, sw[1])
			var gt := GradientTexture2D.new()
			gt.gradient = g
			gt.fill_to = Vector2(1, 1)
			tex = gt
		tr.texture = tex
		img_holder.add_child(tr)
		var ov := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			ov.add_theme_constant_override("margin_" + side, UI.px(8))
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img_holder.add_child(ov)
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", UI.px(6))
		chips.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ov.add_child(chips)
		if special:
			var b := UI.chip("★ " + str(p.badge), Color.WHITE, 11)
			b.add_theme_stylebox_override("normal", UI.box(Color(sw[0].r, sw[0].g, sw[0].b, 0.85), 99.0, Color.WHITE, 1.0, 8.0, 2.0))
			chips.add_child(b)
		if str(p.get("toon", "")) != "":
			chips.add_child(_dark_chip("Cel + outlines"))
		var info := MarginContainer.new()
		for side in ["left", "right"]:
			info.add_theme_constant_override("margin_" + side, UI.px(12))
		info.add_theme_constant_override("margin_top", UI.px(9))
		info.add_theme_constant_override("margin_bottom", UI.px(10))
		v.add_child(info)
		var iv := VBoxContainer.new()
		iv.add_theme_constant_override("separation", UI.px(4))
		info.add_child(iv)
		iv.add_child(UI.label(look, 16, UI.TEXT, true))
		var d := UI.label(str(p.get("desc", "")), 12, UI.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.y = UI.px(34)
		iv.add_child(d)
		var fx: PackedStringArray = L.forward_extras(look)
		var fxl := UI.label(("Forward+: " + ", ".join(fx)) if fx.size() > 0 else "Runs the same on every renderer", 11, UI.WARN if fx.size() > 0 else UI.GOOD)
		fxl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		iv.add_child(fxl)
		var brow := HBoxContainer.new()
		brow.add_theme_constant_override("separation", UI.px(8))
		iv.add_child(brow)
		var mode := UI.label("", 11, UI.MUTED)
		mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		brow.add_child(mode)
		var apply := Button.new()
		apply.text = "Apply"
		UI.style_button(apply, true, 15)
		apply.custom_minimum_size.x = UI.px(110)
		apply.pressed.connect(_apply_look.bind(look))
		brow.add_child(apply)
		_looks_grid.add_child(card)
		_looks_cards[look] = {"card": card, "tex": tr, "button": apply, "mode": mode}

	func _dark_chip(t: String) -> Label:
		var c := UI.chip(t, Color.WHITE, 11)
		c.add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0.6), 99.0, Color(1, 1, 1, 0.35), 1.0, 8.0, 2.0))
		return c

	func _size_looks() -> void:
		if _looks_grid == null or not _looks_box.visible:
			return
		var avail: float = size.x - UI.px(36)
		var cols := clampi(int(avail / UI.px(300)), 1, 5)
		_looks_grid.columns = cols
		var w := floorf((avail - UI.px(14) * (cols - 1)) / cols)
		for k in _looks_cards:
			(_looks_cards[k].tex as TextureRect).custom_minimum_size.y = floorf(w * 0.5)

	func _apply_look(look: String) -> void:
		if _looks_busy:
			return
		var L = _looks_helper()
		if EditorInterface.get_edited_scene_root() == null:
			_toast("Open a scene first, then apply \"%s\"." % look, 1)
			return
		if not L.content_ok():
			_toast("Look files are missing - restart the editor once to unpack them.", 2)
			return
		_looks_busy = true
		for k in _looks_cards:
			(_looks_cards[k].button as Button).disabled = true
		(_looks_cards[look].button as Button).text = "Applying…"
		_set_status("Applying %s…" % look)
		var msg: String = await L.apply(look, _look_mobile())
		_looks_busy = false
		for k in _looks_cards:
			(_looks_cards[k].button as Button).disabled = false
			(_looks_cards[k].button as Button).text = "Apply"
		if is_instance_valid(_looks_cards.get(look, {}).get("button")):
			(_looks_cards[look].button as Button).text = "✓ Applied"
		if msg == "":
			_toast("Couldn't apply %s (see Output)." % look, 2)
		else:
			_toast(msg, 0)
