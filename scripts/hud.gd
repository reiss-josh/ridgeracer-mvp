extends CanvasLayer

@onready var Speedometer : ProgressBar = self.get_node("EngineContainer/Speedometer")
@onready var Tachiometer : ProgressBar = self.get_node("EngineContainer/Tachiometer")
@onready var SpeedText : Label = self.get_node("EngineContainer/Speedometer/SpeedText")
@onready var RPMText : Label = self.get_node("EngineContainer/Tachiometer/RPMText")
@onready var GearText : Label = self.get_node("EngineContainer/GearBox/GearText")
@onready var TurnBar : ProgressBar = self.get_node("TurnContainer/TurnBar")
@onready var TurnText : Label = self.get_node("TurnContainer/TurnBar/TurnText")


## Update HUD min/max values
func set_values(max_speed : float = 0.0, max_rpm : float = 0.0, max_turn : float = 0.0) -> void:
	Speedometer.max_value = max_speed
	Tachiometer.max_value = max_rpm
	TurnBar.max_value = max_turn
	TurnBar.min_value = -max_turn
	#QueuedTurnBar.min_value = -car.max_slip_angle
	#QueuedTurnBar.max_value = car.max_slip_angle


## Update stored hud values
func update_values(speed : float = 0.0, rpm : float = 0.0, angle : float = 0.0, gear : int = 0) -> void:
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
