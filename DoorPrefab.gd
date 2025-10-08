extends BasePrefab

@export var disappear_duration: float = 5.0  # Seconds the door stays disappeared

var is_disappeared: bool = false
var disappear_timer: Timer
var collision_shape: CollisionShape3D
var mesh_instance: MeshInstance3D
var door_open_audio: AudioStreamPlayer

func _ready():
	object_label = "Door"
	confidence = 0.95
	is_interactable = true
	interaction_text = "OPEN"
	collision_shape = $CollisionShape3D
	mesh_instance = $DoorPivot/MeshInstance3D  # The mesh is inside the DoorPivot
	door_open_audio = $DoorOpenAudio
	
	# Create and configure disappear timer
	disappear_timer = Timer.new()
	disappear_timer.wait_time = disappear_duration
	disappear_timer.one_shot = true
	disappear_timer.timeout.connect(_on_disappear_timeout)
	add_child(disappear_timer)
	
	# Debug: Print door position
	print("Door positioned at: ", global_position)
	
	super._ready()  # Call parent's _ready function

func interact():
	if is_disappeared:
		return  # Don't allow interaction while disappeared
	
	# Play door opening sound
	if door_open_audio:
		print("Playing door open sound...")
		door_open_audio.play()
	else:
		print("Error: door_open_audio is null!")
	
	disappear_door()

func disappear_door():
	if is_disappeared:
		return
	
	is_disappeared = true
	
	# Hide the door visually and disable collision
	if mesh_instance:
		mesh_instance.visible = false
	collision_shape.disabled = true
	
	print("Door disappeared - will reappear in ", disappear_duration, " seconds")
	
	# Start disappear timer
	disappear_timer.wait_time = disappear_duration
	disappear_timer.start()

func _on_disappear_timeout():
	print("Checking if door can reappear...")
	
	# Check if player is standing in the doorway
	if is_player_in_doorway():
		print("Player is in doorway - delaying door reappearance")
		# Check again in 0.5 seconds
		disappear_timer.wait_time = 0.5
		disappear_timer.start()
		return
	
	reappear_door()

func reappear_door():
	is_disappeared = false
	
	# Show the door visually and enable collision
	if mesh_instance:
		mesh_instance.visible = true
	collision_shape.disabled = false
	
	print("Door reappeared")

func is_player_in_doorway() -> bool:
	# Get the player (FirstPersonController) from the group
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("Warning: Could not find player in group - assuming doorway is clear")
		return false
	
	# Check if player's position overlaps with the door's collision area
	var door_aabb = get_door_aabb()
	var player_pos = player.global_position
	
	# Expand the door area slightly to account for player size
	var expanded_aabb = door_aabb.grow(0.5)  # Add 0.5 units padding on all sides
	
	return expanded_aabb.has_point(player_pos)

func _find_character_body_recursive(node: Node) -> CharacterBody3D:
	if node is CharacterBody3D:
		return node as CharacterBody3D
	
	for child in node.get_children():
		var result = _find_character_body_recursive(child)
		if result:
			return result
	
	return null

func get_door_aabb() -> AABB:
	# Get the door's collision shape bounds
	if collision_shape and collision_shape.shape:
		var shape = collision_shape.shape
		var aabb = AABB()
		
		if shape is BoxShape3D:
			var box_shape = shape as BoxShape3D
			var size = box_shape.size
			aabb = AABB(-size/2, size)
		elif shape is CapsuleShape3D:
			var capsule_shape = shape as CapsuleShape3D
			var radius = capsule_shape.radius
			var height = capsule_shape.height
			aabb = AABB(Vector3(-radius, -height/2, -radius), Vector3(radius*2, height, radius*2))
		else:
			# Default fallback - use a reasonable door-sized area
			aabb = AABB(Vector3(-0.5, 0, -1), Vector3(1, 2, 2))
		
		# Transform to global coordinates
		return collision_shape.global_transform * aabb
	else:
		# Fallback - use object position with reasonable door dimensions
		var pos = global_position
		return AABB(pos + Vector3(-0.5, 0, -1), Vector3(1, 2, 2))

# Override the vision mode visibility function
func should_be_visible_in_vision_mode() -> bool:
	return !is_disappeared  # Door is not visible in vision mode when it's disappeared
