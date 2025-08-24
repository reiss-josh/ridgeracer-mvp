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
