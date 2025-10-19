extends BasePrefab

var collision_shape: CollisionShape3D
var mesh_instance: MeshInstance3D

func _ready():
	object_label = "Elevator"
	confidence = 0.95
	is_interactable = true
	interaction_text = "Elevator depowered"
	
	collision_shape = $CollisionShape3D
	mesh_instance = $DoorPivot/MeshInstance3D
	
	super._ready()

func interact():
	# This elevator door cannot be opened
	print("Elevator is depowered - cannot be used")
	# You could add a sound effect here if desired

