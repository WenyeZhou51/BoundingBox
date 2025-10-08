extends BasePrefab

var has_interacted: bool = false

func _ready():
	object_label = "Photo"
	confidence = 0.4
	is_interactable = true
	interaction_text = "Look at"
	
	super._ready()  # Call parent's _ready function

func interact():
	if not has_interacted:
		print("Interacting with photo...")
		print("Photo of a large pile of meat")
		
		# Change label to "Window" and make it non-interactable
		object_label = "Window"
		is_interactable = false
		has_interacted = true
		
		print("Photo has been examined. Label changed to: ", object_label)
	else:
		print("This is now a ", object_label, " - no longer interactable")

