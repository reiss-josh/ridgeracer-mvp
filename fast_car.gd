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
var max_slip_angle : float = 70.0 # the maximum angle, in degrees, of a slip
var turn_angle_speed : float = 90.0 # the angle change per frame, in degrees, of our target angle
var turn_center_speed : float = 50.0
var turn_snap_speed : float = 1.0 # the angle change per frame, in degrees, of the actual car
var is_slipping : bool = false # whether we're slipping
var max_angle_timer : float = 0.0 # How long we've been at the max turn angle
var max_angle_timer_top : float = 1.0 # How many seconds at max angle before we slip

# Engine variables
var max_rpm : float = 20.0 #TODO: one max_rpm per geark
var acceleration : float = 5.0 #TODO: one accel per gear
var deaccel : float = 7.0
var curr_rpm : float = 0.0
var brake_force : float = 10.0
var curr_speed : float = 0.0 # get this from our velocity

# Array of Raycasts from wheels to ground
@export var ground_rays : Array[RayCast3D]

# Wheel meshes
@onready var wheel_fl : MeshInstance3D = $CarModel.find_child("Wheel-FL")
@onready var wheel_fr : MeshInstance3D = $CarModel.find_child("Wheel-FR")
@onready var wheel_bl : MeshInstance3D = $CarModel.find_child("Wheel-BL")
@onready var wheel_br : MeshInstance3D = $CarModel.find_child("Wheel-BR")
@onready var wheels : Array[MeshInstance3D] = [wheel_fl, wheel_fr, wheel_bl, wheel_br]

func _physics_process(delta) -> void:
	velocity.y -= gravity * delta
	#get player input
	get_input()
	#handle turning
	handle_turning(delta)
	#handle acceleration/deceleration/braking
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
	accel_input = Input.get_axis("back", "forward")
	turn_input = Input.get_axis("right", "left")
	if(accel_input > 0 and was_accel == false):
		just_started_accel = true
	else:
		just_started_accel = false
	if(accel_input > 0): was_accel = true
	else: was_accel = false


## Handles turning
func handle_turning(delta) -> void:
	#print(curr_turn_angle)
	$TestRay.rotation.y = deg_to_rad(curr_turn_angle)
	#Check if we're currently slipping
		# If our curr_turn_angle exceeds max_turn_angle, we should start slipping
		# If we've been at max turn angle for a bit, and we're still holding a direction, we should slip
	if (abs(curr_turn_angle) > max_turn_angle) or (max_angle_timer >= max_angle_timer_top): 
		is_slipping = true
	else:
		is_slipping = false
	if(is_slipping == false): #If not:
		#Update our turn angle
		if(accel_input <= 0): # If we aren't accelerating, we should increase queued_turn_angle based on our speed + input, and recenter
			if(turn_input != 0):
				queued_turn_angle += turn_input * (turn_angle_speed * 2) * delta
				curr_turn_angle += turn_input * turn_angle_speed * delta
				curr_turn_angle = clampf(curr_turn_angle, -max_turn_angle, max_turn_angle) #clamp the max_turn_angle
			else:
				var sign = sign(curr_turn_angle)
				var qsign = sign(queued_turn_angle)
				queued_turn_angle -= sign(curr_turn_angle) * (turn_center_speed * 2) * delta
				curr_turn_angle -= sign(curr_turn_angle) * turn_center_speed * delta
				if(sign(curr_turn_angle) != sign): curr_turn_angle = 0.0
				if(sign(queued_turn_angle) != qsign): queued_turn_angle = 0.0
		elif(just_started_accel): # Otherwise, if we just started accelerating, we should snap curr_turn_angle to match
			curr_turn_angle = queued_turn_angle
			queued_turn_angle = 0
		else: # Otherwise, we should increase our curr_turn_angle based on input
			if(turn_input != 0):
				curr_turn_angle += turn_input * turn_angle_speed * delta
				curr_turn_angle = clampf(curr_turn_angle, -max_turn_angle, max_turn_angle) #clamp the max_turn_angle
			else:
				var sign = sign(curr_turn_angle)
				curr_turn_angle -= sign(curr_turn_angle) * turn_center_speed * delta
				if(sign(curr_turn_angle) != sign): curr_turn_angle = 0.0
			# TODO: Should turn a little -> a lot -> a little
		queued_turn_angle = clampf(queued_turn_angle, -max_slip_angle, max_slip_angle) #clamp the max_turn_angle
		if(abs(curr_turn_angle) >= max_turn_angle * 0.99): #If we're at/above 99% of max_turn_angle
			max_angle_timer += 1.0 * delta #increase max_angle_timer by 1/sec
		elif(max_angle_timer > 0.0): #Otherwise,
			max_angle_timer -= 0.5 * delta #decrease max_angle_timer by 0.5/sec
		max_angle_timer = clampf(max_angle_timer, 0, max_angle_timer_top) #clamp the turn angle timer
	else: #If we are:
		if(max_angle_timer > 0.0):
			max_angle_timer -= 0.5 * delta #decrease max_angle_timer by 0.5/sec
			max_angle_timer = clampf(max_angle_timer, 0, max_angle_timer_top) #clamp the turn angle timer
		if(sign(curr_turn_angle) == sign(turn_input)): #If we're still holding in the slip direction, we should keep slipping
			curr_turn_angle += turn_input * turn_angle_speed * delta
			curr_turn_angle = clampf(curr_turn_angle, -max_slip_angle, max_slip_angle) #clamp the max_turn_angle
		else: #Otherwise, we should interpolate back to regular turning angle
			curr_turn_angle -= sign(curr_turn_angle) * turn_center_speed * delta
				#TODO: We should interpolate back much more quickly if we're countersteering
				#TODO: We should interpolate back much more slowly if we're flooring it
	# Finally, we should interpolate our actual angle towards our curr_turn_angle
		#TODO: rotate car
	$CarModel.rotation.y = deg_to_rad(curr_turn_angle) + (TAU/2)
	if(curr_rpm > 0):
		self.rotation.y = lerp_angle(self.rotation.y, deg_to_rad(curr_turn_angle) + self.rotation.y, turn_snap_speed * delta)
	


## Handles acceleration/deceleration/braking
func handle_accel(delta) -> void:
	var vy = velocity.y
	# Apply friction
		#decrease velocity by friction amount
# Increase / decrease RPM based on whether we're holding the gas/brake
	if(accel_input > 0):
		curr_rpm += acceleration * delta #If accel, increase RPM by accel
	elif(accel_input == 0):
		curr_rpm -= deaccel * delta #If not accel, decrease RPM by deaccel
	elif(accel_input < 0):
		curr_rpm -= deaccel * delta #If not accel, decrease RPM by deaccel
		curr_rpm -= brake_force * delta #If holding brake, apply brake_force
	curr_rpm = clampf(curr_rpm, 0, max_rpm) #clamp to (0, max speed)
# Increase our velocity in the direction of current turn angle, in accordance with current RPM
	velocity = -transform.basis.z * curr_rpm
	velocity.y = vy


## Aligns the car with the ground beneath it
func align_with_floor(delta) -> void:
	var floor_normal : Vector3 = get_floorplane_normal()
	if(Input.is_action_just_pressed("q")):
		print(is_on_floor(), floor_normal, floor_normal.length())
	#if we're on the floor, and we have a valid floor normal, interpolate to it
	if(is_on_floor() and floor_normal.length() > 0.0):
		var xform = align_with_y(global_transform, floor_normal)
		global_transform = global_transform.interpolate_with(xform, ground_snap_speed * delta)
	#if we're in the air, align with up
	elif(is_on_floor() == false):
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
		ray_points[0] = ground_rays[ray_ind].get_collision_point()
		DebugDraw3D.draw_sphere(ray_points[0], 0.1)
	# ground rays are ordered FL, FR, BL, BR
	var surf_1_normal = get_normal_from_points(ray_points[0],ray_points[1],ray_points[2])
	var surf_2_normal = get_normal_from_points(ray_points[1],ray_points[2],ray_points[3])
	# average the two normals
	var z = -(surf_1_normal + surf_2_normal)/2.0
	DebugDraw3D.draw_arrow_ray(position, z, 1, Color(0,0,0,0), 0.01)
	return z


## Takes points [p1],[p2], [p3]. Returns the normal of the triangle they form.
func get_normal_from_points(p1, p2, p3) -> Vector3:
	var A = p2 - p1
	var B = p3 - p1
	return A.cross(B).normalized()
