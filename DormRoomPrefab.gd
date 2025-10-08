extends BasePrefab

@export var room_number: String = ""
@export var occupant_name: String = ""
@export var is_smeared_plate: bool = false

func _ready():
	object_label = "Wall"  # Changed from "Dorm Room" to "Wall" so it doesn't show in OCR
	confidence = 0.90
	is_interactable = false
	super._ready()  # Call parent's _ready function
	
	# Configure the room plate with the room info - delay to ensure children are ready
	call_deferred("configure_room_plate")

func configure_room_plate():
	# Find the room plate child and configure it
	var room_plate = find_child("RoomPlatePrefab", true, false)
	if room_plate:
		room_plate.room_number = room_number
		room_plate.occupant_name = occupant_name
		room_plate.is_smeared = is_smeared_plate
		# Force the room plate to update its properties
		room_plate._ready()
		print("Configured room plate: ", room_number, " - ", occupant_name, " (smeared: ", is_smeared_plate, ")")
	else:
		print("ERROR: Could not find RoomPlatePrefab child!")
