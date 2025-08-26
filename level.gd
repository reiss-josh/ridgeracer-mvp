extends Node3D

@onready var Speedometer : ProgressBar = self.get_node("CanvasLayer/EngineContainer/Speedometer")
@onready var Tachiometer : ProgressBar = self.get_node("CanvasLayer/EngineContainer/Tachiometer")
@onready var SpeedText : Label = self.get_node("CanvasLayer/EngineContainer/Speedometer/SpeedText")
@onready var RPMText : Label = self.get_node("CanvasLayer/EngineContainer/Tachiometer/RPMText")
@onready var GearText : Label = self.get_node("CanvasLayer/EngineContainer/GearBox/GearText")
@onready var TurnBar : ProgressBar = self.get_node("CanvasLayer/TurnContainer/TurnBar")
@onready var TurnText : Label = self.get_node("CanvasLayer/TurnContainer/TurnBar/TurnText")
@onready var car : FastCar = self.get_node("FastCar")


func _ready() -> void:
	#engine
	Speedometer.max_value = car.gear_top_speeds.back()
	Tachiometer.max_value = car.max_rpm
	Speedometer.min_value = 0
	Tachiometer.min_value = 0
	TurnBar.min_value = -car.max_slip_angle
	TurnBar.max_value = car.max_slip_angle
	#QueuedTurnBar.min_value = -car.max_slip_angle
	#QueuedTurnBar.max_value = car.max_slip_angle


func _process(_delta):
	var speed = car.curr_speed
	var rpm = car.curr_rpm * car.max_rpm
	var gear = car.curr_gear
	#var angle = -car.curr_turn_angle
	var angle = 0
	#var qangle = -car.queued_turn_angle
	Speedometer.value = speed
	Tachiometer.value = rpm
	SpeedText.text = str(snapped(speed, 0.1)) + " MPH"
	RPMText.text = str(snapped(rpm,0.1)) + " RPM"
	TurnBar.value = angle
	TurnText.text = str(snapped(angle, 0.1))
	GearText.text = str(gear)
	#QueuedTurnBar.value = qangle
	#QueuedTurnText.text = str(snapped(qangle, 0.1))
