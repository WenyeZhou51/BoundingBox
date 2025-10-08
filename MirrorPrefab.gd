extends BasePrefab

@export var detection_distance: float = 5.0  # Distance to detect player in front of mirror
@export var detection_angle: float = 90.0    # Angle in degrees for detection cone

var player_reflection_active: bool = false
var player_node: Node = null
var is_broken: bool = false

# Preload the broken glass scene
var broken_glass_scene = preload("res://BrokenGlassPrefab.tscn")

# Audio node
@onready var mirror_shatter_audio: AudioStreamPlayer = $MirrorShatterAudio

func _ready():
	# Mirror itself has no label and is not interactable
	object_label = ""
	confidence = 0.0
	is_interactable = false
	
	# Find the player node
	player_node = get_tree().get_first_node_in_group("player")
	
	super._ready()

func _process(_delta):
	# Only check for reflections if mirror isn't broken
	if not is_broken:
		check_player_reflection()

func check_player_reflection() -> bool:
	if not player_node:
		player_reflection_active = false
		return false
	
	var mirror_pos = global_position
	var player_pos = player_node.global_position
	var mirror_forward = -global_transform.basis.z  # Mirror faces forward (-z direction)
	
	# Calculate vector from mirror to player
	var to_player = player_pos - mirror_pos
	var distance = to_player.length()
	
	# Debug prints
	var was_active = player_reflection_active
	
	# Check if player is within detection distance
	if distance > detection_distance:
		player_reflection_active = false
		if was_active:
			print("Mirror: Player too far away (", distance, " > ", detection_distance, ")")
		return false
	
	# Check if player is in front of the mirror (not behind it)
	var dot_product = mirror_forward.dot(to_player.normalized())
	if dot_product < 0:  # Player is behind the mirror
		player_reflection_active = false
		if was_active:
			print("Mirror: Player behind mirror (dot: ", dot_product, ")")
		return false
	
	# Check if player is within the detection angle
	var angle = acos(dot_product) * 180.0 / PI
	if angle > detection_angle / 2.0:
		player_reflection_active = false
		if was_active:
			print("Mirror: Player outside angle (", angle, " > ", detection_angle / 2.0, ")")
		return false
	
	# Player is in front of the mirror within range and angle
	if not was_active:
		print("Mirror: Player reflection activated! Distance: ", distance, ", Angle: ", angle)
	player_reflection_active = true
	return true

# Override the should_be_visible_in_vision_mode function
func should_be_visible_in_vision_mode() -> bool:
	# If broken, show as mirror frame in vision mode
	if is_broken:
		return true
	# Mirror itself should not be visible in vision mode
	# Only the reflection should be visible when player is in front
	return false

# This function will be called by the FirstPersonController to get reflection info
func get_player_reflection_info() -> Dictionary:
	if not player_reflection_active or not player_node or is_broken:
		return {"active": false}
	
	# Calculate the reflection position (mirror the player's position across the mirror plane)
	var mirror_pos = global_position
	var player_pos = player_node.global_position
	var mirror_forward = -global_transform.basis.z
	var mirror_right = global_transform.basis.x
	var mirror_up = global_transform.basis.y
	
	# Project player position onto mirror plane
	var to_player = player_pos - mirror_pos
	var distance_to_plane = to_player.dot(mirror_forward)
	
	# Calculate reflection position (mirror the player across the mirror plane)
	var reflection_pos = player_pos - 2 * distance_to_plane * mirror_forward
	
	print("Mirror: Returning reflection info - active: true, pos: ", reflection_pos)
	
	return {
		"active": true,
		"position": reflection_pos,
		"label": "Player",
		"confidence": 1.0
	}

# Handle right-click interaction to break the mirror
func right_click_interact():
	print("MirrorPrefab: right_click_interact() called!")
	if is_broken:
		print("Mirror is already broken!")
		return
	
	print("Breaking mirror! Spawning 10 broken glass pieces (3 straight down, 7 scattered)...")
	
	# Play mirror shatter sound
	if mirror_shatter_audio:
		mirror_shatter_audio.play()
	
	is_broken = true
	
	# Spawn 7 broken glass pieces with downward velocities
	spawn_broken_glass()
	
	# Transform this mirror into a mirror frame
	transform_to_mirror_frame()
	
	# Trigger the end sequence
	trigger_end_sequence()

func spawn_broken_glass():
	var mirror_pos = global_position
	var mirror_forward = -global_transform.basis.z
	var mirror_right = global_transform.basis.x
	var mirror_up = global_transform.basis.y
	
	# Get reference to the FirstPersonController to add glass pieces to detected objects
	var player = get_tree().get_first_node_in_group("player")
	
	# Spawn 10 pieces of broken glass total: 3 fall straight down, 7 scatter around
	for i in range(10):
		var glass_piece = broken_glass_scene.instantiate()
		
		# Position glass pieces slightly in front of the mirror
		var offset_x = randf_range(-1.2, 1.2)  # Spread across mirror width
		var offset_y = randf_range(-1.5, 1.5)  # Spread across mirror height
		var spawn_pos = mirror_pos + mirror_right * offset_x + mirror_up * offset_y + mirror_forward * 0.2
		
		glass_piece.global_position = spawn_pos
		
		# First 3 pieces fall straight down, remaining 7 scatter around
		var velocity: Vector3
		if i < 3:
			# Make first 3 pieces fall straight down (no horizontal velocity)
			velocity = Vector3(0, -2.0, 0)
			print("Spawned broken glass piece ", i + 1, " at ", spawn_pos, " falling straight down")
		else:
			# Make remaining 7 pieces scatter around with random horizontal velocity
			var horizontal_speed = randf_range(1.0, 3.0)
			var scatter_angle = randf_range(0, 2 * PI)  # Random direction
			var horizontal_velocity = Vector3(
				cos(scatter_angle) * horizontal_speed,
				0,
				sin(scatter_angle) * horizontal_speed
			)
			# Add downward velocity plus horizontal scattering
			velocity = Vector3(0, -2.0, 0) + horizontal_velocity
			print("Spawned broken glass piece ", i + 1, " at ", spawn_pos, " scattering with velocity ", velocity)
		
		# Add the glass piece to the scene
		get_tree().current_scene.add_child(glass_piece)
		
		# Set the initial velocity
		glass_piece.set_initial_velocity(velocity)
		
		# Add to detected objects list so it shows up in vision mode
		if player and player.has_method("add_detected_object"):
			player.add_detected_object(glass_piece)

func transform_to_mirror_frame():
	# Transform this mirror object into a mirror frame
	object_label = "Mirror Frame"
	confidence = 0.95
	is_interactable = false
	
	# Make sure it's visible in vision mode
	print("Transformed mirror into Mirror Frame with 95% confidence")

func trigger_end_sequence():
	print("MirrorPrefab: trigger_end_sequence() called!")
	# Find the player and trigger the end sequence
	var player = get_tree().get_first_node_in_group("player")
	print("MirrorPrefab: Found player: ", player)
	if player and player.has_method("trigger_end_sequence"):
		print("MirrorPrefab: Triggering end sequence through player...")
		player.trigger_end_sequence()
	else:
		print("Error: Player not found or doesn't have trigger_end_sequence method!")
