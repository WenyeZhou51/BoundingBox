extends Area3D

var triggered: bool = false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Only trigger once when player enters
	if not triggered and body.is_in_group("player"):
		triggered = true
		trigger_battery_low(body)

func trigger_battery_low(player):
	print("Battery Low triggered!")
	
	# Call the battery low function on the player
	if player.has_method("activate_battery_saving_mode"):
		player.activate_battery_saving_mode()
