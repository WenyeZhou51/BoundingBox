extends BasePrefab

func _ready():
	object_label = "Access Card"
	confidence = 0.94
	is_interactable = true
	interaction_text = "Pick Up"
	super._ready()

func interact():
	print("Picked up access card!")
	# Could add functionality to unlock doors, etc.
	# For now, just hide it when picked up
	visible = false
	is_interactable = false
