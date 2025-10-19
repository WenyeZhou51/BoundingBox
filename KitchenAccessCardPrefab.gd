extends BasePrefab

func _ready():
	object_label = "Kitchen Access Card"
	confidence = 0.96
	is_interactable = true
	interaction_text = "Pick Up"
	super._ready()

func interact():
	print("Picked up kitchen access card!")
	
	# Find the player and notify them of pickup
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("pickup_kitchen_access_card"):
		player.pickup_kitchen_access_card()
	
	# Hide the card
	visible = false
	is_interactable = false
