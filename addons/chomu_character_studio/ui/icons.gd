@tool
extends RefCounted
## Line icons for the studio, drawn as white SVG and tinted by the theme (blue / teal / orange / grey).
## Built at runtime with Image.load_svg_from_string, so nothing needs importing.

const HEAD := "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='#ffffff' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'>"

const PATHS := {
	"studio": "<circle cx='12' cy='5' r='2.6'/><path d='M12 8v6M7 10.5h10M12 14l-3.5 6M12 14l3.5 6'/><circle cx='19' cy='19' r='2' fill='#ffffff'/>",
	"rig": "<circle cx='6' cy='6' r='2.2'/><circle cx='18' cy='18' r='2.2'/><path d='M7.6 7.6l8.8 8.8'/><circle cx='12' cy='12' r='1.2' fill='#ffffff'/>",
	"anim": "<rect x='3' y='5' width='18' height='14' rx='2'/><path d='M10 9.2v5.6l4.8-2.8z' fill='#ffffff'/>",
	"cloth": "<path d='M8 3h8l1 3c-1 6 1 10 3 15H4c2-5 4-9 3-15z'/><path d='M9 3c0 2 1.5 3 3 3s3-1 3-3'/>",
	"hair": "<path d='M5 4c3 3 0 7 3 10s0 6 0 6M11 4c3 3 0 7 3 10s0 6 0 6M17 4c3 3 0 7 3 10'/>",
	"model": "<path d='M12 2.8l8 4.6v9.2l-8 4.6-8-4.6V7.4z'/><path d='M4 7.4l8 4.6 8-4.6M12 12v9.2'/>",
	"edit": "<path d='M5 18L9 5l10 4-4 10z'/><circle cx='5' cy='18' r='1.7' fill='#ffffff'/><circle cx='9' cy='5' r='1.7' fill='#ffffff'/><circle cx='19' cy='9' r='1.7' fill='#ffffff'/><circle cx='15' cy='19' r='1.7' fill='#ffffff'/>",
	"sculpt": "<path d='M14.5 4.5l5 5-8.5 8.5H6v-5z'/><path d='M12.5 6.5l5 5'/><path d='M3 21h7'/>",
	"weights": "<path d='M12 3c3.5 4.5 6 7.6 6 11a6 6 0 0 1-12 0c0-3.4 2.5-6.5 6-11z'/><path d='M8.8 14.5a3.2 3.2 0 0 0 3.2 3'/>",
	"shapes": "<path d='M4 7h16M4 12h16M4 17h16'/><circle cx='9' cy='7' r='1.9' fill='#ffffff'/><circle cx='15' cy='12' r='1.9' fill='#ffffff'/><circle cx='7' cy='17' r='1.9' fill='#ffffff'/>",
	"pose": "<circle cx='13' cy='4.5' r='2'/><path d='M13 7l-1 6 3 4 1 4M12 13l-4 3-2 5M12.5 9l4.5-2.5M12.5 9.5L8 8'/>",
	"uv": "<rect x='3.5' y='3.5' width='17' height='17' rx='1.5'/><path d='M9.2 3.5v17M14.8 3.5v17M3.5 9.2h17M3.5 14.8h17'/>",
	"modifiers": "<path d='M12 3l9 4.5-9 4.5-9-4.5z'/><path d='M3 12l9 4.5 9-4.5M3 16.5L12 21l9-4.5'/>",
	"material": "<circle cx='12' cy='12' r='8.5'/><path d='M7.5 9.5a5 5 0 0 1 4-3'/><circle cx='15' cy='15' r='1.4' fill='#ffffff'/>",
	"move": "<path d='M12 3v18M3 12h18M12 3l-2.5 2.5M12 3l2.5 2.5M12 21l-2.5-2.5M12 21l2.5-2.5M3 12l2.5-2.5M3 12l2.5 2.5M21 12l-2.5-2.5M21 12l-2.5 2.5'/>",
	"rotate": "<path d='M20 12a8 8 0 1 1-2.4-5.7'/><path d='M20 4v4.5h-4.5'/>",
	"scale": "<rect x='3.5' y='12.5' width='8' height='8' rx='1'/><path d='M13 11l7-7M14.5 4H20v5.5'/>",
	"extrude": "<path d='M4 15l8 4 8-4-8-4z'/><path d='M12 11V3M9 6l3-3 3 3'/>",
	"inset": "<rect x='3.5' y='3.5' width='17' height='17' rx='1.5'/><rect x='8' y='8' width='8' height='8'/><path d='M3.5 3.5L8 8M20.5 3.5L16 8M3.5 20.5L8 16M20.5 20.5L16 16'/>",
	"subdivide": "<rect x='3.5' y='3.5' width='17' height='17' rx='1.5'/><path d='M12 3.5v17M3.5 12h17'/>",
	"delete": "<path d='M4 7h16M9 7V4h6v3M6.5 7l1 13h9l1-13M10 11v6M14 11v6'/>",
	"merge": "<path d='M5 4l7 8 7-8M12 12v8'/><circle cx='12' cy='12' r='1.6' fill='#ffffff'/>",
	"vert": "<path d='M4 18L12 5l8 13z' stroke-opacity='0.45'/><circle cx='12' cy='5' r='2.6' fill='#ffffff'/><circle cx='4' cy='18' r='1.4'/><circle cx='20' cy='18' r='1.4'/>",
	"edgesel": "<path d='M4 18L12 5l8 13z' stroke-opacity='0.45'/><path d='M4 18L12 5' stroke-width='3.2'/>",
	"facesel": "<path d='M4 18L12 5l8 13z' fill='#ffffff' fill-opacity='0.75'/>",
	"apply": "<path d='M4.5 12.5l5 5 10-11'/>",
	"revert": "<path d='M4 12a8 8 0 1 0 2.4-5.7'/><path d='M4 4v4.5h4.5'/>",
	"frame": "<path d='M4 9V4h5M15 4h5v5M20 15v5h-5M9 20H4v-5'/><circle cx='12' cy='12' r='2.5'/>",
	"target": "<circle cx='12' cy='12' r='7.5'/><circle cx='12' cy='12' r='2.5' fill='#ffffff'/><path d='M12 2v3M12 19v3M2 12h3M19 12h3'/>",
	"key": "<path d='M12 3l5 9-5 9-5-9z'/>",
	"add": "<path d='M12 5v14M5 12h14'/>",
	"remove": "<path d='M5 12h14'/>",
	"mirror": "<path d='M12 3v18' stroke-dasharray='2 2'/><path d='M9 6L3 18h6zM15 6l6 12h-6z'/>",
	"array": "<rect x='2.5' y='8' width='5.5' height='8' rx='1'/><rect x='9.25' y='8' width='5.5' height='8' rx='1'/><rect x='16' y='8' width='5.5' height='8' rx='1'/>",
	"ik": "<circle cx='5' cy='19' r='1.8'/><path d='M6.3 17.7L11 9l7 3'/><circle cx='11' cy='9' r='1.5' fill='#ffffff'/><circle cx='19.5' cy='12.5' r='2.2'/>",
	"look": "<path d='M2.5 12s3.5-6.5 9.5-6.5S21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z'/><circle cx='12' cy='12' r='2.8'/>",
	"import": "<path d='M12 3v12M7.5 10.5L12 15l4.5-4.5M4 17v3h16v-3'/>",
	"play": "<path d='M7 4.5v15l12-7.5z'/>",
	"brush": "<path d='M18.5 3.5l2 2-9 9-2-2z'/><path d='M9.5 12.5c-3 0-4 2-4 4s-2 3-2.5 3.5c4 .5 8-1 8.5-5.5'/>",
	"bone": "<circle cx='6' cy='18' r='2.5'/><path d='M7.8 16.2L17 7'/><circle cx='18' cy='6' r='1.5'/>",
	"sphere": "<circle cx='12' cy='12' r='8.5'/><ellipse cx='12' cy='12' rx='8.5' ry='3.2'/><path d='M12 3.5v17'/>",
	"cylinder": "<ellipse cx='12' cy='6' rx='7' ry='2.5'/><path d='M5 6v12c0 1.4 3.1 2.5 7 2.5s7-1.1 7-2.5V6'/>",
	"torus": "<ellipse cx='12' cy='12' rx='9' ry='5.5'/><ellipse cx='12' cy='11.5' rx='3.6' ry='1.6'/>",
	"plane": "<path d='M2.5 15.5L9 8h12.5L15 15.5z'/>",
	"bake": "<path d='M12 3v4M5 7l2.5 2.5M19 7l-2.5 2.5'/><rect x='4' y='12' width='16' height='8' rx='2'/>",
}

static var _cache = {}

static func get_icon(name: String, size := 20) -> Texture2D:
	var key = "%s@%d" % [name, size]
	if _cache.has(key):
		return _cache[key]
	var body: String = PATHS.get(name, PATHS["target"])
	var svg = HEAD + body + "</svg>"
	var img = Image.new()
	var err = img.load_svg_from_string(svg, float(size) / 24.0)
	var tex: Texture2D = null
	if err == OK:
		tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
