extends RefCounted
class_name ChomuWindGrid

## F-57 Wind and Buoyancy (Part 1)
## A CPU-based 3D wind grid that provides spatially interpolated wind velocities.
## Uses time-sliced updates to distribute the cost of noise generation.

var _size: int
var _cell_size: float
var _origin: Vector3
var _grid: Array[Vector3]
var _impulses: Array[Dictionary] # {pos: Vector3, vel: Vector3, radius: float, life: float}

var _noise := FastNoiseLite.new()
var _time := 0.0
var _current_slice := 0

var _base_wind := Vector3(2.0, 0.0, 0.5)

func _init(p_size: int = 16, p_cell: float = 2.0, p_origin: Vector3 = Vector3.ZERO) -> void:
	_size = p_size
	_cell_size = p_cell
	_origin = p_origin
	_grid.resize(_size * _size * _size)
	_noise.seed = randi()
	_noise.frequency = 0.1

func _get_index(x: int, y: int, z: int) -> int:
	return x + y * _size + z * _size * _size

func step(dt: float) -> void:
	_time += dt
	
	# Time-sliced update: update one Z-slice per call to spread CPU load
	for x in range(_size):
		for y in range(_size):
			var idx := _get_index(x, y, _current_slice)
			var world_pos := _origin + Vector3(x * _cell_size, y * _cell_size, _current_slice * _cell_size)
			
			# Base wind + curl-like noise gusts
			var noise_val := _noise.get_noise_3d(world_pos.x + _time, world_pos.y, world_pos.z + _time)
			var gust := Vector3(
				_noise.get_noise_3d(world_pos.y, world_pos.z, world_pos.x + _time),
				_noise.get_noise_3d(world_pos.z, world_pos.x, world_pos.y + _time),
				_noise.get_noise_3d(world_pos.x, world_pos.y, world_pos.z + _time)
			)
			_grid[idx] = _base_wind + (gust * noise_val * 2.0)
	
	_current_slice = (_current_slice + 1) % _size
	
	# Process impulses
	var i := 0
	while i < _impulses.size():
		var imp := _impulses[i]
		imp.life -= dt
		if imp.life <= 0:
			_impulses.remove_at(i)
		else:
			i += 1

func sample(pos: Vector3) -> Vector3:
	var local := (pos - _origin) / _cell_size
	var fx := local.x
	var fy := local.y
	var fz := local.z
	
	var ix := int(floor(fx))
	var iy := int(floor(fy))
	var iz := int(floor(fz))
	
	# Clamp to grid boundaries
	var x0 := clamp(ix, 0, _size - 1)
	var y0 := clamp(iy, 0, _size - 1)
	var z0 := clamp(iz, 0, _size - 1)
	var x1 := clamp(x0 + 1, 0, _size - 1)
	var y1 := clamp(y0 + 1, 0, _size - 1)
	var z1 := clamp(z0 + 1, 0, _size - 1)
	
	var tx = fx - floor(fx)
	var ty = fy - floor(fy)
	var tz = fz - floor(fz)
	
	# Trilinear interpolation
	var c000 := _grid[_get_index(x0, y0, z0)]
	var c100 := _grid[_get_index(x1, y0, z0)]
	var c010 := _grid[_get_index(x0, y1, z0)]
	var c110 := _grid[_get_index(x1, y1, z0)]
	var c001 := _grid[_get_index(x0, y0, z1)]
	var c101 := _grid[_get_index(x1, y0, z1)]
	var c011 := _grid[_get_index(x0, y1, z1)]
	var c111 := _grid[_get_index(x1, y1, z1)]
	
	var lerp_x00 := c000.lerp(c100, tx)
	var lerp_x10 := c010.lerp(c110, tx)
	var lerp_x01 := c001.lerp(c101, tx)
	var lerp_x11 := c011.lerp(c111, tx)
	
	var lerp_y0 := lerp_x00.lerp(lerp_x10, ty)
	var lerp_y1 := lerp_x01.lerp(lerp_x11, ty)
	
	var final_wind := lerp_y0.lerp(lerp_y1, tz)
	
	# Add active impulses
	for imp in _impulses:
		var dist := pos.distance_to(imp.pos)
		if dist < imp.radius:
			var strength = 1.0 - (dist / imp.radius)
			final_wind += imp.vel * strength * (imp.life / 2.0)
			
	return final_wind

func add_impulse(pos: Vector3, vel: Vector3, radius: float, duration: float = 2.0) -> void:
	_impulses.append({
		"pos": pos,
		"vel": vel,
		"radius": radius,
		"life": duration
	})

static func gerstner_height(x: float, z: float, t: float, waves: Array) -> float:
	var h := 0.0
	for w in waves:
		var dir := Vector2(w.dir.x, w.dir.y).normalized()
		var k = TAU / w.wavelength
		var c := sqrt(9.81 / k)
		var phase = k * (dir.dot(Vector2(x, z)) - c * t)
		h += w.amp * sin(phase)
	return h

static func gerstner(x: float, z: float, t: float, waves: Array) -> Vector3:
	var pos := Vector3(x, 0, z)
	for w in waves:
		var dir := Vector2(w.dir.x, w.dir.y).normalized()
		var k = TAU / w.wavelength
		var c := sqrt(9.81 / k)
		var phase = k * (dir.dot(Vector2(x, z)) - c * t)
		
		var steepness = w.steepness
		var a = w.amp
		
		pos.x += steepness * a * dir.x * cos(phase)
		pos.y += a * sin(phase)
		pos.z += steepness * a * dir.y * cos(phase)
	return pos
