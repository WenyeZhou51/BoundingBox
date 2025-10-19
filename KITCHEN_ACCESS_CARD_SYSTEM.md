# Kitchen Access Card System Implementation

This document describes the kitchen access card system that has been added to the game.

## Overview

The kitchen access card system restricts access to certain areas of the game until the player finds and picks up the kitchen access card. Specifically:

1. **Right door in Study** - Initially displays "NEED KITCHEN ACCESS" and cannot be opened
2. **Kitchen Access Card** - Located in dorm room 1025 (Shay Thompson's room)
3. **After pickup** - The right door in Study changes to "SWIPE OPEN" and can be opened

## Components Created

### 1. KitchenAccessCardPrefab
**Files:** `KitchenAccessCardPrefab.gd`, `KitchenAccessCardPrefab.tscn`

- **Visual:** Orange-colored card (RGB: 1.0, 0.6, 0.2)
- **Object Label:** "Kitchen Access Card"
- **Confidence:** 0.96
- **Interactable:** Yes - "Pick Up"
- **Behavior:** When picked up, notifies the player controller and hides itself

### 2. AccessCardDoorPrefab
**Files:** `AccessCardDoorPrefab.gd`, `AccessCardDoorPrefab.tscn`

- **Based on:** DoorPrefab structure
- **Export Variable:** `required_card: String` - specifies which card is needed (set to "kitchen")
- **Object Label:** "Door"
- **Confidence:** 0.95
- **States:**
  - **Without access:** "NEED KITCHEN ACCESS" - door cannot be opened
  - **With access:** "SWIPE OPEN" - door can be opened normally
- **Behavior:** Same as regular door once access is granted (disappears for 5 seconds, checks for player in doorway)

### 3. FirstPersonController Updates
**File:** `FirstPersonController.gd`

Added new functionality:
```gdscript
# Variable
var has_kitchen_access_card: bool = false

# Functions
func pickup_kitchen_access_card()
func grant_kitchen_access_to_doors()
func _grant_access_recursive(node: Node)
```

**Flow:**
1. When kitchen access card is picked up, `pickup_kitchen_access_card()` is called
2. This function sets the flag and calls `grant_kitchen_access_to_doors()`
3. The function recursively searches the scene tree for all AccessCardDoors requiring "kitchen" access
4. All matching doors have their `grant_access()` method called
5. Doors update their interaction text and become usable

## Scene Modifications

### 1. StudyScene.tscn
- **Changed:** EastDoor (right door at position 3.9, 0, 0)
- **From:** Regular DoorPrefab
- **To:** AccessCardDoorPrefab with `required_card = "kitchen"`

### 2. DormHallwayScene.tscn
- **Added:** KitchenAccessCard to Room1025_Shay
- **Position:** (0.8, 0.85, -0.3) relative to room (on desk)
- **Room Details:**
  - Room Number: 1025
  - Occupant: Shay Thompson
  - Location: Left side of hallway at (6, 0, -5)

## How It Works

### Player Perspective:

1. **First Visit to Study:**
   - Player approaches the right door (east door)
   - Visor displays: "Door: 0.95 [NEED KITCHEN ACCESS]" (yellow box when looking at it)
   - Clicking the door does nothing - access denied message in console

2. **Finding the Card:**
   - Player navigates to dorm hallway
   - Enters room 1025 (Shay Thompson's room)
   - Finds orange kitchen access card on desk
   - Visor displays: "Kitchen Access Card: 0.96 [Pick Up]"
   - Player clicks to pick up the card

3. **After Pickup:**
   - Card disappears from room
   - Console message: "Player picked up kitchen access card!"
   - All kitchen access doors in the scene automatically update

4. **Return to Study:**
   - Player approaches the right door again
   - Visor now displays: "Door: 0.95 [SWIPE OPEN]"
   - Clicking the door opens it (disappears for 5 seconds)
   - Door provides access to the kitchen area

### Technical Flow:

```
Player clicks Kitchen Access Card
    ↓
KitchenAccessCardPrefab.interact()
    ↓
Calls player.pickup_kitchen_access_card()
    ↓
FirstPersonController.pickup_kitchen_access_card()
    ↓
Sets has_kitchen_access_card = true
    ↓
Calls grant_kitchen_access_to_doors()
    ↓
Recursively searches scene tree
    ↓
Finds all AccessCardDoors with required_card = "kitchen"
    ↓
Calls grant_access() on each door
    ↓
Doors update their interaction_text to "SWIPE OPEN"
    ↓
Doors set has_access = true
    ↓
Doors become functional
```

## Extensibility

The system is designed to be easily extensible:

### Adding More Access Cards:

1. Create new prefabs (e.g., `LabAccessCardPrefab`)
2. Set different visual color
3. Call `player.pickup_[type]_access_card()` with appropriate type

### Adding More Restricted Doors:

1. Instance AccessCardDoorPrefab in any scene
2. Set `required_card` property to match card type (e.g., "kitchen", "lab", "admin")
3. Door will automatically check for access when player picks up the matching card

### Example for Lab Access:

```gdscript
# In AccessCardDoorPrefab
required_card = "lab"

# In FirstPersonController
var has_lab_access_card: bool = false

func pickup_lab_access_card():
    has_lab_access_card = true
    print("Player picked up lab access card!")
    grant_lab_access_to_doors()
```

## Testing

To test the system:

1. **Without Card:**
   - Start in Study scene
   - Approach right door (east)
   - Verify text shows "NEED KITCHEN ACCESS"
   - Try to open - should be denied

2. **With Card:**
   - Navigate to dorm hallway
   - Enter room 1025
   - Pick up orange kitchen access card
   - Return to Study
   - Approach right door
   - Verify text shows "SWIPE OPEN"
   - Open door successfully

## Files Modified/Created

### New Files:
- `KitchenAccessCardPrefab.gd` - Kitchen access card behavior
- `KitchenAccessCardPrefab.tscn` - Kitchen access card scene
- `AccessCardDoorPrefab.gd` - Access card door behavior
- `AccessCardDoorPrefab.tscn` - Access card door scene
- `KITCHEN_ACCESS_CARD_SYSTEM.md` - This documentation

### Modified Files:
- `FirstPersonController.gd` - Added access card pickup tracking
- `StudyScene.tscn` - Replaced east door with access card door
- `DormHallwayScene.tscn` - Added kitchen access card to room 1025

## Summary

The kitchen access card system provides a simple but effective progression mechanic. Players must explore the dorm area to find the kitchen access card before they can access the kitchen through the study. The system is modular and can be easily expanded to include additional access cards and restricted areas.
