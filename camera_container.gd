extends Node3D

@onready var parent_car : FastCar = self.get_parent() #TODO: BAD!!! BAD!!!


func _physics_process(delta: float) -> void:
	var parent_velocity : Vector3 = parent_car.velocity
	
	#rotation.y = deg_to_rad(parent_car.curr_turn_angle)
