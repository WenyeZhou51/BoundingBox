extends BasePrefab

var collision_shape: CollisionShape3D
var mesh_instance: MeshInstance3D

func _ready():
	object_label = "Door"
	confidence = 0.95
	is_interactable = true
	interaction_text = "Locked from other side"
	
	collision_shape = $CollisionShape3D
	mesh_instance = $DoorPivot/MeshInstance3D
	
	super._ready()

func interact():
	# This door cannot be opened from this side
	print("Door is locked from the other side")
	# You could add a sound effect here if desired

