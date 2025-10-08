extends BasePrefab
class_name StepPrefab

func _ready():
	# Set the step properties
	object_label = "Step"
	confidence = 0.95
	is_interactable = false  # Steps are not interactable
	
	# Call parent ready
	super._ready()
