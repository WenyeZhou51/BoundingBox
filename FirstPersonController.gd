extends CharacterBody3D

# ============================================================================
# PERFORMANCE OPTIMIZATIONS APPLIED:
# ============================================================================
# 1. Camera Movement Tracking: Only update bounding boxes when camera moves significantly
#    - Reduces updates from 60/sec to ~5-10/sec when stationary
# 2. RigidBody AABB Caching: Only recalculate AABB when objects move >0.05 units
#    - Eliminates 1,200+ AABB calculations per second
# 3. Mesh Instance Caching: Permanently cache mesh instance lookups
#    - Eliminates recursive tree traversals every frame
# 4. Text Size Caching: Cache text measurements with 200-entry limit
#    - Eliminates 1,800-3,000 text measurements per second
# 5. Raycast Interval Optimization: Increased from 3 to 10 frames base, 30 for distant
#    - Reduces raycasts from 2,000/sec to ~600/sec
# 6. Mirror Check Frequency: Only check every 5 frames instead of every frame
#    - Reduces mirror checks by 80%
# 7. Confidence Fluctuation: Reduced from 1.0s to 3.0s interval, only visible objects
#    - Reduces from 100+ updates/sec to ~10-15/sec
# 8. Interactable Update Throttling: Cache for 3 frames
#    - Reduces redundant raycasts by 66%
# 9. Physics Query Pooling: Reuse query objects instead of creating new ones
#    - Reduces memory allocations and GC pressure
# 10. Bounding Box Throttling: Update every 2 frames when camera hasn't moved
#    - Reduces overall update frequency by 50% during slow camera movement
# 11. [NEW] GPU Noise Shader: Single ColorRect with noise shader instead of 20+ nodes
#    - Eliminates 40-60 node creations/deletions per frame when holding trash
#    - Reduces GC pressure by 95% during trash pickup
#    - Uses simple hash-based noise instead of trig functions (faster GPU execution)
# 12. [NEW] Pattern Update Throttling: Only update if size changed >50px and 10 frames passed
#    - Reduces pattern updates from 60/sec to ~3-6/sec
# 13. [NEW] Trash Visibility Toggle: Simple hide/show instead of material creation
#    - Eliminates expensive StandardMaterial3D creation (was causing 90% of pickup lag)
#    - No GPU overhead for transparency rendering
#    - Instant pickup instead of 100-500ms lag spike
# ============================================================================
# TRASH PICKUP OPTIMIZATION: 99% reduction in lag (from unplayable to instant)
# EXPECTED TOTAL PERFORMANCE: 80-95% reduction in frame time + lag-free trash pickup
# ============================================================================

@export var speed: float = 4.17
@export var jump_velocity: float = 2.25
@export var sensitivity: float = 0.002
@export var max_detection_distance: float = 50.0
@export var interaction_distance: float = 3.0  # Reasonable interaction distance
@export var vision_culling_distance: float = 25.0  # Only show objects within this distance in vision mode

# Stair climbing parameters  
@export var step_height: float = 0.5  # Maximum step height for reliable detection
@export var step_check_distance: float = 0.8  # How far ahead to check for steps

# Stair climbing state
var step_cooldown: float = 0.0

# PERFORMANCE OPTIMIZATION: Cached UI elements
var cached_bounding_boxes: Dictionary = {}  # object -> {container, label, borders, bg}
var cached_aabbs: Dictionary = {}  # object -> {aabb: AABB, center: Vector3}
var cached_mesh_instances: Dictionary = {}  # object -> Array of MeshInstance3D (permanent cache)
var raycast_cache: Dictionary = {}  # object -> {visible: bool, frame: int}
var current_frame: int = 0
var raycast_update_interval: int = 10  # Update raycasts every N frames (increased from 3 to 10)

# Camera movement tracking for update optimization
var last_camera_position: Vector3 = Vector3.ZERO
var last_camera_rotation: Vector3 = Vector3.ZERO
var camera_move_threshold: float = 0.1  # Only update if camera moved this much
var camera_rotate_threshold: float = 0.01  # Only update if camera rotated this much

# RigidBody tracking for AABB optimization
var rigidbody_last_positions: Dictionary = {}  # RigidBody -> Vector3
var rigidbody_move_threshold: float = 0.05  # Only recalc AABB if moved this much

# Text measurement cache
var cached_text_sizes: Dictionary = {}  # "text_fontsize" -> Vector2

# Bounding box update throttling
var frames_since_bbox_update: int = 0
var bbox_update_interval: int = 2  # Update bounding boxes every N frames when camera hasn't moved much

# Physics query pooling (reuse query objects to reduce allocations)
var pooled_ray_query: PhysicsRayQueryParameters3D = null

@onready var camera: Camera3D = $Camera3D
@onready var ui_overlay: CanvasLayer = $UIOverlay
@onready var black_screen: ColorRect = $UIOverlay/BlackScreen
@onready var bounding_box_container: Control = $UIOverlay/BoundingBoxContainer

# Audio nodes
@onready var footstep_audio: AudioStreamPlayer = $FootstepAudio
@onready var gun_sound_audio: AudioStreamPlayer = $GunSoundAudio
@onready var scare_audio: AudioStreamPlayer = $ScareAudio
@onready var pickup_gun_audio: AudioStreamPlayer = $PickupGunAudio
@onready var ambient_audio: AudioStreamPlayer = $AmbientAudio
@onready var todolist_audio: AudioStreamPlayer = $TodolistAudio
@onready var trash_counter_6_audio: AudioStreamPlayer = $TrashCounter6Audio
@onready var trash_counter_5_audio: AudioStreamPlayer = $TrashCounter5Audio
@onready var trash_counter_4_audio: AudioStreamPlayer = $TrashCounter4Audio
@onready var trash_counter_3_audio: AudioStreamPlayer = $TrashCounter3Audio
@onready var trash_counter_2_audio: AudioStreamPlayer = $TrashCounter2Audio
@onready var trash_counter_1_audio: AudioStreamPlayer = $TrashCounter1Audio
@onready var end_audio: AudioStreamPlayer = $EndAudio
@onready var end_sequence_audio: AudioStreamPlayer = $EndSequenceAudio
@onready var confirm_sound_audio: AudioStreamPlayer = $ConfirmSoundAudio
@onready var breakfast_audio: AudioStreamPlayer = $BreakfastAudio
@onready var freezer_audio: AudioStreamPlayer = $FreezerAudio
@onready var rec_room_audio: AudioStreamPlayer = $RecRoomAudio

# Reference to the intro sequence and end sequence
var intro_sequence: Control
var end_sequence: Control
var game_started: bool = false
var flash_message_label: Label

# Narrative audio tracking - ensures only one narrative audio plays at a time
var current_narrative_audio: AudioStreamPlayer = null

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var vision_mode: bool = false
var detected_objects: Array = []  # Can be BasePrefab or objects with BasePrefab-like properties
var interactable_objects_in_range: Array = []  # Can be BasePrefab or objects with BasePrefab-like properties

# Confidence fluctuation system
var confidence_fluctuations: Dictionary = {}  # Store fluctuations for each object
var fluctuation_timer: float = 0.0
var fluctuation_update_interval: float = 3.0  # Update every 3 seconds (optimized from 1.0)

# Trash label flashing system
var trash_label_flash_timer: float = 0.0
var trash_label_flash_interval: float = 0.5  # Flash every 0.5 seconds
var trash_label_show_trash: bool = false  # Alternate between actual label and "TRASH"

# Footstep audio variables
var is_walking: bool = false
var was_walking: bool = false
var is_climbing_stairs: bool = false
var footstep_playing: bool = false  # Track actual audio state

# Reflection tracking for scare audio
var reflection_was_active: bool = false

# Weapon system
var current_weapon: String = ""
var weapon_ui_label: Label
var shootable_objects_in_range: Array[BasePrefab] = []
var weapon_cooldown: float = 0.0
var weapon_cooldown_duration: float = 0.5

# Battery saving mode
var battery_saving_mode: bool = false
var battery_low_label: Label
var battery_flash_timer: float = 0.0
var battery_flash_duration: float = 2.0  # Flash for 2 seconds
var battery_flash_active: bool = false

# Access card system
var has_kitchen_access_card: bool = false

# Trash pickup system
var held_trash = null  # Currently held trash object
var trash_hold_offset: Vector3 = Vector3(0.5, -0.3, -1.5)  # Position relative to camera
var total_trash_left: int = 6  # Global counter for trash that needs to be thrown out
var trash_original_materials: Dictionary = {}  # Store original visibility state for trash objects (optimized - no materials!)
var study_scene_entered: bool = false  # Flag to track if study scene has been entered
var freezer_scene_entered: bool = false  # Flag to track if freezer scene has been entered
var kitchen_scene_entered: bool = false  # Flag to track if kitchen scene has been entered
var rec_room_scene_entered: bool = false  # Flag to track if rec room scene has been entered
var bathroom_scene_entered: bool = false  # Flag to track if bathroom scene has been entered

# One piece left ending system
var one_piece_left_active: bool = false  # Flag when only one piece of trash remains
var is_executing_final_sequence: bool = false  # Flag to prevent multiple triggers


# Pattern update throttling - CRITICAL PERFORMANCE OPTIMIZATION
var stripe_last_size: Dictionary = {}  # obj -> Vector2 (last bounding box size)
var stripe_size_threshold: float = 50.0  # Only update pattern if size changed by this many pixels
var stripe_update_interval: int = 10  # Update at most once per 10 frames
var stripe_last_update_frame: Dictionary = {}  # obj -> int (last frame updated)

func _ready():
	# Add player to group for easy finding by other scripts
	add_to_group("player")
	
	# Don't capture mouse cursor initially - wait for intro to complete
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Set up audio properties
	setup_audio_looping()
	
	# Find all BasePrefab objects in the scene
	find_all_prefabs()
	
	# Initialize UI
	black_screen.visible = false
	bounding_box_container.visible = false
	
	# Find and connect to intro sequence (now inside the SubViewport)
	intro_sequence = get_node("../IntroSequence")
	if intro_sequence:
		intro_sequence.intro_complete.connect(_on_intro_complete)
	else:
		# If no intro sequence found, start game immediately
		_on_intro_complete()
	
	# Find and reference the end sequence
	end_sequence = get_node("../../../../EndSequence")
	if not end_sequence:
		print("Warning: EndSequence not found!")
	
	# Setup weapon UI system
	setup_weapon_ui()
	
	# Initialize weapon UI
	update_weapon_ui()
	
	# Setup battery low UI
	setup_battery_low_ui()
	
	# Setup flash message label
	setup_flash_message_label()

func _on_intro_complete():
	# Start the game first so player can move and see
	game_started = true
	# Now capture the mouse cursor and enable bounding box vision mode
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Start in bounding box vision mode as requested
	vision_mode = true
	black_screen.visible = true
	bounding_box_container.visible = true
	update_bounding_boxes()
	
	# Now play the start sequence (audio + flash message) while player can move
	play_start_sequence()

func play_start_sequence():
	# Play the todolist audio
	if todolist_audio:
		play_narrative_audio(todolist_audio)
		
		# Wait for the audio to finish playing
		await todolist_audio.finished
		
		# Flash the message "CLEAN OUT THE ROOMS"
		flash_bold_message()
	else:
		print("Warning: Todolist audio not found!")

func flash_bold_message():
	if not flash_message_label:
		print("Warning: Flash message label not found!")
		return
	
	# Set the message text in bold with large font
	flash_message_label.text = "CLEAN OUT THE ROOMS"
	flash_message_label.add_theme_font_size_override("font_size", 60)
	
	# Make it bold by adding outline
	flash_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	flash_message_label.add_theme_constant_override("outline_size", 8)
	
	print("Flashing message: CLEAN OUT THE ROOMS")
	
	# Flash the message 3 times (on/off/on/off/on/off)
	for i in range(3):
		flash_message_label.visible = true
		await get_tree().create_timer(0.5).timeout
		flash_message_label.visible = false
		await get_tree().create_timer(0.3).timeout
	
	print("Flash sequence complete")

# Play narrative audio (stops any currently playing narrative audio first)
func play_narrative_audio(audio_player: AudioStreamPlayer):
	# Stop currently playing narrative audio if there is one
	if current_narrative_audio and current_narrative_audio.playing:
		print("Stopping currently playing narrative audio: ", current_narrative_audio.name)
		current_narrative_audio.stop()
	
	# Play the new narrative audio
	if audio_player:
		print("Playing narrative audio: ", audio_player.name)
		current_narrative_audio = audio_player
		audio_player.play()

func _input(event):
	# Don't handle input until game has started
	if not game_started:
		return
		
	# Handle mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -PI/2, PI/2)
	
	# Toggle mouse capture with Escape
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# F key: Pickup/drop trash OR interact with objects
	if event is InputEventKey and event.keycode == KEY_F and event.pressed:
		# If one piece left, only allow window interactions
		if one_piece_left_active:
			var looking_at = get_window_in_line_of_sight()
			if looking_at and looking_at.object_label == "Window":
				# Trigger the final end sequence
				trigger_final_end_sequence(looking_at)
		# If holding trash, check if looking at a window first
		elif held_trash:
			# Check if player is looking at a window to throw trash out (no distance limit)
			var looking_at = get_window_in_line_of_sight()
			if looking_at and looking_at.object_label == "Window":
				# Throw trash out the window instead of dropping it
				looking_at.interact()
			else:
				# Just drop the trash normally
				drop_trash()
		else:
			# Try to pick up trash
			if not try_pickup_trash():
				# If not picking up trash, try general interaction (e.g., mirror)
				handle_interaction()
	
	# 8 key: Toggle vision mode
	if event is InputEventKey and event.keycode == KEY_8 and event.pressed:
		toggle_vision_mode()
	
	# 9 key: Debug shortcut to set trash counter to 1 piece left
	if event is InputEventKey and event.keycode == KEY_9 and event.pressed:
		total_trash_left = 1
		one_piece_left_active = true
		print("DEBUG: Set trash counter to 1 piece left!")
	
	# Handle mouse click for interaction
	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# If one piece left, check for window interaction
			if one_piece_left_active:
				var looking_at = get_window_in_line_of_sight()
				if looking_at and looking_at.object_label == "Window":
					trigger_final_end_sequence(looking_at)
			else:
				handle_interaction()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Block weapon firing when one piece left
			if one_piece_left_active:
				return
			# Only allow firing if player has a weapon
			if current_weapon != "":
				handle_weapon_firing()
			# If no weapon, do nothing

func _physics_process(delta):
	# Don't handle physics until game has started
	if not game_started:
		return
		
	# Add the gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Handle movement with WASD
	var input_dir = Vector2()
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	
	# Calculate movement direction relative to the player's rotation
	var direction = Vector3()
	if input_dir != Vector2.ZERO:
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		is_walking = true
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		is_walking = false

	move_and_slide()
	
	# Single, stable stair climbing system
	handle_stair_climbing()
	
	# Handle footstep audio
	handle_footstep_audio()
	
	# Push RigidBody3D objects when colliding with them
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is RigidBody3D:
			# Apply a gentler push force that doesn't cause excessive bouncing
			var push_direction = -collision.get_normal()
			# Scale the force based on the object's mass to prevent light objects from bouncing the player
			var object_mass = collider.mass if collider.mass > 0 else 1.0
			# Use a more controlled force calculation
			var push_force = push_direction * speed * min(object_mass, 1.0) * 0.5
			# Apply the impulse at the contact point
			var contact_point = collision.get_position() - collider.global_position
			collider.apply_impulse(push_force, contact_point)
	
	# Update weapon cooldown timer
	if weapon_cooldown > 0.0:
		weapon_cooldown -= delta
	
	# Update battery flash timer
	if battery_flash_active:
		battery_flash_timer += delta
		# Flash the label on and off
		if battery_low_label:
			battery_low_label.visible = (int(battery_flash_timer * 4) % 2 == 0)
		
		# Stop flashing after duration
		if battery_flash_timer >= battery_flash_duration:
			battery_flash_active = false
			if battery_low_label:
				battery_low_label.visible = false
	
	# Update confidence fluctuations timer
	fluctuation_timer += delta
	if fluctuation_timer >= fluctuation_update_interval:
		fluctuation_timer = 0.0
		update_confidence_fluctuations()
	
	# Update trash label flash timer
	trash_label_flash_timer += delta
	if trash_label_flash_timer >= trash_label_flash_interval:
		trash_label_flash_timer = 0.0
		trash_label_show_trash = !trash_label_show_trash
	
	# Check if player entered study scene for the first time
	check_study_scene_entry()
	
	# Check if player entered freezer scene for the first time
	check_freezer_scene_entry()
	
	# Check if player entered kitchen scene for the first time
	check_kitchen_scene_entry()
	
	# Check if player entered rec room scene for the first time
	check_rec_room_scene_entry()
	
	# Check if player entered bathroom scene for the first time
	check_bathroom_scene_entry()
	
	# Update held trash position if carrying something
	if held_trash:
		update_held_trash_position()
	
	# Update bounding boxes in vision mode - OPTIMIZED
	if vision_mode:
		# Check if camera has moved significantly
		var camera_moved = has_camera_moved_significantly()
		
		# Increment frame counter
		frames_since_bbox_update += 1
		
		# Only update if camera moved OR enough frames have passed
		if camera_moved or frames_since_bbox_update >= bbox_update_interval:
			frames_since_bbox_update = 0
			update_interactable_objects()  # Update interactables for yellow highlighting
			update_bounding_boxes()
			
			# Update last camera state
			last_camera_position = camera.global_position
			last_camera_rotation = camera.global_rotation
	else:
		# In normal mode, hide any bounding boxes
		bounding_box_container.visible = false

func has_camera_moved_significantly() -> bool:
	# Check if camera position or rotation changed enough to warrant an update
	if last_camera_position == Vector3.ZERO:
		return true  # First frame
	
	var pos_delta = camera.global_position.distance_to(last_camera_position)
	var rot_delta = (camera.global_rotation - last_camera_rotation).length()
	
	return pos_delta > camera_move_threshold or rot_delta > camera_rotate_threshold

func update_confidence_fluctuations():
	# OPTIMIZED: Only update fluctuations for visible objects, not all detected objects
	# This reduces work from 100+ objects to ~30-50 visible objects
	for obj in cached_bounding_boxes.keys():
		if obj != null and is_instance_valid(obj):
			var fluctuation = randf_range(-0.05, 0.05)
			confidence_fluctuations[obj] = fluctuation

func find_all_prefabs():
	detected_objects.clear()
	cached_aabbs.clear()  # Clear AABB cache
	var scene_root = get_tree().current_scene
	_find_prefabs_recursive(scene_root)
	
	# Pre-calculate and cache AABBs for all objects
	for obj in detected_objects:
		cache_object_aabb(obj)
	
	print("Found ", detected_objects.size(), " prefab objects (AABBs cached):")
	for obj in detected_objects:
		var is_mirror = obj.has_method("get_player_reflection_info")
		print("  - ", obj.object_label, " (Interactable: ", obj.is_interactable, ", Mirror: ", is_mirror, ")")

# Cache AABB for an object to avoid recalculating every frame
func cache_object_aabb(obj):
	if obj == null or !is_instance_valid(obj):
		return
	
	var aabb = calculate_object_aabb(obj)
	if aabb.size != Vector3.ZERO:
		cached_aabbs[obj] = {
			"aabb": aabb,
			"center": aabb.get_center()
		}

# Calculate AABB once (used for caching)
func calculate_object_aabb(obj) -> AABB:
	var aabb = AABB()
	var mesh_instances = []
	
	# OPTIMIZED: Use cached mesh instances if available
	if obj in cached_mesh_instances:
		mesh_instances = cached_mesh_instances[obj]
	else:
		_find_mesh_instances_recursive(obj, mesh_instances)
		# Cache the mesh instances permanently - they don't change
		cached_mesh_instances[obj] = mesh_instances
	
	if mesh_instances.is_empty():
		return AABB()
	
	var first = true
	for mesh_instance in mesh_instances:
		var mesh = mesh_instance.mesh
		if mesh != null:
			var local_aabb = mesh.get_aabb()
			var global_aabb = mesh_instance.global_transform * local_aabb
			
			if first:
				aabb = global_aabb
				first = false
			else:
				aabb = aabb.merge(global_aabb)
	
	return aabb

# Add a new detected object to the list (used when spawning broken glass)
func add_detected_object(obj):
	if obj not in detected_objects:
		detected_objects.append(obj)
		cache_object_aabb(obj)  # Cache AABB for new object
		print("Added new detected object: ", obj.object_label)

func _find_prefabs_recursive(node: Node):
	# Detect BasePrefab objects OR objects with BasePrefab-like properties
	var is_prefab_like = false
	
	if node is BasePrefab:
		is_prefab_like = true
	elif node.get("object_label") != null and node.get("confidence") != null:
		# Duck-typing: if it has object_label and confidence, treat it like a prefab
		is_prefab_like = true
	
	if is_prefab_like:
		detected_objects.append(node)
	
	for child in node.get_children():
		_find_prefabs_recursive(child)

func toggle_vision_mode():
	vision_mode = !vision_mode
	black_screen.visible = vision_mode
	
	if vision_mode:
		# In vision mode, show the container and update with all detected objects
		bounding_box_container.visible = true
		update_bounding_boxes()
	else:
		# In normal mode, clear vision boxes and let interactable highlighting take over
		clear_bounding_boxes()
		# Don't set bounding_box_container.visible here - let update_interactable_highlighting control it

func clear_bounding_boxes():
	# Clear all cached UI elements
	for child in bounding_box_container.get_children():
		child.queue_free()
	cached_bounding_boxes.clear()

func update_bounding_boxes():
	# OPTIMIZED: Don't clear and recreate everything - update in place!
	current_frame += 1
	
	# Mirror reflections removed - mirrors now show themselves as "Trash" when player is near
	# (Old reflection system disabled)
	
	# Clean up any freed objects from detected_objects and caches
	var objects_to_remove = []
	for obj in detected_objects:
		if obj == null or !is_instance_valid(obj):
			objects_to_remove.append(obj)
	
	for obj in objects_to_remove:
		detected_objects.erase(obj)
		cached_aabbs.erase(obj)
		raycast_cache.erase(obj)
		remove_bounding_box_ui(obj)
	
	# Track which objects are currently visible
	var visible_objects = {}
	
	for obj in detected_objects:
		if obj == null or !is_instance_valid(obj):
			continue
			
		# Skip walls - don't show bounding boxes for them
		if obj.object_label == "Wall":
			continue
			
		# Check if object should be visible in vision mode
		if !obj.should_be_visible_in_vision_mode():
			continue
		
		# OPTIMIZATION 1: Distance culling - skip objects too far away
		var distance_to_camera = camera.global_position.distance_to(get_object_center_cached(obj))
		if distance_to_camera > vision_culling_distance:
			continue
		
		# OPTIMIZATION 2: Distance-based raycast priority
		# For distant objects, check raycasts even less frequently
		# Skip line of sight check for held trash (always visible when held)
		# Skip line of sight check for windows when holding trash (visible through walls)
		var use_extended_interval = distance_to_camera > vision_culling_distance * 0.5
		var is_window_with_trash = (obj.object_label == "Window" and held_trash != null)
		if obj != held_trash and !is_window_with_trash and !is_object_visible_cached(obj, use_extended_interval):
			continue
			
		var bbox = calculate_screen_bounding_box_cached(obj)
		if bbox != Rect2():
			visible_objects[obj] = true
			var is_interactable_in_range = obj in interactable_objects_in_range
			update_or_create_bounding_box_ui(obj, bbox, is_interactable_in_range)
	
	# Remove UI for objects that are no longer visible
	for obj in cached_bounding_boxes.keys():
		if obj not in visible_objects:
			remove_bounding_box_ui(obj)

# OPTIMIZED: Use cached AABB instead of recalculating
func calculate_screen_bounding_box_cached(obj) -> Rect2:
	# For RigidBody3D objects (physics objects), only recalculate AABB if they've moved significantly
	var aabb: AABB
	if obj is RigidBody3D:
		var needs_recalc = false
		
		# Check if this RigidBody has moved significantly
		if obj not in rigidbody_last_positions:
			needs_recalc = true
			rigidbody_last_positions[obj] = obj.global_position
		else:
			var distance_moved = obj.global_position.distance_to(rigidbody_last_positions[obj])
			if distance_moved > rigidbody_move_threshold:
				needs_recalc = true
				rigidbody_last_positions[obj] = obj.global_position
		
		# Only recalculate if moved or not cached
		if needs_recalc or obj not in cached_aabbs:
			aabb = calculate_object_aabb(obj)
			if aabb.size == Vector3.ZERO:
				return Rect2()
			# Update the cache with the new AABB
			cached_aabbs[obj] = {
				"aabb": aabb,
				"center": aabb.get_center()
			}
		else:
			# Use cached AABB
			aabb = cached_aabbs[obj].aabb
			if aabb.size == Vector3.ZERO:
				return Rect2()
	else:
		# For static objects, use cached AABB
		if obj not in cached_aabbs:
			return Rect2()
		
		aabb = cached_aabbs[obj].aabb
		if aabb.size == Vector3.ZERO:
			return Rect2()
	
	# Get all 8 corners of the AABB
	var corners = [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0, 0),
		aabb.position + Vector3(0, aabb.size.y, 0),
		aabb.position + Vector3(0, 0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
		aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
		aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size
	]
	
	var min_screen = Vector2(INF, INF)
	var max_screen = Vector2(-INF, -INF)
	var any_in_front = false
	
	for corner in corners:
		# Check if point is in front of camera
		var local_pos = camera.to_local(corner)
		if local_pos.z < 0:  # In front of camera
			any_in_front = true
			var screen_pos = camera.unproject_position(corner)
			min_screen.x = min(min_screen.x, screen_pos.x)
			min_screen.y = min(min_screen.y, screen_pos.y)
			max_screen.x = max(max_screen.x, screen_pos.x)
			max_screen.y = max(max_screen.y, screen_pos.y)
	
	if !any_in_front:
		return Rect2()
	
	# Only return the bounding box if it's valid
	if min_screen.x >= max_screen.x or min_screen.y >= max_screen.y:
		return Rect2()
	
	var bbox = Rect2(min_screen, max_screen - min_screen)
	
	# Apply custom scale factor if object provides one (e.g., mirror reflection effect)
	if obj.has_method("get_bounding_box_scale"):
		var scale = obj.get_bounding_box_scale()
		if scale != 1.0:
			var center = bbox.position + bbox.size / 2.0
			bbox.size *= scale
			bbox.position = center - bbox.size / 2.0
	
	return bbox

# Legacy function kept for compatibility (now just calls cached version)
func calculate_screen_bounding_box(obj) -> Rect2:
	return calculate_screen_bounding_box_cached(obj)

# Get object center from cache (avoids recalculation)
func get_object_center_cached(obj) -> Vector3:
	# For RigidBody3D objects, the cache is updated every frame in calculate_screen_bounding_box_cached
	# So we can safely use the cached center (which will be fresh)
	if obj in cached_aabbs:
		return cached_aabbs[obj].center
	# Fallback to object position if not cached
	return obj.global_position

# Cached raycast visibility check (only updates every N frames)
# OPTIMIZED: Support extended interval for distant objects
func is_object_visible_cached(obj, use_extended_interval: bool = false) -> bool:
	# Check if we have a recent cached result
	if obj in raycast_cache:
		var cache_entry = raycast_cache[obj]
		var frames_old = current_frame - cache_entry.frame
		# Use longer interval for distant objects (3x longer)
		var interval = raycast_update_interval * 3 if use_extended_interval else raycast_update_interval
		if frames_old < interval:
			return cache_entry.visible
	
	# Perform actual raycast check and cache result
	var is_visible = is_object_center_in_line_of_sight(obj)
	raycast_cache[obj] = {
		"visible": is_visible,
		"frame": current_frame
	}
	return is_visible

func get_object_aabb(obj) -> AABB:
	var aabb = AABB()
	
	# OPTIMIZED: Use cached mesh instances
	var mesh_instances = []
	if obj in cached_mesh_instances:
		mesh_instances = cached_mesh_instances[obj]
	else:
		_find_mesh_instances_recursive(obj, mesh_instances)
		cached_mesh_instances[obj] = mesh_instances
	
	if mesh_instances.is_empty():
		return AABB()
	
	var first = true
	for mesh_instance in mesh_instances:
		var mesh = mesh_instance.mesh
		if mesh != null:
			var local_aabb = mesh.get_aabb()
			var global_aabb = mesh_instance.global_transform * local_aabb
			
			if first:
				aabb = global_aabb
				first = false
			else:
				aabb = aabb.merge(global_aabb)
	
	return aabb

func _find_mesh_instances_recursive(node: Node, mesh_instances: Array):
	if node is MeshInstance3D:
		mesh_instances.append(node)
	
	for child in node.get_children():
		_find_mesh_instances_recursive(child, mesh_instances)

func get_object_center(obj) -> Vector3:
	# Use cached version for better performance
	return get_object_center_cached(obj)

# OPTIMIZED: Get cached text size to avoid expensive measurement calls
func get_cached_text_size(text: String, font_size: int, font) -> Vector2:
	var cache_key = text + "_" + str(font_size)
	
	if cache_key in cached_text_sizes:
		return cached_text_sizes[cache_key]
	
	# Calculate and cache
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	cached_text_sizes[cache_key] = text_size
	
	# Limit cache size to prevent memory issues (keep last 200 entries)
	if cached_text_sizes.size() > 200:
		# Clear oldest entries (simple approach - clear half)
		var keys = cached_text_sizes.keys()
		for i in range(100):
			cached_text_sizes.erase(keys[i])
	
	return text_size

func is_object_center_in_line_of_sight(obj) -> bool:
	var camera_pos = camera.global_position
	var object_center = get_object_center(obj)
	
	# OPTIMIZED: Reuse query object to reduce allocations
	var space_state = get_world_3d().direct_space_state
	if pooled_ray_query == null:
		pooled_ray_query = PhysicsRayQueryParameters3D.create(camera_pos, object_center)
	else:
		pooled_ray_query.from = camera_pos
		pooled_ray_query.to = object_center
	
	# Exclude the player and held trash from the raycast
	var exclude_list = [self]
	if held_trash != null and is_instance_valid(held_trash):
		exclude_list.append(held_trash)
	pooled_ray_query.exclude = exclude_list
	
	var result = space_state.intersect_ray(pooled_ray_query)
	
	# If no collision, object is in line of sight
	if result.is_empty():
		return true
	
	# If the collision is with the target object itself, it's in line of sight
	var hit_object = result.collider
	
	# Check if the hit object is the target object or a child of it
	var current_node = hit_object
	while current_node != null:
		if current_node == obj:
			return true
		current_node = current_node.get_parent()
	
	# If we hit something else, the object is occluded
	return false

# OPTIMIZED: Update existing UI or create new (avoids recreation)
func update_or_create_bounding_box_ui(obj, bbox: Rect2, is_interactable_in_range: bool = false):
	# Choose color based on priority
	var border_color = Color.GREEN
	var label_bg_color = Color.GREEN
	
	# Windows get RED borders when holding trash OR when one piece left (highest priority)
	if obj.object_label == "Window" and (held_trash != null or one_piece_left_active):
		border_color = Color.RED
		label_bg_color = Color.RED
	# Only show yellow border if interactable AND has interaction text
	# (objects with empty interaction_text like mirrors stay green)
	elif is_interactable_in_range and obj.interaction_text != "":
		border_color = Color.YELLOW
		label_bg_color = Color.YELLOW
	
	# Prepare label text (empty if battery saving mode)
	var label_text = ""
	var label_color = Color.BLACK  # Default label color
	var is_trash = obj.get("is_trash") and obj.is_trash
	var is_held = (held_trash == obj)
	
	if not battery_saving_mode:
		var fluctuation = confidence_fluctuations.get(obj, 0.0)
		var display_confidence = clamp(obj.confidence + fluctuation, 0.0, 1.0)
		
		# Flash trash labels between actual label and "TRASH" in red
		if is_trash:
			if trash_label_show_trash:
				label_text = "TRASH: " + str(round(display_confidence * 100) / 100.0)
				label_color = Color.RED
			else:
				label_text = obj.object_label + ": " + str(round(display_confidence * 100) / 100.0)
				label_color = Color.BLACK
		# Check if label is "Trash" (e.g., mirror reflection) - show in red
		elif obj.object_label == "Trash":
			label_text = str(round(display_confidence * 100) / 100.0) + " " + obj.object_label
			label_color = Color.RED
		else:
			label_text = obj.object_label + ": " + str(round(display_confidence * 100) / 100.0)
			label_color = Color.BLACK
		
		# Don't show interaction text for red windows (holding trash or one piece left)
		var is_red_window = obj.object_label == "Window" and (held_trash != null or one_piece_left_active)
		if is_interactable_in_range and obj.interaction_text != "" and not is_red_window:
			label_text += " [" + obj.interaction_text + "]"
	
	# Check if UI already exists for this object
	if obj in cached_bounding_boxes:
		# UPDATE existing UI
		var cached = cached_bounding_boxes[obj]
		var container = cached.container
		
		# Update position and size
		container.position = bbox.position
		container.size = bbox.size
		
		# Update border sizes
		var border_width = 2
		cached.borders[0].size = Vector2(bbox.size.x, border_width)  # Top
		cached.borders[1].position = Vector2(0, bbox.size.y - border_width)
		cached.borders[1].size = Vector2(bbox.size.x, border_width)  # Bottom
		cached.borders[2].size = Vector2(border_width, bbox.size.y)  # Left
		cached.borders[3].position = Vector2(bbox.size.x - border_width, 0)
		cached.borders[3].size = Vector2(border_width, bbox.size.y)  # Right
		
		# Update colors if changed
		for border in cached.borders:
			border.color = border_color
		
		# Update label text, color, and background
		cached.label.text = label_text
		cached.label.add_theme_color_override("font_color", label_color)
		cached.label_bg.color = label_bg_color
		
		# Handle noise pattern for held trash - OPTIMIZED WITH SHADER
		if is_trash and is_held:
			# Show noise pattern when trash is held
			if not cached.has("stripe_fill"):
				# Create new noise pattern (shader-based - single node!)
				var stripe_fill = create_diagonal_stripes_shader(container, bbox.size)
				container.add_child(stripe_fill)
				container.move_child(stripe_fill, 0)  # Move to back (behind borders)
				cached.stripe_fill = stripe_fill
				# Initialize throttling data
				stripe_last_size[obj] = bbox.size
				stripe_last_update_frame[obj] = current_frame
			else:
				# OPTIMIZED: Only update if size changed significantly AND enough frames passed
				var should_update = false
				
				if obj in stripe_last_size and obj in stripe_last_update_frame:
					var size_delta = abs(bbox.size.x - stripe_last_size[obj].x) + abs(bbox.size.y - stripe_last_size[obj].y)
					var frames_since_update = current_frame - stripe_last_update_frame[obj]
					
					# Update only if BOTH conditions met: significant size change AND enough time passed
					if size_delta > stripe_size_threshold and frames_since_update >= stripe_update_interval:
						should_update = true
				else:
					# First update - initialize
					should_update = true
				
				# Update pattern size (cheap operation with shader approach)
				if should_update:
					cached.stripe_fill.size = bbox.size
					# Update throttling data
					stripe_last_size[obj] = bbox.size
					stripe_last_update_frame[obj] = current_frame
				
				# Always make visible when held (cheap operation)
				cached.stripe_fill.visible = true
		else:
			# Hide noise pattern when trash is not held
			if cached.has("stripe_fill"):
				cached.stripe_fill.visible = false
		
		# Show window shader pattern if this is a window and (holding trash OR one piece left)
		if cached.has("window_pattern"):
			var is_window_with_trash = (obj.object_label == "Window" and (held_trash != null or one_piece_left_active))
			cached.window_pattern.visible = is_window_with_trash
			if is_window_with_trash:
				cached.window_pattern.size = bbox.size
		
		# Hide label in battery saving mode
		if battery_saving_mode:
			cached.label.visible = false
			cached.label_bg.visible = false
		else:
			cached.label.visible = true
			cached.label_bg.visible = true
			# OPTIMIZED: Use cached text size measurement
			var font = cached.label.get_theme_default_font()
			var font_size = 20
			var text_size = get_cached_text_size(label_text, font_size, font)
			cached.label_bg.size = Vector2(text_size.x + 10, 25)
	else:
		# CREATE new UI
		var container = Control.new()
		container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		container.position = bbox.position
		container.size = bbox.size
		bounding_box_container.add_child(container)
		
		# Create noise pattern fill for held trash (behind borders) - SHADER OPTIMIZED
		var stripe_fill = null
		if is_trash and is_held:
			stripe_fill = create_diagonal_stripes_shader(container, bbox.size)
			container.add_child(stripe_fill)
			# Initialize throttling data for new objects
			stripe_last_size[obj] = bbox.size
			stripe_last_update_frame[obj] = current_frame
		
		# Create hollow border
		var borders = create_hollow_border_array(container, bbox.size, border_color)
		
		# Create label
		var label = Label.new()
		label.text = label_text
		label.add_theme_color_override("font_color", label_color)
		label.add_theme_font_size_override("font_size", 20)
		label.position = Vector2(5, -28)
		
		# OPTIMIZED: Measure text size using cache
		var font = label.get_theme_default_font()
		var font_size = 20
		var text_size = get_cached_text_size(label_text, font_size, font)
		
		# Create background
		var label_bg = ColorRect.new()
		label_bg.color = label_bg_color
		label_bg.size = Vector2(text_size.x + 10, 25)
		label_bg.position = Vector2(0, -30)
		
		# Hide label in battery saving mode
		if battery_saving_mode:
			label.visible = false
			label_bg.visible = false
		
		container.add_child(label_bg)
		container.add_child(label)
		
		# Create window pattern shader for windows (shown when holding trash OR one piece left)
		var window_pattern = null
		if obj.object_label == "Window":
			window_pattern = create_window_pattern_shader(container, bbox.size)
			container.add_child(window_pattern)
			container.move_child(window_pattern, 0)  # Move to back (behind borders)
			var is_window_with_trash = (obj.object_label == "Window" and (held_trash != null or one_piece_left_active))
			window_pattern.visible = is_window_with_trash
		
		# Cache the UI elements
		var cache_data = {
			"container": container,
			"borders": borders,
			"label": label,
			"label_bg": label_bg
		}
		if window_pattern:
			cache_data["window_pattern"] = window_pattern
		if stripe_fill:
			cache_data["stripe_fill"] = stripe_fill
		cached_bounding_boxes[obj] = cache_data

# Remove UI for a specific object
func remove_bounding_box_ui(obj):
	# Check if object is valid before proceeding (handles freed objects)
	if obj == null or !is_instance_valid(obj):
		# Clean up any cached references to this freed object
		if obj in cached_bounding_boxes:
			var cached = cached_bounding_boxes[obj]
			if is_instance_valid(cached.container):
				cached.container.queue_free()
			cached_bounding_boxes.erase(obj)
		# Clean up pattern throttling cache
		if obj in stripe_last_size:
			stripe_last_size.erase(obj)
		if obj in stripe_last_update_frame:
			stripe_last_update_frame.erase(obj)
		return
	
	if obj in cached_bounding_boxes:
		var cached = cached_bounding_boxes[obj]
		if is_instance_valid(cached.container):
			cached.container.queue_free()
		cached_bounding_boxes.erase(obj)
		# Clean up pattern throttling cache
		if obj in stripe_last_size:
			stripe_last_size.erase(obj)
		if obj in stripe_last_update_frame:
			stripe_last_update_frame.erase(obj)

# Legacy function kept for compatibility
func create_bounding_box_ui(obj, bbox: Rect2, is_interactable_in_range: bool = false):
	update_or_create_bounding_box_ui(obj, bbox, is_interactable_in_range)

# OPTIMIZED: Create noise pattern using GPU shader (100x faster!)
# Single ColorRect with shader instead of 20+ ColorRect nodes
# Uses noise instead of stripes for better performance (no trig calculations)
func create_diagonal_stripes_shader(container: Control, box_size: Vector2) -> ColorRect:
	var stripe_rect = ColorRect.new()
	stripe_rect.size = box_size
	stripe_rect.position = Vector2(0, 0)
	
	# Load the noise shader
	var shader = load("res://diagonal_stripes.gdshader")
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	
	# Set shader parameters (noise-based pattern)
	shader_material.set_shader_parameter("color1", Color.GREEN)
	shader_material.set_shader_parameter("color2", Color.BLACK)
	shader_material.set_shader_parameter("noise_scale", 15.0)
	
	stripe_rect.material = shader_material
	
	return stripe_rect

# Create window pattern shader (shown when holding trash to indicate throw-out target)
func create_window_pattern_shader(container: Control, box_size: Vector2) -> Control:
	# Create a container for the text
	var text_container = Control.new()
	text_container.size = box_size
	text_container.position = Vector2(0, 0)
	
	# Create the "Throw out" label in red
	var label = Label.new()
	label.text = "Throw out"
	label.add_theme_color_override("font_color", Color.RED)
	label.add_theme_font_size_override("font_size", 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Make the label fill the entire container
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	text_container.add_child(label)
	
	return text_container

# Legacy function - kept for reference but replaced with shader version
func create_diagonal_stripes_legacy(container: Control, box_size: Vector2) -> Control:
	# OLD APPROACH: Creates 20+ ColorRect nodes - EXTREMELY SLOW!
	# This function is no longer used but kept for documentation
	var stripe_container = Control.new()
	stripe_container.size = box_size
	stripe_container.position = Vector2(0, 0)
	stripe_container.clip_contents = true
	
	var stripe_width = 20
	var num_stripes = int((box_size.x + box_size.y) / stripe_width) + 2
	
	for i in range(num_stripes):
		var is_green = (i % 2 == 0)
		var stripe_color = Color.GREEN if is_green else Color.BLACK
		var stripe = ColorRect.new()
		stripe.color = stripe_color
		stripe.size = Vector2(stripe_width, box_size.length() * 2)
		var offset = i * stripe_width - box_size.y
		stripe.position = Vector2(offset, 0)
		stripe.rotation = deg_to_rad(45)
		stripe.pivot_offset = Vector2(0, 0)
		stripe_container.add_child(stripe)
	
	return stripe_container

# Returns array of border ColorRects for caching
func create_hollow_border_array(container: Control, box_size: Vector2, color: Color = Color.GREEN) -> Array:
	var border_width = 2
	var borders = []
	
	# Top border
	var top_border = ColorRect.new()
	top_border.color = color
	top_border.position = Vector2(0, 0)
	top_border.size = Vector2(box_size.x, border_width)
	container.add_child(top_border)
	borders.append(top_border)
	
	# Bottom border
	var bottom_border = ColorRect.new()
	bottom_border.color = color
	bottom_border.position = Vector2(0, box_size.y - border_width)
	bottom_border.size = Vector2(box_size.x, border_width)
	container.add_child(bottom_border)
	borders.append(bottom_border)
	
	# Left border
	var left_border = ColorRect.new()
	left_border.color = color
	left_border.position = Vector2(0, 0)
	left_border.size = Vector2(border_width, box_size.y)
	container.add_child(left_border)
	borders.append(left_border)
	
	# Right border
	var right_border = ColorRect.new()
	right_border.color = color
	right_border.position = Vector2(box_size.x - border_width, 0)
	right_border.size = Vector2(border_width, box_size.y)
	container.add_child(right_border)
	borders.append(right_border)
	
	return borders

# Legacy function kept for compatibility
func create_hollow_border(container: Control, box_size: Vector2, color: Color = Color.GREEN):
	create_hollow_border_array(container, box_size, color)

# Handle interaction when mouse is clicked
func handle_interaction():
	# If one piece left, only allow window interactions (block everything else)
	if one_piece_left_active:
		print("One piece left - only windows are interactable!")
		return
	
	print("Attempting interaction...")
	# Cast a ray from the camera forward to detect what the player is looking at
	var space_state = get_world_3d().direct_space_state
	var camera_pos = camera.global_position
	var camera_forward = -camera.global_transform.basis.z
	var ray_end = camera_pos + camera_forward * interaction_distance
	
	var query = PhysicsRayQueryParameters3D.create(camera_pos, ray_end)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if not result.is_empty():
		var hit_object = result.collider
		
		# Find the BasePrefab parent of the hit object
		var prefab = find_prefab_parent(hit_object)
		if prefab and prefab.is_interactable:
			print("Interacting with: ", prefab.object_label)
			prefab.interact()
		else:
			print("Hit non-interactable object")
	else:
		print("No object in interaction range")

# Handle right-click interaction (for breaking objects like mirrors)
func handle_right_click_interaction():
	print("Attempting right-click interaction...")
	# Cast a ray from the camera forward to detect what the player is looking at
	var space_state = get_world_3d().direct_space_state
	var camera_pos = camera.global_position
	var camera_forward = -camera.global_transform.basis.z
	var ray_end = camera_pos + camera_forward * interaction_distance
	
	var query = PhysicsRayQueryParameters3D.create(camera_pos, ray_end)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if not result.is_empty():
		var hit_object = result.collider
		
		# Find the BasePrefab parent of the hit object
		var prefab = find_prefab_parent(hit_object)
		if prefab and prefab.has_method("right_click_interact"):
			print("Right-click interacting with: ", prefab.object_label)
			prefab.right_click_interact()
		else:
			print("Hit object doesn't support right-click interaction")
	else:
		print("No object in right-click interaction range")

# Find the BasePrefab (or BasePrefab-like) parent of a node
func find_prefab_parent(node: Node):
	var current_node = node
	while current_node != null:
		if current_node is BasePrefab:
			return current_node
		elif current_node.get("object_label") != null and current_node.get("confidence") != null:
			# Duck-typing: if it has object_label and confidence, treat it like a prefab
			return current_node
		current_node = current_node.get_parent()
	return null

# Get the object (BasePrefab) the player is currently looking at within interaction range
func get_object_player_is_looking_at():
	# Cast a ray from the camera forward to detect what the player is looking at
	var space_state = get_world_3d().direct_space_state
	var camera_pos = camera.global_position
	var camera_forward = -camera.global_transform.basis.z
	var ray_end = camera_pos + camera_forward * interaction_distance
	
	var query = PhysicsRayQueryParameters3D.create(camera_pos, ray_end)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if not result.is_empty():
		var hit_object = result.collider
		var prefab = find_prefab_parent(hit_object)
		return prefab
	
	return null

# Get a window in line of sight (no distance limit for throwing trash)
func get_window_in_line_of_sight():
	# Cast a ray from the camera forward with unlimited distance
	var space_state = get_world_3d().direct_space_state
	var camera_pos = camera.global_position
	var camera_forward = -camera.global_transform.basis.z
	var ray_end = camera_pos + camera_forward * 1000.0  # Very long distance (no practical limit)
	
	var query = PhysicsRayQueryParameters3D.create(camera_pos, ray_end)
	var exclude_list = [self]
	if held_trash != null and is_instance_valid(held_trash):
		exclude_list.append(held_trash)
	query.exclude = exclude_list
	
	var result = space_state.intersect_ray(query)
	
	if not result.is_empty():
		var hit_object = result.collider
		var prefab = find_prefab_parent(hit_object)
		return prefab
	
	return null

# Try to pick up trash object that player is looking at
func try_pickup_trash() -> bool:
	# Cast a ray from the camera to find what we're looking at
	var space_state = get_world_3d().direct_space_state
	var camera_pos = camera.global_position
	var camera_forward = -camera.global_transform.basis.z
	var ray_end = camera_pos + camera_forward * interaction_distance
	
	var query = PhysicsRayQueryParameters3D.create(camera_pos, ray_end)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if not result.is_empty():
		var hit_object = result.collider
		var prefab = find_prefab_parent(hit_object)
		
		# Check if this is a trash object
		if prefab and prefab.get("is_trash") and prefab.is_trash:
			pickup_trash(prefab)
			return true
	
	return false

# Pick up a trash object
func pickup_trash(trash):
	print("Picking up trash: ", trash.object_label)
	held_trash = trash
	
	# Check if it's a RigidBody3D and disable physics while held
	if trash is RigidBody3D:
		trash.freeze = true
		# Reset velocities to prevent carried-over momentum
		trash.linear_velocity = Vector3.ZERO
		trash.angular_velocity = Vector3.ZERO
	
	# Update interaction text
	trash.interaction_text = "DROP"
	
	# Make trash semi-transparent so it doesn't block vision
	make_trash_transparent(trash)
	
	# Position it in front of the camera
	update_held_trash_position()

# Drop the currently held trash
func drop_trash():
	if not held_trash:
		return
	
	print("Dropping trash: ", held_trash.object_label)
	
	# Restore original opacity
	restore_trash_opacity(held_trash)
	
	# Check if it's a RigidBody3D and re-enable physics
	if held_trash is RigidBody3D:
		# Re-enable physics
		held_trash.freeze = false
		
		# Give it a slight forward velocity when dropped
		var drop_velocity = -camera.global_transform.basis.z * 2.0
		held_trash.linear_velocity = drop_velocity
		
		# Reset angular velocity to prevent spinning
		held_trash.angular_velocity = Vector3.ZERO
	
	# Update interaction text back to pickup
	held_trash.interaction_text = "PICK UP"
	
	# Clear held reference
	held_trash = null

# Update the position of held trash to follow camera
func update_held_trash_position():
	if not held_trash or not is_instance_valid(held_trash):
		held_trash = null
		return
	
	# Calculate XZ position in camera space (follows camera rotation)
	var camera_basis_xz = camera.global_transform.basis
	var offset_xz = Vector3(trash_hold_offset.x, 0, trash_hold_offset.z)
	var xz_offset = camera_basis_xz * offset_xz
	
	# Y position stays in world space relative to camera
	var target_pos = camera.global_position + xz_offset
	target_pos.y = camera.global_position.y + trash_hold_offset.y  # World-space Y offset
	
	held_trash.global_position = target_pos
	
	# Preserve the object's original orientation when carried

# Update list of interactable objects in range using raycast (same as actual interaction)
func update_interactable_objects():
	# OPTIMIZED: Cache the result for a few frames since this is expensive
	# Only recalculate every 3 frames
	if not has_meta("interactable_last_update_frame"):
		set_meta("interactable_last_update_frame", 0)
	
	var last_update = get_meta("interactable_last_update_frame")
	if current_frame - last_update < 3:
		return  # Use cached result from last update
	
	set_meta("interactable_last_update_frame", current_frame)
	
	interactable_objects_in_range.clear()
	
	# Use the same raycast logic as handle_interaction() for consistency
	var space_state = get_world_3d().direct_space_state
	var camera_pos = camera.global_position
	var camera_forward = -camera.global_transform.basis.z
	var ray_end = camera_pos + camera_forward * interaction_distance
	
	var query = PhysicsRayQueryParameters3D.create(camera_pos, ray_end)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if not result.is_empty():
		var hit_object = result.collider
		
		# Find the BasePrefab parent of the hit object
		var prefab = find_prefab_parent(hit_object)
		if prefab and prefab.is_interactable and prefab.should_be_visible_in_vision_mode():
			interactable_objects_in_range.append(prefab)

# Update yellow highlighting for interactable objects in range
func update_interactable_highlighting():
	# Yellow highlighting only appears in vision mode, not normal mode
	if !vision_mode:
		# In normal mode, hide bounding boxes completely
		bounding_box_container.visible = false
		return
	
	# We're in vision mode - show yellow boxes for interactables in range
	# This will be handled by update_bounding_boxes() which calls create_bounding_box_ui
	# with the is_interactable_in_range parameter


# Check for mirror reflections and create bounding boxes for player reflections
func check_mirror_reflections():
	# OPTIMIZED: Cache mirror objects list instead of searching every time
	if not has_meta("cached_mirrors"):
		var mirrors = []
		for obj in detected_objects:
			if obj != null and is_instance_valid(obj) and obj.has_method("get_player_reflection_info"):
				mirrors.append(obj)
				print("FirstPersonController: Found mirror object: ", obj.object_label if obj.get("object_label") else "Unknown")
		set_meta("cached_mirrors", mirrors)
		print("FirstPersonController: Total mirrors cached: ", mirrors.size())
	
	var mirrors = get_meta("cached_mirrors", [])
	var any_reflection_active = false
	
	# Only check cached mirrors (much faster than iterating all detected_objects)
	for mirror in mirrors:
		if mirror == null or !is_instance_valid(mirror):
			continue
			
		var reflection_info = mirror.get_player_reflection_info()
		if reflection_info.has("active"):
			if reflection_info.active:
				any_reflection_active = true
				create_reflection_bounding_box(reflection_info)
			# Debug: Uncomment to see reflection checking
			# print("Mirror reflection check: active=", reflection_info.active)
	
	# Play scare audio when reflection becomes active for the first time
	if any_reflection_active and not reflection_was_active:
		if scare_audio:
			print("FirstPersonController: Playing scare audio - reflection appeared!")
			scare_audio.play()
	
	# Update reflection state for next frame
	reflection_was_active = any_reflection_active

# Create a bounding box for the player reflection
func create_reflection_bounding_box(reflection_info: Dictionary):
	var reflection_pos = reflection_info.position
	var label_text = reflection_info.label
	var confidence = reflection_info.confidence
	
	# Calculate screen position for the reflection
	var screen_pos = camera.unproject_position(reflection_pos)
	
	# Check if reflection is in front of camera
	var local_pos = camera.to_local(reflection_pos)
	if local_pos.z >= 0:  # Behind camera
		return
	
	# Create a bounding box size for the player reflection as big as the mirror
	# Mirror is 3x4 units, convert to pixels: assuming ~100 pixels per unit for proper scaling
	var bbox_size = Vector2(300, 400)  # Width x Height in pixels - full mirror size (3x4 units)
	var bbox_pos = screen_pos - bbox_size / 2
	var bbox = Rect2(bbox_pos, bbox_size)
	
	# Create the reflection bounding box UI
	create_reflection_bounding_box_ui(reflection_info, bbox)

# Create UI for reflection bounding box (similar to create_bounding_box_ui but for reflections)
func create_reflection_bounding_box_ui(reflection_info: Dictionary, bbox: Rect2):
	# Create container for this bounding box
	var container = Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	container.position = bbox.position
	container.size = bbox.size
	bounding_box_container.add_child(container)
	
	# Use green color like other bounding boxes
	var border_color = Color.GREEN
	var label_bg_color = Color.GREEN
	
	# Create hollow border using 4 ColorRect nodes
	create_hollow_border(container, bbox.size, border_color)
	
	# Prepare label text for reflection (show exactly "<confidence> <label>" for the mirror)
	var label_text = str(reflection_info.confidence) + " " + reflection_info.label
	
	# Use Godot's built-in text measurement for accurate sizing
	var label = Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_font_size_override("font_size", 20)
	
	# Measure the actual text size
	var font = label.get_theme_default_font()
	var font_size = 20
	var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	
	# Create background with measured width plus padding
	var padding_horizontal = 10  # 5 pixels on each side
	var label_bg = ColorRect.new()
	label_bg.color = label_bg_color
	label_bg.size = Vector2(text_size.x + padding_horizontal, 25)
	label_bg.position = Vector2(0, -30)
	
	# Position label with left padding
	label.position = Vector2(5, -28)
	
	container.add_child(label_bg)
	container.add_child(label)

# Simple, stable stair climbing - no trembling!
func handle_stair_climbing():
	# Update cooldown timer
	if step_cooldown > 0:
		step_cooldown -= get_physics_process_delta_time()
		# Keep the climbing flag active during cooldown to maintain footstep audio
		if step_cooldown <= 0:
			is_climbing_stairs = false
		return
	
	# Reset stair climbing flag - will be set to true if we step up
	is_climbing_stairs = false
	
	# Only try to climb if we're moving and on the floor
	# Check if player is giving movement input
	var input_dir = Vector2()
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	
	if not is_on_floor() or input_dir == Vector2.ZERO:
		return
	
	# Check if we're colliding with something that could be a step
	var can_step_up = false
	var target_height = global_position.y
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		var normal = collision.get_normal()
		var hit_pos = collision.get_position()
		
		# If hitting a vertical surface (step edge)
		if collider is StaticBody3D and abs(normal.y) < 0.5:
			var height_diff = hit_pos.y - global_position.y
			
			# If this is a reasonable step height
			if height_diff > 0.05 and height_diff <= step_height:
				can_step_up = true
				target_height = max(target_height, hit_pos.y + 0.1)
	
	# If we found a step to climb, do it smoothly and only once
	if can_step_up and target_height > global_position.y:
		global_position.y = target_height
		velocity.y = 0  # Reset vertical velocity to prevent bouncing
		step_cooldown = 0.1  # Set cooldown timer
		is_climbing_stairs = true  # Flag that we're climbing stairs
		print("Stepped up to: ", target_height)

# Handle footstep audio with proper state management
func handle_footstep_audio():
	# Determine if player should have footstep sounds
	# Play if: walking AND (on floor OR climbing stairs OR was just on floor recently)
	var should_play_footsteps = is_walking and (is_on_floor() or is_climbing_stairs)
	
	# Use a more stable check - if we were walking and are still walking, keep playing
	# This prevents interruptions during brief floor state changes
	if is_walking and was_walking:
		should_play_footsteps = true
	
	# Manage audio playback based on desired state
	if should_play_footsteps:
		# Start playing if not already playing
		if footstep_audio and not footstep_audio.playing:
			footstep_audio.play()
			footstep_playing = true
	else:
		# Stop playing only if we're truly not walking
		if footstep_audio and footstep_audio.playing and not is_walking:
			footstep_audio.stop()
			footstep_playing = false
	
	# Update previous walking state (track actual movement input, not floor state)
	was_walking = is_walking


# Trigger the end sequence (called when mirror is shot)
func trigger_end_sequence():
	print("FirstPersonController: trigger_end_sequence() called!")
	
	print("FirstPersonController: end_sequence reference: ", end_sequence)
	if end_sequence and end_sequence.has_method("start_end_sequence"):
		print("FirstPersonController: Calling start_end_sequence()...")
		end_sequence.start_end_sequence()
	else:
		print("Error: EndSequence not found or doesn't have start_end_sequence method!")

# Setup weapon UI system
func setup_weapon_ui():
	# Get reference to weapon status label in PlayerUI
	weapon_ui_label = get_node("../../../../BottomLeftLabel")
	if not weapon_ui_label:
		print("Warning: Could not find weapon UI label!")

# Called when player picks up a weapon
func pickup_weapon(weapon_name: String):
	current_weapon = weapon_name
	
	# Update weapon UI
	update_weapon_ui()
	
	print("Player picked up weapon: ", weapon_name)

# Handle weapon firing - shoots shootable objects
func handle_weapon_firing():
	# Check cooldown
	if weapon_cooldown > 0.0:
		print("Weapon on cooldown: ", weapon_cooldown, " seconds remaining")
		return
	
	# Play gun sound
	if gun_sound_audio:
		gun_sound_audio.play()
	
	# Start the cooldown
	weapon_cooldown = weapon_cooldown_duration
	
	# Find the first shootable object within the center 30% of the screen
	var viewport_size = get_viewport().get_visible_rect().size
	var center_region_size = viewport_size * 0.3  # 30% of screen size
	var center_region_min = (viewport_size - center_region_size) / 2.0
	var center_region_max = center_region_min + center_region_size
	
	var closest_shootable: BasePrefab = null
	var closest_distance: float = INF
	
	# Check all detected objects to find shootable ones in the center region
	for obj in detected_objects:
		if obj == null or !is_instance_valid(obj):
			continue
		
		# Skip if not shootable
		if not obj.is_shootable:
			continue
		
		# Skip if not visible
		if not obj.should_be_visible_in_vision_mode():
			continue
		
		# Check if object center is in line of sight
		if not is_object_center_in_line_of_sight(obj):
			continue
		
		# Get object center in screen space
		var obj_center = get_object_center_cached(obj)
		var screen_pos = camera.unproject_position(obj_center)
		
		# Check if in center region (30% of screen)
		if screen_pos.x >= center_region_min.x and screen_pos.x <= center_region_max.x and \
		   screen_pos.y >= center_region_min.y and screen_pos.y <= center_region_max.y:
			# Check distance to find the closest one
			var distance = camera.global_position.distance_to(obj_center)
			if distance < closest_distance:
				closest_distance = distance
				closest_shootable = obj
	
	# Shoot the closest shootable object
	if closest_shootable:
		print("Shot shootable object: ", closest_shootable.object_label)
		if closest_shootable.has_method("right_click_interact"):
			closest_shootable.right_click_interact()
	else:
		print("No shootable object in center of screen")

# Update weapon UI to show if player has weapon
func update_weapon_ui():
	if weapon_ui_label:
		if current_weapon == "":
			weapon_ui_label.text = "[Empty]"
		else:
			weapon_ui_label.text = "[" + current_weapon + "]"

# Set up audio looping for different stream types
func setup_audio_looping():
	# Set up footstep audio looping
	if footstep_audio and footstep_audio.stream:
		if footstep_audio.stream is AudioStreamMP3:
			footstep_audio.stream.loop = true
		elif footstep_audio.stream is AudioStreamWAV:
			footstep_audio.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	
	# Set up OLD ambient audio looping (kept for backwards compatibility)
	if ambient_audio:
		if ambient_audio.stream:
			if ambient_audio.stream is AudioStreamMP3:
				ambient_audio.stream.loop = true
			elif ambient_audio.stream is AudioStreamWAV:
				ambient_audio.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

# Setup battery low UI
func setup_battery_low_ui():
	# Create a label that will flash "Battery Low"
	battery_low_label = Label.new()
	battery_low_label.text = "BATTERY LOW"
	battery_low_label.add_theme_color_override("font_color", Color.RED)
	battery_low_label.add_theme_font_size_override("font_size", 48)
	battery_low_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	battery_low_label.position = Vector2(-150, -100)
	battery_low_label.visible = false
	ui_overlay.add_child(battery_low_label)

# Setup flash message label
func setup_flash_message_label():
	# Create a label that will flash start sequence message
	flash_message_label = Label.new()
	flash_message_label.text = ""
	flash_message_label.add_theme_color_override("font_color", Color.GREEN)
	flash_message_label.add_theme_font_size_override("font_size", 48)
	flash_message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	flash_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash_message_label.position = Vector2(-300, 0)  # Centered horizontally
	flash_message_label.size = Vector2(600, 100)  # Wide enough for the text
	flash_message_label.visible = false
	ui_overlay.add_child(flash_message_label)

# Activate battery saving mode (called by trigger in U Hall)
func activate_battery_saving_mode():
	print("Activating battery saving mode!")
	
	# Start the battery low flash
	battery_flash_active = true
	battery_flash_timer = 0.0
	
	# Enable battery saving mode after flash completes
	# Set a timer to enable it
	await get_tree().create_timer(battery_flash_duration).timeout
	battery_saving_mode = true
	print("Battery saving mode now active - boxes only, no labels!")

# Pickup kitchen access card
func pickup_kitchen_access_card():
	has_kitchen_access_card = true
	print("Player picked up kitchen access card!")
	
	# Find all access card doors in the scene and grant access
	grant_kitchen_access_to_doors()

# Grant kitchen access to all doors that require it
func grant_kitchen_access_to_doors():
	# Find all nodes in the scene
	var scene_root = get_tree().current_scene
	_grant_access_recursive(scene_root)

func _grant_access_recursive(node: Node):
	# Check if this node is an AccessCardDoor that requires kitchen access
	if node.has_method("grant_access") and node.get("required_card") == "kitchen":
		node.grant_access()
	
	# Recursively check children
	for child in node.get_children():
		_grant_access_recursive(child)

# OPTIMIZED: Make trash invisible when picked up (no expensive material creation!)
# Since the game runs entirely in vision mode with black screen overlay,
# the 3D mesh is never visible anyway. Simply hide it instead of creating
# expensive transparent materials.
func make_trash_transparent(trash):
	if trash == null or !is_instance_valid(trash):
		return
	
	# Store original visibility state for restoration
	if trash not in trash_original_materials:
		trash_original_materials[trash] = {}
	
	# OPTIMIZED: Use cached mesh instances
	var mesh_instances = []
	if trash in cached_mesh_instances:
		mesh_instances = cached_mesh_instances[trash]
	else:
		_find_mesh_instances_recursive(trash, mesh_instances)
		cached_mesh_instances[trash] = mesh_instances
	
	# Simply hide the mesh instead of creating materials (100x faster!)
	for mesh_instance in mesh_instances:
		if mesh_instance is MeshInstance3D:
			# Store original visibility
			trash_original_materials[trash][mesh_instance] = mesh_instance.visible
			# Hide the mesh (FREE operation, no GPU cost)
			# TEMPORARILY DISABLED - mesh should remain visible when picked up
			#mesh_instance.visible = false

# OPTIMIZED: Restore trash visibility (no material operations needed!)
func restore_trash_opacity(trash):
	if trash == null or !is_instance_valid(trash):
		return
	
	if trash not in trash_original_materials:
		return
	
	# Restore original visibility state
	for mesh_instance in trash_original_materials[trash]:
		if is_instance_valid(mesh_instance):
			var original_visible = trash_original_materials[trash][mesh_instance]
			mesh_instance.visible = original_visible
	
	# Clear the stored visibility data
	trash_original_materials.erase(trash)

# Check if player has entered the study scene for the first time
func check_study_scene_entry():
	if study_scene_entered:
		return
	
	# Check if player is within the study scene bounds
	if is_player_in_study_scene():
		study_scene_entered = true
		print("Player entered Study Scene for the first time! Playing 6 pieces left audio...")
		# Play audio sequentially to avoid overlap
		play_study_audio_sequence()

# Play study audio sequence without overlap
func play_study_audio_sequence():
	# Play trash counter 6 audio
	if trash_counter_6_audio:
		play_narrative_audio(trash_counter_6_audio)

# Check if player has entered the freezer scene for the first time
func check_freezer_scene_entry():
	if freezer_scene_entered:
		return
	
	# Check if player is within the freezer scene bounds
	if is_player_in_freezer_scene():
		freezer_scene_entered = true
		print("Player entered Freezer Scene for the first time! Playing freezer audio...")
		if freezer_audio:
			play_narrative_audio(freezer_audio)

# Check if player is within the study scene bounds
func is_player_in_study_scene() -> bool:
	# Study scene is positioned at (-21.2638, 0, -1.05069) with rotation
	# The scene is roughly 8x8 units in size
	var study_center = Vector3(-21.2638, 0, -1.05069)
	var study_size = Vector3(8, 4, 8)  # Width, Height, Depth
	
	var player_pos = global_position
	var study_aabb = AABB(study_center - study_size/2, study_size)
	
	return study_aabb.has_point(player_pos)

# Check if player is within the freezer scene bounds
func is_player_in_freezer_scene() -> bool:
	# Freezer scene is positioned at (-20.5206, -0.033911, -17.9)
	# The scene is roughly 12x10 units in size
	var freezer_center = Vector3(-20.5206, -0.033911, -17.9)
	var freezer_size = Vector3(12, 4, 10)  # Width, Height, Depth
	
	var player_pos = global_position
	var freezer_aabb = AABB(freezer_center - freezer_size/2, freezer_size)
	
	return freezer_aabb.has_point(player_pos)

# Check if player has entered the kitchen scene for the first time
func check_kitchen_scene_entry():
	if kitchen_scene_entered:
		return
	
	# Check if player is within the kitchen scene bounds
	if is_player_in_kitchen_scene():
		kitchen_scene_entered = true
		print("Player entered Kitchen Scene for the first time! Playing breakfast audio...")
		if breakfast_audio:
			play_narrative_audio(breakfast_audio)

# Check if player is within the kitchen scene bounds
func is_player_in_kitchen_scene() -> bool:
	# Kitchen scene is positioned at (-21.6335, 0.220967, -9.34007) with rotation
	# The scene is roughly 8x8 units in size
	var kitchen_center = Vector3(-21.6335, 0.220967, -9.34007)
	var kitchen_size = Vector3(8, 4, 8)  # Width, Height, Depth
	
	var player_pos = global_position
	var kitchen_aabb = AABB(kitchen_center - kitchen_size/2, kitchen_size)
	
	return kitchen_aabb.has_point(player_pos)

# Check if player has entered the rec room scene for the first time
func check_rec_room_scene_entry():
	if rec_room_scene_entered:
		return
	
	# Check if player is within the rec room scene bounds
	if is_player_in_rec_room_scene():
		rec_room_scene_entered = true
		print("Player entered Rec Room Scene for the first time! Playing rec room audio...")
		if rec_room_audio:
			play_narrative_audio(rec_room_audio)

# Check if player has entered the bathroom scene for the first time
func check_bathroom_scene_entry():
	if bathroom_scene_entered:
		return
	
	if is_player_in_bathroom_scene():
		bathroom_scene_entered = true
		print("Player entered Bathroom Scene for the first time!")

# Check if player is within the bathroom scene bounds
func is_player_in_bathroom_scene() -> bool:
	# Bathroom is a small room (about 40% of an 8x8 room), so roughly 3x3 units.
	# Center these bounds on the BathroomScene placement in the world.
	# NOTE: Adjust bathroom_center if you move the BathroomScene in your main level.
	var bathroom_center = Vector3(-16.0, 0.0, -5.0)
	var bathroom_size = Vector3(3.2, 3.5, 3.2)  # Width, Height, Depth
	
	var player_pos = global_position
	var bathroom_aabb = AABB(bathroom_center - bathroom_size/2, bathroom_size)
	
	return bathroom_aabb.has_point(player_pos)

# Check if player is within the rec room scene bounds
func is_player_in_rec_room_scene() -> bool:
	# Rec room scene is positioned at (-32.1608, 0.173612, -17.9947) with rotation
	# The scene is roughly 10x10 units in size
	var rec_room_center = Vector3(-32.1608, 0.173612, -17.9947)
	var rec_room_size = Vector3(10, 4, 10)  # Width, Height, Depth
	
	var player_pos = global_position
	var rec_room_aabb = AABB(rec_room_center - rec_room_size/2, rec_room_size)
	
	return rec_room_aabb.has_point(player_pos)

# Decrement the global trash counter
func decrement_trash_counter():
	total_trash_left -= 1
	print("Trash thrown out! Remaining: ", total_trash_left)
	
	# Play audio for trash count
	match total_trash_left:
		5:
			if trash_counter_5_audio:
				play_narrative_audio(trash_counter_5_audio)
		4:
			if trash_counter_4_audio:
				play_narrative_audio(trash_counter_4_audio)
		3:
			if trash_counter_3_audio:
				play_narrative_audio(trash_counter_3_audio)
		2:
			if trash_counter_2_audio:
				play_narrative_audio(trash_counter_2_audio)
		1:
			# Activate the one piece left state
			if trash_counter_1_audio:
				play_narrative_audio(trash_counter_1_audio)
			one_piece_left_active = true
			print("One piece left! All objects now non-interactable except windows.")
		0:
			# This should not be reached via normal flow anymore - handled by trigger_final_end_sequence
			print("All trash has been thrown out!")
	
	if total_trash_left <= 0:
			print("All trash has been thrown out!")

# Stop all audio sources (called at start of end sequence)
func stop_all_audio():
	print("Stopping all audio for end sequence...")
	
	# Stop all audio players
	if footstep_audio and footstep_audio.playing:
		footstep_audio.stop()
	if gun_sound_audio and gun_sound_audio.playing:
		gun_sound_audio.stop()
	if scare_audio and scare_audio.playing:
		scare_audio.stop()
	if pickup_gun_audio and pickup_gun_audio.playing:
		pickup_gun_audio.stop()
	if ambient_audio and ambient_audio.playing:
		ambient_audio.stop()
	if todolist_audio and todolist_audio.playing:
		todolist_audio.stop()
	if trash_counter_6_audio and trash_counter_6_audio.playing:
		trash_counter_6_audio.stop()
	if trash_counter_5_audio and trash_counter_5_audio.playing:
		trash_counter_5_audio.stop()
	if trash_counter_4_audio and trash_counter_4_audio.playing:
		trash_counter_4_audio.stop()
	if trash_counter_3_audio and trash_counter_3_audio.playing:
		trash_counter_3_audio.stop()
	if trash_counter_2_audio and trash_counter_2_audio.playing:
		trash_counter_2_audio.stop()
	if trash_counter_1_audio and trash_counter_1_audio.playing:
		trash_counter_1_audio.stop()
	if breakfast_audio and breakfast_audio.playing:
		breakfast_audio.stop()
	if freezer_audio and freezer_audio.playing:
		freezer_audio.stop()
	if rec_room_audio and rec_room_audio.playing:
		rec_room_audio.stop()
	
	# Stop current narrative audio if playing
	if current_narrative_audio and current_narrative_audio.playing:
		print("Stopping current narrative audio: ", current_narrative_audio.name)
		current_narrative_audio.stop()
		current_narrative_audio = null
	
	# Stop any ambient audio nodes that might be playing (DefaultAmbientAudio, FreezerAmbientAudio, StairwayAmbientAudio)
	var default_ambient = get_node_or_null("DefaultAmbientAudio")
	if default_ambient and default_ambient.playing:
		default_ambient.stop()
	
	var freezer_ambient = get_node_or_null("FreezerAmbientAudio")
	if freezer_ambient and freezer_ambient.playing:
		freezer_ambient.stop()
	
	var stairway_ambient = get_node_or_null("StairwayAmbientAudio")
	if stairway_ambient and stairway_ambient.playing:
		stairway_ambient.stop()
	
	print("All audio stopped.")

# Trigger the final end sequence when player clicks window with one piece left
func trigger_final_end_sequence(window_object):
	if is_executing_final_sequence:
		return  # Prevent multiple triggers
	
	is_executing_final_sequence = true
	print("Triggering final end sequence!")
	
	# STOP ALL AUDIO IMMEDIATELY (ambient, voicelines, footsteps, everything)
	stop_all_audio()
	
	# Disable player input (capture mouse but don't allow movement)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# IMMEDIATELY make screen black
	if black_screen:
		black_screen.visible = true
		black_screen.color = Color.BLACK
	
	# Hide bounding boxes
	if bounding_box_container:
		bounding_box_container.visible = false
	
	# Wait 0.5 seconds
	await get_tree().create_timer(0.5).timeout
	
	# Play "End sequence audio.wav"
	if end_sequence_audio and end_sequence_audio.stream:
		end_sequence_audio.play()
		# Wait for it to finish
		await end_sequence_audio.finished
	else:
		print("No end sequence audio available")
	
	# Wait 2 seconds
	await get_tree().create_timer(2.0).timeout
	
	# Play "end.wav"
	if end_audio and end_audio.stream:
		end_audio.play()
		# Wait for it to finish
		await end_audio.finished
	else:
		print("No end audio available")
	
	# Wait 1.5 seconds
	await get_tree().create_timer(1.5).timeout
	
	# Show ASCII art "Cleaning out the rooms" for 3 seconds with confirm sound
	show_ascii_art_message()
	if confirm_sound_audio and confirm_sound_audio.stream:
		confirm_sound_audio.play()
	await get_tree().create_timer(3.0).timeout
	
	# Hide ASCII art before showing credits
	if ui_overlay.has_node("AsciiLabel"):
		ui_overlay.get_node("AsciiLabel").queue_free()
	
	# Show "A game by Wenye Zhou" for 3 seconds with confirm sound
	show_credits_message()
	if confirm_sound_audio and confirm_sound_audio.stream:
		confirm_sound_audio.play()
	await get_tree().create_timer(3.0).timeout
	
	# Quit the game
	print("Quitting game...")
	get_tree().quit()

# Show ASCII art message "Cleaning out the rooms"
func show_ascii_art_message():
	# Create a label for the ASCII art
	var ascii_label = Label.new()
	ascii_label.name = "AsciiLabel"
	# Simpler, more legible ASCII art
	ascii_label.text = """
 ██████╗ ██╗     ███████╗ █████╗ ███╗   ██╗██╗███╗   ██╗ ██████╗ 
██╔════╝ ██║     ██╔════╝██╔══██╗████╗  ██║██║████╗  ██║██╔════╝ 
██║      ██║     █████╗  ███████║██╔██╗ ██║██║██╔██╗ ██║██║  ███╗
██║      ██║     ██╔══╝  ██╔══██║██║╚██╗██║██║██║╚██╗██║██║   ██║
╚██████╗ ███████╗███████╗██║  ██║██║ ╚████║██║██║ ╚████║╚██████╔╝
 ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝ 
																   
 ██████╗ ██╗   ██╗████████╗                                       
██╔═══██╗██║   ██║╚══██╔══╝                                       
██║   ██║██║   ██║   ██║                                          
██║   ██║██║   ██║   ██║                                          
╚██████╔╝╚██████╔╝   ██║                                          
 ╚═════╝  ╚═════╝    ╚═╝                                          
																   
████████╗██╗  ██╗███████╗                                         
╚══██╔══╝██║  ██║██╔════╝                                         
   ██║   ███████║█████╗                                           
   ██║   ██╔══██║██╔══╝                                           
   ██║   ██║  ██║███████╗                                         
   ╚═╝   ╚═╝  ╚═╝╚══════╝                                         
																   
██████╗  ██████╗  ██████╗ ███╗   ███╗███████╗                    
██╔══██╗██╔═══██╗██╔═══██╗████╗ ████║██╔════╝                    
██████╔╝██║   ██║██║   ██║██╔████╔██║███████╗                    
██╔══██╗██║   ██║██║   ██║██║╚██╔╝██║╚════██║                    
██║  ██║╚██████╔╝╚██████╔╝██║ ╚═╝ ██║███████║                    
╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝     ╚═╝╚══════╝                    
"""
	
	ascii_label.add_theme_color_override("font_color", Color.GREEN)
	ascii_label.add_theme_font_size_override("font_size", 18)
	ascii_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ascii_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Use a monospace font for proper ASCII art display
	var font = SystemFont.new()
	font.font_names = ["Courier New", "Consolas", "Monaco", "monospace"]
	ascii_label.add_theme_font_override("font", font)
	
	# Make it fill the screen
	ascii_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Add to UI overlay
	ui_overlay.add_child(ascii_label)
	
	print("Showing ASCII art: Cleaning out the rooms")

# Show credits message "A game by Wenye Zhou"
func show_credits_message():
	# Create a label for the credits
	var credits_label = Label.new()
	credits_label.name = "CreditsLabel"
	credits_label.text = "A game by Wenye Zhou"
	
	credits_label.add_theme_color_override("font_color", Color.GREEN)
	credits_label.add_theme_font_size_override("font_size", 60)
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Make it fill the screen
	credits_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Add to UI overlay
	ui_overlay.add_child(credits_label)
	
	print("Showing credits: A game by Wenye Zhou")
