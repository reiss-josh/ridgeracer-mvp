extends CharacterBody3D
class_name FastCar


# Fake-physics forces
@export var friction = 5.0
@export var gravity = 5.0
# y-alignment variables
@export var fall_tilt_speed = 1.0
@export var ground_snap_speed = 5.0
# Input variables
var accel_input : float = 0.0
var turn_input : float = 0.0
var just_started_accel : bool = false
var was_accel : bool = false # whether we were accelerating last frame
# Turning variables
var curr_turn_angle : float = 0.0 # the current turning angle
var queued_turn_angle : float = 0.0 # the turn angle we-ll hit on acceleration
@export var max_turn_angle : float = 45.0 # the maximum turn angle, in euler degrees
@export var max_slip_angle : float = 60.0 # the maximum drift angle, in euler degrees
@export var turn_angle_speed : float = 180.0 # the angle change/frame, in euler degrees, of our target angle
@export var turn_center_speed : float = 180.0 # the angle change/frame, in euler degrees, of steeering centering
var turn_amount : float = 0.0 # for how much our transform actually rotated this frame
var is_slipping : bool = false # whether we're slipping
# Engine variables
var curr_rpm : float = 0.0 #current RPM
var curr_rpm_smoothed : float = 0.0 # smoothed RPM -- used for display, sounds
@export var max_rpm : float = 10.0 #max RPM (in thousands)
var curr_gear : int = 0
var gear_change : int = 0
@export var gear_top_speeds : Array[float] = [0, 40, 80, 105, 120]
var accel : float = 0.0 # current acceleration point along the accel_curve
@export var accel_rate : float = 0.2 # percentage of accel_curve we traverse/second while accelerating
@export var deaccel_rate : float = 0.3 # percentage of accel_curve we traverse/second while deccelerating
@export var brake_rate : float = 0.5 # percentage of accel_curve we traverse/second while braking
@export var accel_curve : Curve
var curr_speed : float = 0.0
var delta_speed : float = 0.0 # change in curr_speed since last frame
# Sound variables
@export var engine_volume : float = -20.0
@export var engine_min_pitch : float = 0.25
@export var engine_max_pitch : float = 1.0
# Array exports
@export var ground_rays : Array[RayCast3D] #raycasts from wheels to ground
@export var cameras : Array[Camera3D] #available cameras
var curr_camera : int = 0
# Wheel meshes
@onready var wheel_fl : MeshInstance3D = $CarModelContainer.find_child("CarModel/Wheel-FL")
@onready var wheel_fr : MeshInstance3D = $CarModelContainer.find_child("CarModel/Wheel-FR")
@onready var wheel_br : MeshInstance3D = $CarModelContainer.find_child("CarModel/Wheel-BR")
@onready var wheel_bl : MeshInstance3D = $CarModelContainer.find_child("CarModel/Wheel-BL")
@onready var car_body : MeshInstance3D = self.get_node("CarModelContainer/CarModel/CarBody")
@onready var wheels : Array[MeshInstance3D] = [wheel_fl, wheel_fr, wheel_br, wheel_bl]


func _ready() -> void:
	curr_camera = 2
	cameras[curr_camera].make_current()
	$HUD.set_values(gear_top_speeds.back(), max_rpm, -max_turn_angle)
	$EngineSound.volume_db = engine_volume
	$EngineSound.pitch_scale = engine_min_pitch
	$EngineSound.autoplay = true
	$EngineSound.playing = true
	# reparent body cameras to car_body
	for camera in cameras:
		if(camera.name == "BumperCam" or camera.name == "HoodCam"):
			camera.reparent(car_body)


func _physics_process(delta) -> void:
	get_input()
	handle_gearbox()
	handle_turning(delta)
	handle_engine(delta)
	align_with_floor(delta) #TODO -- when should we do this?
	handle_accel(delta)
	handle_camera(delta)
	animate_car(delta)
	handle_sound()
	$HUD.update_values(curr_speed, curr_rpm_smoothed * max_rpm, curr_turn_angle, curr_gear)
	#orthonormalize
	global_transform = global_transform.orthonormalized()


## Handles player input
func get_input():
	#accel/steering
	accel_input = Input.get_axis("back", "forward")
	turn_input = Input.get_axis("right", "left")
	#gearing
	if(Input.is_action_just_pressed("gear_up")): gear_change = 1
	elif(Input.is_action_just_pressed("gear_down")): gear_change = -1
	#cycle camera
	if(Input.is_action_just_pressed("cycle_camera")):
		curr_camera += 1
		if(curr_camera > (cameras.size()-1)): curr_camera = 0
		cameras[curr_camera].make_current()
	#debug
	if(Input.is_action_just_pressed("debug_ground")):
		accel = 1.0
		#velocity += -transform.basis.z * gear_top_speeds[curr_gear] / 4
		pass
	# check if we just gassed it
	if (accel_input > 0 and was_accel == false): just_started_accel = true
	else: just_started_accel = false
	if (accel_input > 0): was_accel = true
	else: was_accel = false


## Handles gearing
func handle_gearbox() -> void:
	if(gear_change == 0): return #early return for no change
	var new_gear = curr_gear + gear_change
	if(new_gear < 0 or new_gear > gear_top_speeds.size() - 1): return #early return for index OOB
	#set accel proportional to new gear's accel curve
		#ex: 0.5 accel at top speed 50 -> 0.25 at top speed 100
		#ex: 0.25 accel at top speed 100 -> 0.5 at top speed 50
	if(gear_top_speeds[new_gear] != 0): #for gears other than Neutral
		accel = accel * gear_top_speeds[curr_gear] / gear_top_speeds[new_gear]
	else: #for Neutral
		accel = accel #TODO: this is probably bad
	#updates gear
	curr_gear = new_gear
	gear_change = 0


## Handles engine acceleration curves
func handle_engine(delta) -> void:
	#step 0: offset acceleration by gear -- higher gears accelerate lesswwww
	var gear_ratio : float = 1.0
	if(curr_gear > 0): gear_ratio = 1.0/float(curr_gear) #TODO: is this okay?
	#step 1: update accel based on input
	if(accel_input > 0):
		accel += accel_rate * accel_input * gear_ratio * delta
	elif(accel_input == 0):
		accel -= deaccel_rate * delta
	elif(accel_input < 0):
		accel += brake_rate * accel_input * delta
	accel = clampf(accel, 0, 1.0)
	#step 2: sample accel curve to get curr_rpm
	curr_rpm = accel_curve.sample_baked(accel)
	#step 3: convert rpm to speed
	var target_speed = gear_top_speeds[curr_gear]
	var last_frame_speed = curr_speed
	if(curr_speed > target_speed):
		curr_speed = lerpf(curr_speed, 0, deaccel_rate * delta) #TODO: not sure about this
	else:
		curr_speed = curr_rpm * gear_top_speeds[curr_gear]
	delta_speed = curr_speed - last_frame_speed
	#step 4: update cur_rpm_smoothed
	if(curr_rpm > curr_rpm_smoothed):
		curr_rpm_smoothed += accel_rate * delta
		curr_rpm_smoothed = clampf(curr_rpm_smoothed, 0, curr_rpm)
	elif(curr_rpm < curr_rpm_smoothed):
		curr_rpm_smoothed -= deaccel_rate * delta
		curr_rpm_smoothed = clampf(curr_rpm_smoothed, curr_rpm, 1.0)


## Handles forward movement of the car // TODO
var stored_bounce : Vector3 = Vector3.ZERO
func handle_accel(delta) -> void:
	#apply gravity
	velocity.y -= gravity * delta
	var stored_velocity = velocity #storeour velocity
	#engine
	var curr_engine_effect = -transform.basis.z * curr_speed / 4
	curr_engine_effect.y = 0
	#move
	velocity = curr_engine_effect + stored_velocity
	move_and_slide()
	#update stored velocity
	stored_velocity.y = velocity.y
	#stored_velocity = stored_velocity + accel_collisions()
	accel_collisions()
	#apply friction
	velocity = friction_applied(stored_velocity, delta)


## Takes vector [vel] and [delta] - returns vector with x and z decreased by (friction * delta)
func friction_applied(vel : Vector3, delta) -> Vector3:
	var d = delta * friction
	var xs = sign(vel.x)
	var zs = sign(vel.z)
	vel.x -= d * xs
	vel.z -= d * zs
	if sign(vel.x) != sign(xs): vel.x = 0.0
	if sign(vel.z) != sign(zs): vel.z = 0.0
	return vel


## Handle acceleration collisions for move_and_slide()
func accel_collisions() -> void:
	var old_speed = curr_speed
	var up_dir = transform.basis.y
	#var up_dir = up_direction
	var collisions := get_slide_collision_count()
	var done_wall = false
	var ref_angle : float = 0.0
	var num_walls = 0
	var bounces : Vector3 = Vector3.ZERO
	for index in collisions:
		var collision = get_slide_collision(index)
		var normal := collision.get_normal()
		var angle := normal.angle_to(up_dir)
		if angle < floor_max_angle:
			# it is a floor
			pass
		elif angle > (PI - floor_max_angle):
			# it is a ceiling
			pass
		else:
			# it is a wall
			#bounces = velocity.bounce(normal)
			var alignment = abs(-normal.dot(-transform.basis.z))
			#print(alignment)
			bounces += curr_speed/8 * normal #*alignment #TODO: why 8?
			if(done_wall == false):
				accel = accel / 2
				curr_speed = curr_speed / 2
				done_wall = true
			var vec1 = -transform.basis.z
			var vec2 = (-transform.basis.z).bounce(normal)
			var c_ref_angle = -(atan2(vec1.z, vec2.x) - atan2(vec2.z, vec1.x))
			ref_angle += c_ref_angle
			num_walls += 1
	if(ref_angle != 0):
		ref_angle = ref_angle / num_walls
		print(rad_to_deg(ref_angle))
		pass
		if(abs(ref_angle) < 0): # only ricochet when angle is < x degrees
			collision_angle = ref_angle
			is_colliding = true
	if(bounces != Vector3.ZERO):
		bounces = bounces / num_walls
		var min_crash_vol = -2.0
		var max_crash_vol = 2.0
		var speed_ratio = old_speed / gear_top_speeds[curr_gear]
		var impact_volume := lerpf(min_crash_vol, max_crash_vol, speed_ratio)
		#print(speed_ratio)
		impact_volume = clampf(impact_volume, min_crash_vol, max_crash_vol)
		$CrashSound.volume_db = impact_volume
		if(curr_speed > 3.0):
			$CrashSound.play()

## Move and slide, then return the change in x/z velocity
func move_and_slide_deltacheck():
	var v0 = Vector3(velocity.x, 0, velocity.z)
	move_and_slide() #do actual movement
	var v1 = Vector3(velocity.x , 0, velocity.z)
	if(v0 != v1):
		print("v0: ", v0)
		print("v1: ", v1)
		print("delta: ", v1 - v0)
		pass


## Handles turning // TODO - tuning
var is_colliding : bool = false # whether we're managing a collision
@export var collision_turn_speed : float = 120.0 # angle change/frame, in eueler degrees, after collision
var collision_angle = 0.0
func handle_turning(delta) -> void:
	#add damping if holding gas
	var accel_damping = 1.0
	if(accel_input > 0): accel_damping = 0.75 #TODO: tune this
	#add multiplier if changing directions
	var change_dir_mult = 1.0
	if sign(turn_input) != sign(curr_turn_angle):
		change_dir_mult = 1.5 #TODO: tune this. equal to center_speed?
	#update turn angle based on input
	if(abs(turn_input) > 0):
		curr_turn_angle += turn_angle_speed * turn_input * accel_damping * change_dir_mult * delta
	else:
		var angle_sign = sign(curr_turn_angle)
		curr_turn_angle -= angle_sign * turn_center_speed * accel_damping * delta
		if sign(curr_turn_angle) != angle_sign: curr_turn_angle = 0.0
	curr_turn_angle = clampf(curr_turn_angle, -max_turn_angle, max_turn_angle)
	$TestRay.rotation.y = deg_to_rad(curr_turn_angle)
	#rotate the car
	#if(curr_speed != 0):
	if(curr_speed != 0 and is_on_floor() == true):
		turn_amount = accel_damping * delta * abs(curr_turn_angle)/max_turn_angle * sign(curr_turn_angle)
		if(curr_speed < 0): turn_amount *= -1
	elif(is_on_floor() != true):
		var air_damping = 0.2
		turn_amount = air_damping * delta * abs(curr_turn_angle)/max_turn_angle * sign(curr_turn_angle)
	else:
		turn_amount = 0.0
		
	#handle collisions
	if(is_colliding):
		var start_collision_angle = collision_angle
		var coll_turn_amount = (delta * deg_to_rad(collision_turn_speed) * sign(start_collision_angle))
		collision_angle = collision_angle - coll_turn_amount
		if sign(collision_angle) != sign(start_collision_angle): collision_angle = 0.0
		turn_amount += coll_turn_amount
		if(collision_angle == 0): is_colliding = false
	self.rotation.y += turn_amount


## Handle camera effects // TODO - tuning
var body_fov_range : Vector2 = Vector2(75.0, 100.0)
var chase_fov_range : Vector2 = Vector2(75.0, 100.0)
var body_extra_tilt_lim : float = 10.0
func handle_camera(delta):
	var curr_cam = cameras[curr_camera]
	var speed_ratio = curr_speed / gear_top_speeds[gear_top_speeds.size()-1]
	var curr_fov_range : Vector2 = Vector2(75.0, 75.0)
	if(curr_cam.name == "HoodCam" or curr_cam.name == "BumperCam"):
		#speed tilt -- extra, for additional sauce!!
		var new_x := lerpf(0, deg_to_rad(body_extra_tilt_lim), delta_speed * 5)
		new_x = clampf(new_x, -deg_to_rad(body_extra_tilt_lim), deg_to_rad(body_extra_tilt_lim))
		curr_cam.rotation.x = lerpf(curr_cam.rotation.x, new_x, delta)
		#speed FOV
		curr_fov_range = body_fov_range
	elif(curr_cam.name == "ChaseCam" or curr_cam.name == "SideCam"):
		#speed FOV
		curr_fov_range = chase_fov_range
		#align with y -- TODO: should this interpolate?
		var xform = align_with_y(curr_cam.global_transform, Vector3.UP)
		curr_cam.global_transform = xform
		var chase_parent = curr_cam.get_parent() # TODO: this is bad
		chase_parent.rotation.y = lerpf(chase_parent.rotation.y, -turn_amount * 10, delta * 5)
	#speed FOV
	var new_fov = lerpf(curr_fov_range.x, curr_fov_range.y, speed_ratio)
	new_fov = clampf(new_fov, curr_fov_range.x, curr_fov_range.y)
	curr_cam.fov = lerpf(curr_cam.fov, new_fov, delta)


## Animates the car // TODO - tuning
var body_roll_lim : float = 10.0
var body_tilt_lim : float = 5
func animate_car(delta):
	#turn tilt
	var new_z := 0.0
	if(curr_speed > 0 and is_on_floor()): new_z = lerpf(0, deg_to_rad(body_roll_lim), turn_input)
	car_body.rotation.z = lerpf(car_body.rotation.z, new_z, delta)
	#speed tilt
	var new_x := 0.0 #maybe shouldn't have is_on_floor() but idk!!
	if(is_on_floor()): new_x = lerpf(0, deg_to_rad(body_tilt_lim), delta_speed * 5)
	new_x = clampf(new_x, -deg_to_rad(body_tilt_lim), deg_to_rad(body_tilt_lim))
	car_body.rotation.x = lerpf(car_body.rotation.x, new_x, delta)


## Handles playing engine sounds
func handle_sound():
	$EngineSound.pitch_scale = lerpf(engine_min_pitch, engine_max_pitch, curr_rpm_smoothed)


## Aligns the car with the ground beneath it
func align_with_floor(delta) -> void:
	var ground_normal : Vector3 = get_ground_normal()
	#debug display for normal debugging
	if(Input.is_action_just_pressed("debug_ground")): print(is_on_floor(), ground_normal, ground_normal.length())
	#if we're on the floor, and we have a valid floor normal, interpolate to it
	if(is_on_floor() and ground_normal.length() > 0.0 and (Vector3.UP.dot(ground_normal) > 0)):
		var xform = align_with_y(global_transform, ground_normal)
		global_transform = global_transform.interpolate_with(xform, ground_snap_speed * delta)
	#if we're in the air, align with up
	else:
		var xform = align_with_y(global_transform, Vector3.UP)
		global_transform = global_transform.interpolate_with(xform, fall_tilt_speed * delta)


## Takes [xform] and snaps its y axis to [new_y]
func align_with_y(xform : Transform3D, new_y : Vector3) -> Transform3D:
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform.orthonormalized()


## Returns the surface normal of ground below the car
func get_ground_normal() -> Vector3:
	var ray_points : Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	# update and debug our ground rays
	for ray_ind in ground_rays.size():
		ground_rays[ray_ind].force_raycast_update()
		ray_points[ray_ind] = ground_rays[ray_ind].get_collision_point()
		#DebugDraw3D.draw_sphere(ray_points[ray_ind], 0.1)
	# ground rays are ordered FL, FR, BR, BL - we want tris FL-FR-BR and BR-BL-FL
	var z = get_normal_for_plane(ray_points[0],ray_points[1],ray_points[2],ray_points[3])
	DebugDraw3D.draw_arrow_ray(position, z, 0.5, Color(0,0,0,0), 0.01)
	return z


## Takes points [p1],[p2],[p3],[p4] -- CLOCKWISE points of a plane -- and returns the surface normal
func get_normal_for_plane(p1, p2, p3, p4) -> Vector3:
	# we want triangles [p1-p2-p3] and [p3-p4-p1]
	var surf_1_normal = get_normal_from_points(p1,p2,p3)
	var surf_2_normal = get_normal_from_points(p3,p4,p1)
	# average the two triangles' normals
	return -(surf_1_normal + surf_2_normal)/2.0


## Takes points [p1],[p2],[p3] -- CLOCKWISE points of a tri -- and the tri's surface normal.
func get_normal_from_points(p1, p2, p3) -> Vector3:
	var A = p2 - p1
	var B = p3 - p1
	return A.cross(B).normalized()


## Handle acceleration collisions for move_and_collide()
func accel_bounce(delta) -> void:
	var collisions = move_and_collide(velocity*delta, false, 0.001, false, 32)
	if collisions == null: return
	var up_dir = transform.basis.y
	for index in collisions.get_collision_count():
		var normal := collisions.get_normal(index)
		var angle := normal.angle_to(up_dir)
		if angle < floor_max_angle:
			# it is a floor
			pass
		elif angle > (PI - floor_max_angle):
			# it is a ceiling
			pass
		else:
			# it is a wall
			pass
