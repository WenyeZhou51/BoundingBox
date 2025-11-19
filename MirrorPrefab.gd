extends BasePrefab

@export var detection_distance: float = 8.0  # Distance to detect player near mirror

var player_near: bool = false
var player_node: Node = null
var is_broken: bool = false

# OPTIMIZATION: Reduce check frequency
var frame_counter: int = 0
var check_interval: int = 3  # Only check every 3 frames instead of every frame

# Preload the broken glass scene
var broken_glass_scene = preload("res://BrokenGlassPrefab.tscn")

# Audio node
@onready var mirror_shatter_audio: AudioStreamPlayer = $MirrorShatterAudio

func _ready():
	# Mirror is interactable (left-click and F key)
	# When player is near, shows as "Trash" with red label
	object_label = "Mirror"
	confidence = 0.0
	is_interactable = true
	interaction_text = ""  # Empty string - don't show [INTERACT] text
	
	# Find the player node
	player_node = get_tree().get_first_node_in_group("player")
	
	super._ready()

func _process(_delta):
	# Check if player is near the mirror (only if not broken)
	if not is_broken:
		frame_counter += 1
		if frame_counter >= check_interval:
			frame_counter = 0
			check_player_proximity()

func check_player_proximity():
	if not player_node:
		player_near = false
		return
	
	var mirror_pos = global_position
	var player_pos = player_node.global_position
	
	# Check distance to player
	var distance_squared = mirror_pos.distance_squared_to(player_pos)
	var detection_distance_squared = detection_distance * detection_distance
	
	var was_near = player_near
	player_near = distance_squared <= detection_distance_squared
	
	# Update label when player gets near/far
	if player_near and not was_near:
		object_label = "Trash"
		confidence = 0.92
		print("Mirror: Player approached - showing Trash label")
	elif not player_near and was_near:
		object_label = "Mirror"
		confidence = 0.0
		print("Mirror: Player left - hiding label")

# Override the should_be_visible_in_vision_mode function
func should_be_visible_in_vision_mode() -> bool:
	# Show mirror in vision mode only if broken OR if player is near
	if is_broken:
		return true
	return player_near

# Return custom scale factor for bounding box to make it appear "inside" the mirror
# This makes the bounding box 30% smaller on each side (70% of original size)
func get_bounding_box_scale() -> float:
	if player_near and not is_broken:
		return 0.7  # 30% smaller
	return 1.0

# Shared logic for breaking the mirror
func _break_mirror():
	print("MirrorPrefab: _break_mirror() called!")
	if is_broken:
		print("Mirror is already broken!")
		return
	
	print("Breaking mirror! Spawning 5 broken glass pieces (2 straight down, 3 scattered)...")
	
	# Play mirror shatter sound
	if mirror_shatter_audio:
		mirror_shatter_audio.play()
	
	is_broken = true
	
	# Spawn broken glass pieces
	spawn_broken_glass()
	
	# Transform this mirror into a mirror frame (no end sequence trigger)
	transform_to_mirror_frame()

# Handle left-click interaction to break the mirror
func interact():
	# Left-click interaction will be routed here by FirstPersonController.handle_interaction()
	_break_mirror()

# Preserve right-click handler (in case anything still calls it), but delegate to shared logic
func right_click_interact():
	print("MirrorPrefab: right_click_interact() called!")
	_break_mirror()

func spawn_broken_glass():
	var mirror_pos = global_position
	var mirror_forward = -global_transform.basis.z
	var mirror_right = global_transform.basis.x
	var mirror_up = global_transform.basis.y
	
	# Get reference to the FirstPersonController to add glass pieces to detected objects
	var player = get_tree().get_first_node_in_group("player")
	
	# Spawn 5 pieces of broken glass total: 2 fall straight down, 3 scatter around
	for i in range(5):
		var glass_piece = broken_glass_scene.instantiate()
		
		# Position glass pieces slightly in front of the mirror
		var offset_x = randf_range(-1.2, 1.2)  # Spread across mirror width
		var offset_y = randf_range(-1.5, 1.5)  # Spread across mirror height
		var spawn_pos = mirror_pos + mirror_right * offset_x + mirror_up * offset_y + mirror_forward * 0.2
		
		glass_piece.global_position = spawn_pos
		
		# First 2 pieces fall straight down, remaining 3 scatter around
		var velocity: Vector3
		if i < 2:
			# Make first 2 pieces fall straight down (no horizontal velocity)
			velocity = Vector3(0, -2.0, 0)
			print("Spawned broken glass piece ", i + 1, " at ", spawn_pos, " falling straight down")
		else:
			# Make remaining 3 pieces scatter around with random horizontal velocity
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
	# End sequence should no longer be triggered by this mirror.
	print("MirrorPrefab: trigger_end_sequence() called, but end sequence is now disabled for this mirror.")
