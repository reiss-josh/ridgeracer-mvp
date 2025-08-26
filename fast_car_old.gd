extends CharacterBody3D
class_name FastCarOld

@export var speed = 10.0
@export var maxspeed = 10.0
@export var deaccel = 2
@export var gravity = 5.0
@export var ground_snap_speed = 10
@export var fall_tilt_speed = 5

@export var turn_speed = 5
@export var true_turn_speed = 1
@export var recenter_speed = 5
@export var max_turn_angle = 60.0
@export var curr_turn_angle = 0.0

@export var ground_rays : Array[RayCast3D]

@onready var front_left_wheel : MeshInstance3D = $CarModel.find_child("Wheel-FL")
@onready var front_right_wheel : MeshInstance3D = $CarModel.find_child("Wheel-FR")
@onready var back_left_wheel : MeshInstance3D = $CarModel.find_child("Wheel-BL")
@onready var back_right_wheel : MeshInstance3D = $CarModel.find_child("Wheel-BR")
@onready var wheels : Array[MeshInstance3D] = [front_left_wheel, front_right_wheel, back_left_wheel, back_right_wheel]

func _physics_process(delta):
	velocity.y -= gravity * delta
	get_input(delta)
	move_and_slide()
	_align_with_floor(delta)
	global_transform = global_transform.orthonormalized()


## Handles player input
func get_input(delta):
	var vy = velocity.y
	var accel : float = Input.get_axis("back", "forward")
	var turn : float = Input.get_axis("right", "left")

	if(turn == 0): #re-center
		curr_turn_angle = lerp_angle(curr_turn_angle, 0.0, delta*recenter_speed)
	else:
		curr_turn_angle = lerp_angle(curr_turn_angle, deg_to_rad(max_turn_angle) * turn, delta*turn_speed)
	
	
	$TestRay.rotation.y = curr_turn_angle
	$CarModel.rotation.y = deg_to_rad(180)+(curr_turn_angle / 2.0)
	rotate_y(curr_turn_angle * delta * true_turn_speed)
	if(accel != 0):
		velocity += -transform.basis.z * accel * speed * delta
		for wheel in wheels:
			pass
			wheel.rotate_x(delta*50 * accel)
	elif (velocity.length() > 0):
		velocity += -transform.basis.z * delta
		velocity += -velocity * deaccel * delta
	#front_left_wheel.rotate_y(curr_turn_angle)
	#front_right_wheel.rotate_y(curr_turn_angle)
	velocity = velocity.limit_length(maxspeed)
	velocity.y = vy


var accel_input = 0.0
var acceleration = 0.0
var curr_rpm = 0.0
var max_rpm = 0.0
var brake_force = 0.0
var friction = 2.0
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
	#increase velocity by speed
	#velocity = lerp (velocity, velocity + (-transform.basis.z*curr_rpm), delta)
	#arc velocity towards facing
	#velocity = lerp(velocity, velocity * deg_to_rad(curr_turn_angle), delta)
	#velocity.limit_length(max_rpm)
	var wheel_basis = transform.rotated(transform.basis.y, deg_to_rad(curr_turn_angle)).basis
	var turn_ratio =  clampf(1 - (abs(curr_turn_angle)/max_slip_angle), 0.25, 1.0)
	#var heading = -wheel_basis.z
	var heading = -global_transform.basis.z
	var rpm_ratio = curr_rpm/max_rpm
	var impact = velocity.normalized().dot(heading.normalized())
	if(impact == 0): impact = 1
	#print(impact)
	velocity += curr_rpm * heading * turn_ratio
	var vel_cap = max_rpm
	velocity = velocity.limit_length(vel_cap)
	velocity = lerp(velocity, Vector3.ZERO, friction * delta)
	#velocity = lerp(Vector3.ZERO, max_rpm * heading, rpm_ratio * turn_ratio)
	velocity.y = vy


# Turning variables
var just_started_accel : bool = false
var turn_input = 0.0
#var curr_turn_angle : float = 0.0 # the current turning angle
var queued_turn_angle : float = 0.0 # the turn angle we-ll hit on acceleration
#var max_turn_angle : float = 45.0 # the maximum turn angle, in degrees
var max_slip_angle : float = 60.0 # the maximum angle, in degrees, of a slip
var turn_angle_speed : float = 45.0 # the angle change per frame, in degrees, of our target angle
var turn_center_speed : float = 50.0
var turn_snap_speed : float = 1.0 # the angle change per frame, in degrees, of the actual car
var is_slipping : bool = false # whether we're slipping
var max_angle_timer : float = 0.0 # How long we've been at the max turn angle
var max_angle_timer_top : float = 1.0 # How many seconds at max angle before we slip
## Handles turning
func handle_turning(delta) -> void:
	#print(curr_turn_angle)
	DebugDraw3D.draw_arrow_ray(global_position + Vector3(0,0.5,0), velocity.normalized(), 0.5, Color.RED, 0.1)
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
				var nsign = sign(curr_turn_angle)
				var qsign = sign(queued_turn_angle)
				queued_turn_angle -= sign(curr_turn_angle) * (turn_center_speed * 2) * delta
				curr_turn_angle -= sign(curr_turn_angle) * turn_center_speed * delta
				if(sign(curr_turn_angle) != nsign): curr_turn_angle = 0.0
				if(sign(queued_turn_angle) != qsign): queued_turn_angle = 0.0
		elif(just_started_accel): # Otherwise, if we just started accelerating, we should snap curr_turn_angle to match
			curr_turn_angle = queued_turn_angle
			queued_turn_angle = 0
		else: # Otherwise, we should increase our curr_turn_angle based on input
			if(turn_input != 0):
				curr_turn_angle += turn_input * turn_angle_speed * delta
				curr_turn_angle = clampf(curr_turn_angle, -max_turn_angle, max_turn_angle) #clamp the max_turn_angle
			else:
				var nsign = sign(curr_turn_angle)
				curr_turn_angle -= sign(curr_turn_angle) * turn_center_speed * delta
				if(sign(curr_turn_angle) != nsign): curr_turn_angle = 0.0
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
	#$CarModel.rotation.y = deg_to_rad(curr_turn_angle) + (TAU/2)
	var vel_angle = atan2(velocity.x, velocity.z)
	if(curr_rpm > 0):
		pass
		var inv_rpm_ratio = 1- (curr_rpm/max_rpm)
	self.rotation.y = lerp_angle(self.rotation.y, deg_to_rad(curr_turn_angle) + self.rotation.y, 3 * delta)


## Takes [xform] and snaps its y axis to [new_y]
func align_with_y(xform : Transform3D, new_y : Vector3) -> Transform3D:
	xform.basis.y = new_y
	#xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis.x = new_y.cross(xform.basis.z)
	xform.basis = xform.basis.orthonormalized()
	return xform.orthonormalized()


## Takes [mesh_instance] and points [a],[b],[c], and draws a triangle.
func draw_mesh_from_ponts(mesh_instance : MeshInstance3D, a: Vector3, b : Vector3, c : Vector3) -> void:
	var mesh : Mesh = mesh_instance.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_add_vertex(c)
	mesh.surface_end()


func _get_floorplane_normal() -> Vector3:
	for ray in ground_rays:
		#DebugDraw3D.draw_sphere(ray.get_collision_point(), 0.1)
		ray.force_raycast_update()
	# ground rays are ordered FL, FR, BL, BR
	var fl = ground_rays[0].get_collision_point()
	var fr = ground_rays[1].get_collision_point()
	var bl = ground_rays[2].get_collision_point()
	var br = ground_rays[3].get_collision_point()
	var surf_1_normal = get_normal_from_points(fl,fr,bl)
	var surf_2_normal = get_normal_from_points(fr,br,bl)
	var z = -(surf_1_normal + surf_2_normal)/2.0
	DebugDraw3D.draw_arrow_ray(position, z, 1, Color(0,0,0,0), 0.01)
	return z


func get_normal_from_points(p1, p2, p3) -> Vector3:
	var A = p2 - p1
	var B = p3 - p1
	return A.cross(B).normalized()


func _align_with_floor(delta) -> void:
	var floor_normal : Vector3 = _get_floorplane_normal()
	if(Input.is_action_just_pressed("q")):
		print(is_on_floor())
		print(floor_normal)
		print(floor_normal.length())
	if(is_on_floor() and floor_normal.length() > 0.0):
		var xform = align_with_y(global_transform, floor_normal)
		global_transform = global_transform.interpolate_with(xform, ground_snap_speed * delta)
	elif(is_on_floor() == false):
		var xform = align_with_y(global_transform, Vector3.UP)
		global_transform = global_transform.interpolate_with(xform, fall_tilt_speed * delta)
