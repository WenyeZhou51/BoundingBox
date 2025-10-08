extends BasePrefab

func _ready():
	object_label = "Gun"
	confidence = 0.97
	is_interactable = false  # Initially not interactable until safe is opened
	interaction_text = "TAKE"
	
	super._ready()  # Call parent's _ready function

func interact():
	if not is_interactable:
		return
	
	print("Gun taken from safe!")
	
	# Get the player and update their weapon status
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Play gun pickup sound
		var pickup_gun_audio = player.get_node_or_null("PickupGunAudio")
		if pickup_gun_audio:
			pickup_gun_audio.play()
		
		# Update player's weapon status
		if player.has_method("pickup_weapon"):
			player.pickup_weapon("Revolver")
	
	# Remove the gun from the scene
	queue_free()

# Override the vision mode visibility function
func should_be_visible_in_vision_mode() -> bool:
	return is_interactable  # Only visible when interactable (safe is open)
