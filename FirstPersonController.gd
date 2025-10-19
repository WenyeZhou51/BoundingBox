extends CharacterBody3D

@export var speed: float = 12.5
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
var raycast_cache: Dictionary = {}  # object -> {visible: bool, frame: int}
var current_frame: int = 0
var raycast_update_interval: int = 3  # Update raycasts every N frames

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

# Reference to the intro sequence and end sequence
var intro_sequence: Control
var end_sequence: Control
var game_started: bool = false
var flash_message_label: Label

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var vision_mode: bool = false
var detected_objects: Array = []  # Can be BasePrefab or objects with BasePrefab-like properties
var interactable_objects_in_range: Array = []  # Can be BasePrefab or objects with BasePrefab-like properties

# Confidence fluctuation system
var confidence_fluctuations: Dictionary = {}  # Store fluctuations for each object
var fluctuation_timer: float = 0.0
var fluctuation_update_interval: float = 1.0  # Update every second

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
	
	# Start ambient audio now that the level has started
	start_ambient_audio()
	
	# Now play the start sequence (audio + flash message) while player can move
	play_start_sequence()

func play_start_sequence():
	# Play the todolist audio
	if todolist_audio:
		print("Playing todolist audio...")
		todolist_audio.play()
		
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
	
	# F key: Pickup/drop trash
	if event is InputEventKey and event.keycode == KEY_F and event.pressed:
		# If holding trash, drop it
		if held_trash:
			drop_trash()
		else:
			# Try to pick up trash
			try_pickup_trash()
	
	# 8 key: Toggle vision mode
	if event is InputEventKey and event.keycode == KEY_8 and event.pressed:
		toggle_vision_mode()
	
	# Handle mouse click for interaction
	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_LEFT:
			handle_interaction()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
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
	
	# Update held trash position if carrying something
	if held_trash:
		update_held_trash_position()
	
	# Update bounding boxes in vision mode
	if vision_mode:
		update_interactable_objects()  # Update interactables for yellow highlighting
		update_bounding_boxes()
	else:
		# In normal mode, hide any bounding boxes
		bounding_box_container.visible = false

func update_confidence_fluctuations():
	# Update fluctuations for all detected objects
	for obj in detected_objects:
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
	_find_mesh_instances_recursive(obj, mesh_instances)
	
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
	
	# First, check for mirror reflections
	check_mirror_reflections()
	
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
		
		# OPTIMIZATION 2: Cached raycast check (update every N frames)
		if !is_object_visible_cached(obj):
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
	# For RigidBody3D objects (physics objects), recalculate AABB every frame since they can move
	var aabb: AABB
	if obj is RigidBody3D:
		aabb = calculate_object_aabb(obj)
		if aabb.size == Vector3.ZERO:
			return Rect2()
		# Update the cache with the new AABB
		cached_aabbs[obj] = {
			"aabb": aabb,
			"center": aabb.get_center()
		}
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
	
	return Rect2(min_screen, max_screen - min_screen)

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
func is_object_visible_cached(obj) -> bool:
	# Check if we have a recent cached result
	if obj in raycast_cache:
		var cache_entry = raycast_cache[obj]
		var frames_old = current_frame - cache_entry.frame
		if frames_old < raycast_update_interval:
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
	
	# Find all MeshInstance3D nodes in the object
	var mesh_instances = []
	_find_mesh_instances_recursive(obj, mesh_instances)
	
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

func is_object_center_in_line_of_sight(obj) -> bool:
	var camera_pos = camera.global_position
	var object_center = get_object_center(obj)
	
	# Create a ray from camera to object center
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(camera_pos, object_center)
	
	# Exclude the player from the raycast
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
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
	
	if is_interactable_in_range:
		border_color = Color.YELLOW
		label_bg_color = Color.YELLOW
	
	# Prepare label text (empty if battery saving mode)
	var label_text = ""
	if not battery_saving_mode:
		var fluctuation = confidence_fluctuations.get(obj, 0.0)
		var display_confidence = clamp(obj.confidence + fluctuation, 0.0, 1.0)
		label_text = obj.object_label + ": " + str(round(display_confidence * 100) / 100.0)
		
		if is_interactable_in_range:
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
		
		# Update label text and background
		cached.label.text = label_text
		cached.label_bg.color = label_bg_color
		
		# Hide label in battery saving mode
		if battery_saving_mode:
			cached.label.visible = false
			cached.label_bg.visible = false
		else:
			cached.label.visible = true
			cached.label_bg.visible = true
			# Recalculate label background size
			var font = cached.label.get_theme_default_font()
			var font_size = 20
			var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			cached.label_bg.size = Vector2(text_size.x + 10, 25)
	else:
		# CREATE new UI
		var container = Control.new()
		container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		container.position = bbox.position
		container.size = bbox.size
		bounding_box_container.add_child(container)
		
		# Create hollow border
		var borders = create_hollow_border_array(container, bbox.size, border_color)
		
		# Create label
		var label = Label.new()
		label.text = label_text
		label.add_theme_color_override("font_color", Color.BLACK)
		label.add_theme_font_size_override("font_size", 20)
		label.position = Vector2(5, -28)
		
		# Measure text size
		var font = label.get_theme_default_font()
		var font_size = 20
		var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		
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
		
		# Cache the UI elements
		cached_bounding_boxes[obj] = {
			"container": container,
			"borders": borders,
			"label": label,
			"label_bg": label_bg
		}

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
		return
	
	if obj in cached_bounding_boxes:
		var cached = cached_bounding_boxes[obj]
		if is_instance_valid(cached.container):
			cached.container.queue_free()
		cached_bounding_boxes.erase(obj)

# Legacy function kept for compatibility
func create_bounding_box_ui(obj, bbox: Rect2, is_interactable_in_range: bool = false):
	update_or_create_bounding_box_ui(obj, bbox, is_interactable_in_range)

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
	
	# Position it in front of the camera
	update_held_trash_position()

# Drop the currently held trash
func drop_trash():
	if not held_trash:
		return
	
	print("Dropping trash: ", held_trash.object_label)
	
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
	
	# Calculate position relative to camera
	var target_pos = camera.global_position + camera.global_transform.basis * trash_hold_offset
	held_trash.global_position = target_pos
	
	# Don't override rotation - let the object keep its natural orientation
	# This prevents physics instability from constant rotation changes

# Update list of interactable objects in range using raycast (same as actual interaction)
func update_interactable_objects():
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
	
	# Only print in vision mode when we have interactables
	if vision_mode and interactable_objects_in_range.size() > 0:
		print("Found ", interactable_objects_in_range.size(), " interactable(s) in range")
	
	# Update yellow highlighting for interactable objects
	update_interactable_highlighting()

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
	# Find all mirror objects in the scene
	var mirror_count = 0
	var any_reflection_active = false
	
	for obj in detected_objects:
		if obj == null or !is_instance_valid(obj):
			continue
		
		# Check if this is a mirror (has the get_player_reflection_info method)
		if obj.has_method("get_player_reflection_info"):
			mirror_count += 1
			var reflection_info = obj.get_player_reflection_info()
			if reflection_info.has("active") and reflection_info.active:
				any_reflection_active = true
				print("FirstPersonController: Creating reflection bounding box")
				create_reflection_bounding_box(reflection_info)
	
	# Play scare audio when reflection becomes active for the first time
	if any_reflection_active and not reflection_was_active:
		if scare_audio:
			print("FirstPersonController: Playing scare audio - reflection appeared!")
			scare_audio.play()
	
	# Update reflection state for next frame
	reflection_was_active = any_reflection_active
	
	# Debug: Print mirror count once per second
	if mirror_count > 0:
		var current_time = Time.get_time_dict_from_system()
		var seconds = current_time.second
		if seconds != get_meta("last_debug_second", -1):
			set_meta("last_debug_second", seconds)
			print("FirstPersonController: Found ", mirror_count, " mirrors in detected_objects")

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
	
	# Prepare label text for reflection
	var label_text = reflection_info.label + ": " + str(reflection_info.confidence)
	
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
	
	# Stop ambient audio before starting end sequence
	stop_ambient_audio()
	
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
	
	# Set up ambient audio looping (but DON'T start playing yet - wait for intro to complete)
	if ambient_audio:
		print("Ambient audio node found: ", ambient_audio)
		if ambient_audio.stream:
			print("Ambient audio stream found: ", ambient_audio.stream)
			print("Stream type: ", ambient_audio.stream.get_class())
			if ambient_audio.stream is AudioStreamMP3:
				ambient_audio.stream.loop = true
				print("  - Set MP3 loop = true, current value: ", ambient_audio.stream.loop)
			elif ambient_audio.stream is AudioStreamWAV:
				ambient_audio.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				print("  - Set WAV loop_mode = LOOP_FORWARD")
		else:
			print("ERROR: Ambient audio stream is null!")
	else:
		print("ERROR: Ambient audio node not found!")

# Start ambient audio (called when level starts, after intro)
func start_ambient_audio():
	if ambient_audio:
		print("=== Starting Ambient Audio ===")
		print("  Node: ", ambient_audio)
		print("  Stream: ", ambient_audio.stream)
		print("  Volume: ", ambient_audio.volume_db, " dB")
		
		if ambient_audio.stream:
			# Ensure loop is set for MP3
			if ambient_audio.stream is AudioStreamMP3:
				ambient_audio.stream.loop = true
				print("  MP3 loop enabled: ", ambient_audio.stream.loop)
			
			if not ambient_audio.playing:
				ambient_audio.play()
				print("  ✓ Started playing ambient audio")
			else:
				print("  Ambient audio already playing")
		else:
			print("  ERROR: Ambient audio stream is null!")
	else:
		print("ERROR: AmbientAudio node not found!")

# Stop ambient audio (called when end sequence starts)
func stop_ambient_audio():
	if ambient_audio and ambient_audio.playing:
		ambient_audio.stop()
		print("Stopped ambient audio for end sequence")

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
