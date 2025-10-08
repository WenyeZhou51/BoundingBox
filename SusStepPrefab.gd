extends BasePrefab
class_name SusStepPrefab

func _ready():
	# Set the sus step properties - looks like a step but with different label/confidence
	object_label = "step"
	confidence = 0.34
	is_interactable = false  # Steps are not interactable
	
	# Call parent ready
	super._ready()
