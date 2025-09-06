extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var sensitivity: float = 0.002
@export var max_detection_distance: float = 50.0
@export var interaction_distance: float = 3.0  # Reasonable interaction distance

@onready var camera: Camera3D = $Camera3D
@onready var ui_overlay: Control = $UIOverlay
@onready var black_screen: ColorRect = $UIOverlay/BlackScreen
@onready var bounding_box_container: Control = $UIOverlay/BoundingBoxContainer

# Audio nodes
@onready var footstep_audio: AudioStreamPlayer = $FootstepAudio
@onready var gun_sound_audio: AudioStreamPlayer = $GunSoundAudio

# Reference to the intro sequence
var intro_sequence: Control
var game_started: bool = false

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var vision_mode: bool = false
var detected_objects: Array[BasePrefab] = []
var interactable_objects_in_range: Array[BasePrefab] = []

# Confidence fluctuation system
var confidence_fluctuations: Dictionary = {}  # Store fluctuations for each object
var fluctuation_timer: float = 0.0
var fluctuation_update_interval: float = 1.0  # Update every second

# Footstep audio variables
var is_walking: bool = false
var was_walking: bool = false

func _ready():
	# Add player to group for easy finding by other scripts
	add_to_group("player")
	
	# Don't capture mouse cursor initially - wait for intro to complete
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Set up audio properties
	if footstep_audio and footstep_audio.stream:
		footstep_audio.stream.loop = true
	
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

func _on_intro_complete():
	game_started = true
	# Now capture the mouse cursor and enable bounding box vision mode
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Start in bounding box vision mode as requested
	vision_mode = true
	black_screen.visible = true
	bounding_box_container.visible = true
	update_bounding_boxes()

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
	
	# Toggle vision mode with F key
	if event is InputEventKey and event.keycode == KEY_F and event.pressed:
		toggle_vision_mode()
	
	# Handle mouse click for interaction
	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_LEFT:
			handle_interaction()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Play gun sound on right click
			if gun_sound_audio:
				gun_sound_audio.play()
			handle_right_click_interaction()

func _physics_process(delta):
	# Don't handle physics until game has started
	if not game_started:
		return
		
	# Add the gravity.
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
	
	# Update confidence fluctuations timer
	fluctuation_timer += delta
	if fluctuation_timer >= fluctuation_update_interval:
		fluctuation_timer = 0.0
		update_confidence_fluctuations()
	
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
	var scene_root = get_tree().current_scene
	_find_prefabs_recursive(scene_root)
	print("Found ", detected_objects.size(), " prefab objects:")
	for obj in detected_objects:
		var is_mirror = obj.has_method("get_player_reflection_info")
		print("  - ", obj.object_label, " (Interactable: ", obj.is_interactable, ", Mirror: ", is_mirror, ")")

# Add a new detected object to the list (used when spawning broken glass)
func add_detected_object(obj: BasePrefab):
	if obj not in detected_objects:
		detected_objects.append(obj)
		print("Added new detected object: ", obj.object_label)

func _find_prefabs_recursive(node: Node):
	if node is BasePrefab:
		detected_objects.append(node as BasePrefab)
	
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
	for child in bounding_box_container.get_children():
		child.queue_free()

func update_bounding_boxes():
	clear_bounding_boxes()
	
	# First, check for mirror reflections
	check_mirror_reflections()
	
	for obj in detected_objects:
		if obj == null or !is_instance_valid(obj):
			continue
			
		# Skip walls - don't show bounding boxes for them
		if obj.object_label == "Wall":
			continue
			
		# Check if object should be visible in vision mode
		if !obj.should_be_visible_in_vision_mode():
			continue
			
		# Check if object's center is in line of sight (walls can block vision)
		if !is_object_center_in_line_of_sight(obj):
			continue
			
		var bbox = calculate_screen_bounding_box(obj)
		if bbox != Rect2():
			var is_interactable_in_range = obj in interactable_objects_in_range
			create_bounding_box_ui(obj, bbox, is_interactable_in_range)

func calculate_screen_bounding_box(obj: BasePrefab) -> Rect2:
	var camera_3d = camera
	var viewport = get_viewport()
	
	# Get object bounds in world space
	var aabb = get_object_aabb(obj)
	if aabb.size == Vector3.ZERO:
		return Rect2()
	
	# Removed distance and field of view checks
	
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
		var local_pos = camera_3d.to_local(corner)
		if local_pos.z < 0:  # In front of camera
			any_in_front = true
			var screen_pos = camera_3d.unproject_position(corner)
			min_screen.x = min(min_screen.x, screen_pos.x)
			min_screen.y = min(min_screen.y, screen_pos.y)
			max_screen.x = max(max_screen.x, screen_pos.x)
			max_screen.y = max(max_screen.y, screen_pos.y)
	
	if !any_in_front:
		return Rect2()
	
	# Removed screen boundary checks - allow bounding boxes to extend outside screen
	
	# Only return the bounding box if it's valid
	if min_screen.x >= max_screen.x or min_screen.y >= max_screen.y:
		return Rect2()
	
	return Rect2(min_screen, max_screen - min_screen)

func get_object_aabb(obj: BasePrefab) -> AABB:
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

func get_object_center(obj: BasePrefab) -> Vector3:
	# Get the AABB of the object and return its center
	var aabb = get_object_aabb(obj)
	if aabb.size == Vector3.ZERO:
		# If no mesh found, use the object's global position
		return obj.global_position
	return aabb.get_center()

func is_object_center_in_line_of_sight(obj: BasePrefab) -> bool:
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

func create_bounding_box_ui(obj: BasePrefab, bbox: Rect2, is_interactable_in_range: bool = false):
	# Create container for this bounding box
	var container = Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	container.position = bbox.position
	container.size = bbox.size
	bounding_box_container.add_child(container)
	
	# Choose color based on interactability and range
	var border_color = Color.GREEN
	var label_bg_color = Color.GREEN
	if is_interactable_in_range:
		border_color = Color.YELLOW
		label_bg_color = Color.YELLOW
	
	# Create hollow border using 4 ColorRect nodes
	create_hollow_border(container, bbox.size, border_color)
	
	# Prepare label text
	var fluctuation = confidence_fluctuations.get(obj, 0.0)
	var display_confidence = clamp(obj.confidence + fluctuation, 0.0, 1.0)
	var label_text = obj.object_label + ": " + str(round(display_confidence * 100) / 100.0)
	if is_interactable_in_range:
		label_text += " [INTERACT]"
	
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

func create_hollow_border(container: Control, box_size: Vector2, color: Color = Color.GREEN):
	var border_width = 2
	
	# Top border
	var top_border = ColorRect.new()
	top_border.color = color
	top_border.position = Vector2(0, 0)
	top_border.size = Vector2(box_size.x, border_width)
	container.add_child(top_border)
	
	# Bottom border
	var bottom_border = ColorRect.new()
	bottom_border.color = color
	bottom_border.position = Vector2(0, box_size.y - border_width)
	bottom_border.size = Vector2(box_size.x, border_width)
	container.add_child(bottom_border)
	
	# Left border
	var left_border = ColorRect.new()
	left_border.color = color
	left_border.position = Vector2(0, 0)
	left_border.size = Vector2(border_width, box_size.y)
	container.add_child(left_border)
	
	# Right border
	var right_border = ColorRect.new()
	right_border.color = color
	right_border.position = Vector2(box_size.x - border_width, 0)
	right_border.size = Vector2(border_width, box_size.y)
	container.add_child(right_border)

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

# Find the BasePrefab parent of a node
func find_prefab_parent(node: Node) -> BasePrefab:
	var current_node = node
	while current_node != null:
		if current_node is BasePrefab:
			return current_node as BasePrefab
		current_node = current_node.get_parent()
	return null

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
	for obj in detected_objects:
		if obj == null or !is_instance_valid(obj):
			continue
		
		# Check if this is a mirror (has the get_player_reflection_info method)
		if obj.has_method("get_player_reflection_info"):
			mirror_count += 1
			var reflection_info = obj.get_player_reflection_info()
			if reflection_info.has("active") and reflection_info.active:
				print("FirstPersonController: Creating reflection bounding box")
				create_reflection_bounding_box(reflection_info)
	
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
	
	# Create a much larger bounding box size for the player reflection
	# Make it about half the size of the mirror (which is 3x4 units)
	var bbox_size = Vector2(300, 400)  # Width x Height in pixels - half the mirror size for proper reflection
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

# Handle footstep audio based on walking state
func handle_footstep_audio():
	# Only play footsteps if player is on the floor and walking
	var should_play_footsteps = is_walking and is_on_floor()
	
	if should_play_footsteps and not was_walking:
		# Start playing footsteps
		if footstep_audio and not footstep_audio.playing:
			footstep_audio.play()
	elif not should_play_footsteps and was_walking:
		# Stop playing footsteps
		if footstep_audio and footstep_audio.playing:
			footstep_audio.stop()
	
	was_walking = should_play_footsteps