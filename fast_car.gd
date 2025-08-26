extends CharacterBody3D
class_name FastCar


# Fake-physics forces
@export var friction = 2.0
@export var gravity = 5.0

# y-alignment variables
@export var fall_tilt_speed = 1.0
@export var ground_snap_speed = 5.0

# Input variables
var accel_input : float = 0.0
var turn_input : float = 0.0
var just_started_accel : bool = false
var was_accel : bool = false
# Turning variables
var curr_turn_angle : float = 0.0 # the current turning angle
var queued_turn_angle : float = 0.0 # the turn angle we-ll hit on acceleration
var max_turn_angle : float = 45.0 # the maximum turn angle, in degrees
var max_slip_angle : float = 60.0 # the maximum angle, in degrees, of a slip
var turn_angle_speed : float = 45.0 # the angle change per frame, in degrees, of our target angle
var turn_center_speed : float = 50.0
var turn_snap_speed : float = 1.0 # the angle change per frame, in degrees, of the actual car
var is_slipping : bool = false # whether we're slipping
var max_angle_timer : float = 0.0 # How long we've been at the max turn angle
var max_angle_timer_top : float = 1.0 # How many seconds at max angle before we slip
# Engine variables
var curr_rpm : float = 0.0 #current RPM
var max_rpm : float = 10.0 #max RPM (in thousands)
var curr_gear : int = 0
@export var gear_top_speeds : Array[float] = [0, 40, 80, 105, 120]
var accel : float = 0.0 # current acceleration point along the accel_curve
@export var accel_rate : float = 0.2 # % of accel_curve we traverse/second while accelerating
@export var deaccel_rate : float = 0.3 # % of accel_curve we traverse/second while deccelerating
@export var brake_rate : float = 0.5 # % of accel_curve we traverse/second while braking
@export var accel_curve : Curve
var curr_speed : float = 0.0 # get this from our velocity
# Array of Raycasts from wheels to ground
@export var ground_rays : Array[RayCast3D]
@export var cameras : Array[Camera3D]
var curr_camera : int = 0
# Wheel meshes
@onready var wheel_fl : MeshInstance3D = $CarModel.find_child("Wheel-FL")
@onready var wheel_fr : MeshInstance3D = $CarModel.find_child("Wheel-FR")
@onready var wheel_bl : MeshInstance3D = $CarModel.find_child("Wheel-BL")
@onready var wheel_br : MeshInstance3D = $CarModel.find_child("Wheel-BR")
@onready var wheels : Array[MeshInstance3D] = [wheel_fl, wheel_fr, wheel_bl, wheel_br]


func _physics_process(delta) -> void:
	velocity.y -= gravity * delta
	#get player input, handle gearing
	get_input()
	#handle turning
	handle_turning(delta)
	#handle engine curve
	handle_engine(delta)
	#handles moving the car forward
	handle_accel(delta)
	#do actual movement
	#TODO: handle collisions, landing
	move_and_slide()
	#align with floor
	align_with_floor(delta)
	#orthonormalize
	global_transform = global_transform.orthonormalized()


## Handles player input
func get_input():
	#accel/steering
	accel_input = Input.get_axis("back", "forward")
	turn_input = Input.get_axis("right", "left")
	#gearing
	if(Input.is_action_just_pressed("gear_up")): gear_change(1)
	elif(Input.is_action_just_pressed("gear_down")): gear_change(-1)
	curr_gear = clamp(curr_gear, 0, gear_top_speeds.size())
	#cycle camera
	if(Input.is_action_just_pressed("cycle_camera")):
		curr_camera += 1
		if(curr_camera > (cameras.size()-1)): curr_camera = 0
		cameras[curr_camera].make_current()
	# check if we just gassed it
	if (accel_input > 0 and was_accel == false): just_started_accel = true
	else: just_started_accel = false
	if (accel_input > 0): was_accel = true
	else: was_accel = false


## Handles gearing
func gear_change(gear_increment) -> void:
	var new_gear = curr_gear + gear_increment
	#early return for index OOB
	if(new_gear < 0 or new_gear > gear_top_speeds.size() - 1): return
	#sets accel proportional to new gear's accel curve
	#ex: 0.5 accel at top speed 50 -> 0.25 at top speed 100
	#ex: 0.25 accel at top speed 100 -> 0.5 at top speed 50
	if(gear_top_speeds[new_gear] != 0): #avoid div by 0
		accel = accel * gear_top_speeds[curr_gear] / gear_top_speeds[new_gear]
	else:
		accel = accel #TODO: this is probably bad
	#updates gear
	curr_gear = new_gear


## Handles engine acceleration curves
func handle_engine(delta) -> void:
	#step 0: offset acceleration by gear -- higher gears accelerate lesswwww
	var max_gear = gear_top_speeds.size()-1
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
	if(curr_speed > target_speed):
		#var old_target_speed = gear_top_speeds[curr_gear+1]
		#print(curr_speed, "\t", target_speed, "\t", old_target_speed)
		curr_speed = lerpf(curr_speed, 0, deaccel_rate * delta) #TODO: not sure about this
	else:
		curr_speed = curr_rpm * gear_top_speeds[curr_gear]


## Handles forward movement of the car
func handle_accel(delta) -> void:
	var vy = velocity.y
	velocity = -transform.basis.z * curr_speed / 4
	velocity.y = vy


## Handles turning
func handle_turning(delta) -> void:
	#add damping if holding gas
	var accel_damping = 1.0
	if(accel_input > 0): accel_damping = 0.75 #TODO: tune this
	#add multiplier if changing directions
	var change_dir_mult = 1.0
	if sign(turn_input) != sign(curr_turn_angle): change_dir_mult = 1.5 #TODO: tune this. equal to center_speed?
	#update turn angle based on input
	if(abs(turn_input) > 0):
		curr_turn_angle += turn_angle_speed * turn_input * accel_damping * change_dir_mult * delta
	else:
		curr_turn_angle -= sign(curr_turn_angle) * turn_center_speed * accel_damping * delta
	curr_turn_angle = clampf(curr_turn_angle, -max_turn_angle, max_turn_angle)
	#rotate the car
	#TODO: fix this
	self.rotation.y = lerp_angle(self.rotation.y, deg_to_rad(curr_turn_angle) + self.rotation.y, 3 * delta)


## Aligns the car with the ground beneath it
func align_with_floor(delta) -> void:
	var floor_normal : Vector3 = get_floorplane_normal()
	if(Input.is_action_just_pressed("q")):
		print(is_on_floor(), floor_normal, floor_normal.length())
	#if we're on the floor, and we have a valid floor normal, interpolate to it
	if(is_on_floor() and floor_normal.length() > 0.0 and (Vector3.UP.dot(floor_normal) > 0)):
		var xform = align_with_y(global_transform, floor_normal)
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
func get_floorplane_normal() -> Vector3:
	var ray_points : Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	# update and debug our ground rays
	for ray_ind in ground_rays.size():
		ground_rays[ray_ind].force_raycast_update()
		ray_points[ray_ind] = ground_rays[ray_ind].get_collision_point()
		DebugDraw3D.draw_sphere(ray_points[ray_ind], 0.1)
	# ground rays are ordered FL, FR, BL, BR
	#we want triangle FL-FR-BL and FR-BR-BL
	var surf_1_normal = get_normal_from_points(ray_points[0],ray_points[1],ray_points[2])
	var surf_2_normal = get_normal_from_points(ray_points[1],ray_points[3],ray_points[2])
	# average the two normals
	var z = -(surf_1_normal + surf_2_normal)/2.0
	DebugDraw3D.draw_arrow_ray(position, z, 0.5, Color(0,0,0,0), 0.01)
	return z


## Takes points [p1],[p2], [p3]. Returns the normal of the triangle they form.
func get_normal_from_points(p1, p2, p3) -> Vector3:
	var A = p2 - p1
	var B = p3 - p1
	return A.cross(B).normalized()
