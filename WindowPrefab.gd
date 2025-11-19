extends BasePrefab

var player: Node3D = null

func _ready():
	object_label = "Window"
	confidence = 0.92
	is_interactable = true
	interaction_text = "LOOK OUTSIDE"
	super._ready()
	
	# Get reference to player
	await get_tree().process_frame  # Wait one frame for player to be added to group
	player = get_tree().get_first_node_in_group("player")

func interact():
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	# Check if player is holding trash
	if player and player.get("held_trash") and player.held_trash != null:
		print("Throwing trash out the window!")
		throw_out_trash()
	else:
		print("Looking outside the window... nothing special.")

func throw_out_trash():
	if not player or not player.held_trash:
		return
	
	var trash = player.held_trash
	print("Throwing out: ", trash.object_label)
	
	# Decrement the global trash counter
	if player.has_method("decrement_trash_counter"):
		player.decrement_trash_counter()
	
	# Remove the trash object from the scene
	trash.queue_free()
	
	# Clear the held_trash reference
	player.held_trash = null

# Override should_be_visible to always be visible
func should_be_visible_in_vision_mode() -> bool:
	return true

