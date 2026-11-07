extends RefCounted
class_name ChomuFluidParticleCollisionDynamics

## S-94 Fluid / Particle Collision Dynamics
## Implements a lightweight, data-driven particle-based fluid simulation 
## focusing on collision dynamics with solid objects.
## Uses a Position-Based Dynamics (PBD) approach for stability and performance.

class Particle:
	var position: Vector3
	var prev_position: Vector3
	var velocity: Vector3
	var mass: float
	var radius: float
	var id: int

	func _init(id_val: int, pos: Vector3, rad: float, m: float):
		id = id_val
		position = pos
		prev_position = pos
		velocity = Vector3.ZERO
		radius = rad
		mass = m

## Configuration for the fluid simulation
class FluidConfig:
	var gravity: Vector3 = Vector3(0, -9.81, 0)
	var viscosity: float = 0.1
	var particle_radius: float = 0.1
	var interaction_radius: float = 0.3
	var restitution: float = 0.2 # Bounciness against solids
	var friction: float = 0.1
	var max_velocity: float = 50.0
	var iterations: int = 3 # PBD solver iterations

func _init(config: FluidConfig = null):
	if config:
		_config = config
	else:
		_config = FluidConfig.new()
	_particles = [] # Fixed: Removed typed array initialization in _init which causes parse errors in some 4.x versions
	_rng = RandomNumberGenerator.new()

var _config: FluidConfig
var _rng: RandomNumberGenerator
var _particles: Array

## Adds a particle to the simulation.
func add_particle(position: Vector3, radius: float = -1.0, mass: float = 1.0) -> int:
	var rad = radius if radius > 0 else _config.particle_radius
	var p = Particle.new(_particles.size(), position, rad, mass)
	_particles.append(p)
	return p.id

## Removes a particle by ID.
func remove_particle(id: int) -> bool:
	if id < 0 or id >= _particles.size():
		return false
	# To maintain O(1) removal and avoid shifting, we swap with last
	var last_idx = _particles.size() - 1
	var last_p = _particles[last_idx]
	_particles[id] = last_p
	last_p.id = id
	_particles.pop_back()
	return true

## Updates the simulation state.
## [param space_state] The physics direct space state for collision queries.
func step(delta: float, space_state: PhysicsDirectSpaceState3D) -> void:
	if _particles.is_empty():
		return

	# 1. Integration & External Forces
	for p in _particles:
		p.velocity += _config.gravity * delta
		p.prev_position = p.position
		p.position += p.velocity * delta

	# 2. PBD Solver Iterations
	for i in range(_config.iterations):
		_solve_particle_collisions()
		_solve_solid_collisions(space_state)

	# 3. Velocity Update & Friction
	for p in _particles:
		p.velocity = (p.position - p.prev_position) / delta
		p.velocity = p.velocity.limit_length(_config.max_velocity)

func _solve_particle_collisions() -> void:
	# Simple sphere-sphere repulsion to simulate fluid volume
	for i in range(_particles.size()):
		var p1 = _particles[i]
		for j in range(i + 1, _particles.size()):
			var p2 = _particles[j]
			var diff = p1.position - p2.position
			var dist_sq = diff.length_squared()
			var min_dist = p1.radius + p2.radius
			if dist_sq < min_dist * min_dist:
				var dist = sqrt(dist_sq)
				var overlap = min_dist - dist
				var normal = diff / dist if dist > 0.0001 else Vector3.UP
				var correction = normal * (overlap * 0.5)
				p1.position += correction
				p2.position -= correction

func _solve_solid_collisions(space_state: PhysicsDirectSpaceState3D) -> void:
	for p in _particles:
		# Use a raycast to detect solid boundaries
		var query = PhysicsRayQueryParameters3D.new()
		query.from = p.prev_position
		query.to = p.position
		
		var result = space_state.intersect_ray(query)
		if result:
			var hit_pos = result.position
			var hit_normal = result.normal
			
			# Correct position to be exactly 'radius' away from surface
			p.position = hit_pos + hit_normal * p.radius
			
			# Apply restitution/friction to velocity (indirectly via prev_position)
			var relative_vel = (p.position - p.prev_position)
			var normal_vel = hit_normal * relative_vel.dot(hit_normal)
			var tangent_vel = relative_vel - normal_vel
			
			# Reflect normal velocity and dampen tangent
			var reflected_vel = (tangent_vel * (1.0 - _config.friction)) - (normal_vel * _config.restitution)
			p.prev_position = p.position - reflected_vel

## Returns the current state of all particles.
func get_particles_data() -> Array:
	var data: Array = []
	for p in _particles:
		data.append({
			"id": p.id,
			"pos": p.position,
			"vel": p.velocity,
			"radius": p.radius
		})
	return data

## Saves the simulation state to a Dictionary.
func save_state() -> Dictionary:
	var p_data: Array = []
	for p in _particles:
		p_data.append({
			"pos": p.position,
			"prev": p.prev_position,
			"vel": p.velocity,
			"rad": p.radius,
			"mass": p.mass
		})
	return {
		"particles": p_data,
		"config": {
			"gravity": _config.gravity,
			"viscosity": _config.viscosity,
			"restitution": _config.restitution,
			"friction": _config.friction
		}
	}

## Loads the simulation state from a Dictionary.
func load_state(data: Dictionary) -> void:
	_particles.clear()
	if not data.has("particles"): return
	
	var p_list = data["particles"]
	for i in range(p_list.size()):
		var d = p_list[i]
		var p = Particle.new(i, d.pos, d.rad, d.mass)
		p.prev_position = d.prev
		p.velocity = d.vel
		_particles.append(p)
	
	if data.has("config"):
		var c = data["config"]
		_config.gravity = c.get("gravity", _config.gravity)
		_config.viscosity = c.get("viscosity", _config.viscosity)
		_config.restitution = c.get("restitution", _config.restitution)
		_config.friction = c.get("friction", _config.friction)
