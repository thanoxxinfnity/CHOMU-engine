extends Node3D
## World root: assembles city, lighting, player, car, AI, HUD and handles
## entering / exiting the car.

const PLAYER_SPAWN := Vector3(-30.0, 0.3, 66.0)
const CAR_SPAWN := Vector3(-35.3, 0.9, 44.0)
const ENTER_DIST := 4.2

var city: Node3D
var day_night: Node
var player: CharacterBody3D
var car: VehicleBody3D
var rig: Node3D
var traffic: Node3D
var peds: Node3D
var hud: CanvasLayer
var ambience: AudioStreamPlayer

func _ready() -> void:
	Game.world = self
	Game.driving = false
	Game.reset_virtual_input()
	city = preload("res://scripts/City.gd").new()
	city.name = "City"
	add_child(city)
	day_night = preload("res://scripts/DayNight.gd").new()
	day_night.name = "DayNight"
	day_night.city = city
	if Game.demo:
		day_night.start_hour = 17.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hour="):
			day_night.start_hour = float(a.substr(7))
	add_child(day_night)

	player = preload("res://scripts/Player.gd").new()
	player.name = "Player"
	add_child(player)
	player.teleport(PLAYER_SPAWN, PI)

	car = preload("res://scripts/Car.gd").new()
	car.name = "PlayerCar"
	add_child(car)
	car.global_transform = Transform3D(Basis(Vector3.UP, PI), CAR_SPAWN)

	traffic = preload("res://scripts/Traffic.gd").new()
	traffic.name = "Traffic"
	add_child(traffic)
	traffic.setup(city)
	peds = preload("res://scripts/Pedestrians.gd").new()
	peds.name = "Pedestrians"
	add_child(peds)
	peds.setup(city, 18)

	rig = preload("res://scripts/CameraRig.gd").new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.target = player
	rig.yaw = 0.0
	rig.snap_to_target()
	rig.set_excludes([player, car])

	hud = preload("res://scripts/HUD.gd").new()
	hud.name = "HUD"
	add_child(hud)
	hud.minimap.city = city
	hud.minimap.traffic = traffic
	hud.minimap.peds = peds

	ambience = AudioStreamPlayer.new()
	ambience.stream = Util.load_audio(Assets.SFX.ambience, true)
	ambience.volume_db = -14.0
	add_child(ambience)
	ambience.play()

	Game.action.connect(_on_action)
	day_night.apply_quality(Game.quality)
	if Game.demo:
		var d := preload("res://scripts/DemoDirector.gd").new()
		d.name = "DemoDirector"
		add_child(d)
	else:
		hud.show_caption("Welcome to Chomu City", 3.0)

var _shot_frames := -1

func _process(_d: float) -> void:
	if _shot_frames < 0:
		_shot_frames = 0 if "--shot" in OS.get_cmdline_user_args() else -2
	if _shot_frames >= 0:
		_shot_frames += 1
		if _shot_frames == 90:
			get_viewport().get_texture().get_image().save_png("user://shot.png")
			print("[shot] saved, fps=", Engine.get_frames_per_second())
			get_tree().quit()

func _physics_process(_d: float) -> void:
	if not Game.driving:
		Game.near_car = player.global_position.distance_to(car.global_position) < ENTER_DIST
	else:
		Game.near_car = false

func _on_action(a: String) -> void:
	if a == "enter":
		if Game.driving:
			exit_car()
		elif Game.near_car:
			enter_car()

func enter_car() -> void:
	Game.driving = true
	hud.touch.release_all()
	player.set_active(false)
	car.play_door(true)
	car.set_driven(true)
	rig.target = car
	if car.global_basis.y.dot(Vector3.UP) < 0.5:
		car.reset_upright()

func exit_car() -> void:
	if car.get_speed_kmh() > 25.0:
		return
	Game.driving = false
	hud.touch.release_all()
	car.set_driven(false)
	car.play_door(false)
	# step out on the driver's (left) side, or the other side if blocked
	var left := car.global_basis.x       # +X is the car's left (forward is +Z)
	var spot: Vector3 = car.global_position + left * 2.0
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(car.global_position + Vector3(0, 1, 0), spot + Vector3(0, 1, 0), 1 | 4)
	q.exclude = [car.get_rid()]
	if not space.intersect_ray(q).is_empty():
		spot = car.global_position - left * 2.0
	spot.y = maxf(car.global_position.y, 0.2) + 0.3
	player.teleport(spot, atan2(car.global_basis.z.x, car.global_basis.z.z))
	player.set_active(true)
	rig.target = player
