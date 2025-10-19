extends BasePrefab

func _ready():
	object_label = "Watch"
	confidence = 0.9
	is_interactable = true
	interaction_text = "PICK UP"
	super._ready()

func interact():
	print("Picked up watch")
	queue_free()

