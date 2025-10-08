extends BasePrefab

var is_broken: bool = false
var rigid_body: RigidBody3D
var collision_shape: CollisionShape3D
var mesh_instance: MeshInstance3D
var parent_locked_door: Node3D

func _ready():
	object_label = "Lock"
	confidence = 0.95
	is_interactable = false  # Not interactable, only shootable
	is_shootable = true  # Can be shot with the gun
	super._ready()
	
	# Get references to components
	rigid_body = $RigidBody3D
	collision_shape = $RigidBody3D/CollisionShape3D
	mesh_instance = $RigidBody3D/MeshInstance3D
	
	# Find the parent locked door
	parent_locked_door = get_parent()
	
	# Initially the lock should be static (not affected by physics)
	if rigid_body:
		rigid_body.gravity_scale = 0.0
		rigid_body.freeze = true

# Called when the lock is shot
func right_click_interact():
	if is_broken:
		return  # Already broken
	
	print("Lock shot! Breaking lock...")
	break_lock()

func break_lock():
	if is_broken:
		return
	
	is_broken = true
	object_label = "Broken lock"
	
	# Enable physics for the lock so it falls
	if rigid_body:
		rigid_body.gravity_scale = 1.0
		rigid_body.freeze = false
		# Add some force to make it fall more realistically
		rigid_body.apply_impulse(Vector3(0, -0.5, 0))
	
	# Change the locked door to a normal door
	if parent_locked_door and parent_locked_door.has_method("convert_to_normal_door"):
		parent_locked_door.convert_to_normal_door()
	
	print("Lock broken! Door is now unlocked.")

# Override the vision mode visibility function
func should_be_visible_in_vision_mode() -> bool:
	return true  # Lock is always visible in vision mode
