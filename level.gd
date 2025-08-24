extends Node3D

@onready var SpeedBar : ProgressBar = self.get_node("CanvasLayer/SpeedBar")
@onready var SpeedText : Label = self.get_node("CanvasLayer/SpeedBar/SpeedText")
@onready var TurnBar : ProgressBar = self.get_node("CanvasLayer/TurnBar")
@onready var TurnText : Label = self.get_node("CanvasLayer/TurnBar/TurnText")
@onready var QueuedTurnBar : ProgressBar = self.get_node("CanvasLayer/QueuedTurnBar")
@onready var QueuedTurnText : Label = self.get_node("CanvasLayer/QueuedTurnBar/TurnText")
@onready var car : FastCar = self.get_node("FastCar")

func _ready() -> void:
	SpeedBar.max_value = car.max_rpm
	TurnBar.min_value = -car.max_slip_angle
	TurnBar.max_value = car.max_slip_angle
	QueuedTurnBar.min_value = -car.max_slip_angle
	QueuedTurnBar.max_value = car.max_slip_angle

func _process(_delta):
	var rpm = car.curr_rpm
	var angle = -car.curr_turn_angle
	var qangle = -car.queued_turn_angle
	SpeedBar.value = rpm
	SpeedText.text = str(snapped(rpm, 0.1))
	TurnBar.value = angle
	TurnText.text = str(snapped(angle, 0.1))
	QueuedTurnBar.value = qangle
	QueuedTurnText.text = str(snapped(qangle, 0.1))
