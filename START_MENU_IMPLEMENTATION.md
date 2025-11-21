# Start Menu Implementation

## Overview
A start menu has been implemented with bounding box styling that matches the in-game object detection aesthetic. The menu appears before the game starts and provides three options: Start, Options, and Quit.

## Features

### Menu Structure
1. **Title Box** - Large bounding box at the top labeled "Title" with confidence score 0.98
2. **Start Button** - Clickable bounding box that starts the game
3. **Options Button** - Clickable bounding box that flashes "NOne" when clicked
4. **Quit Button** - Clickable bounding box that exits the game

### Visual Style
- All menu elements are styled as green bounding boxes (matching in-game style)
- Each box has:
  - Hollow green border (2px width)
  - Label with confidence score (e.g., "Start: 0.95")
  - Black text on green background for labels
  - Confidence scores are randomly generated between 0.85 and 0.99

### Interactions
- **Start Button**: Plays confirm sound → Loads the game (PlayerUI.tscn with intro sequence)
- **Options Button**: Plays confirm sound → Flashes "NOne" text in large green letters for 1 second
- **Quit Button**: Plays confirm sound → Quits the application

## File Structure

### Created Files
1. **StartMenu.gd** - Script that creates the menu UI programmatically
2. **StartMenu.tscn** - Scene file containing the menu layout
3. **MainScene.gd** - Main scene controller that loads start menu then game
4. **MainScene.tscn** - Root scene that manages the flow

### Modified Files
1. **PlayerUI.tscn** - Removed inline StartMenu (using MainScene flow instead)
2. **IntroSequence.gd** - Reverted to original behavior (no start menu handling)
3. **project.godot** - Main scene set to MainScene.tscn

## How It Works

### Flow
1. Game launches → MainScene.tscn loads
2. MainScene loads StartMenu.tscn as overlay
3. User clicks "Start" → MainScene removes start menu
4. MainScene loads PlayerUI.tscn (full game)
5. IntroSequence plays (incoming message → MIRROR letter)
6. Game starts

### Technical Details
- StartMenu creates UI elements programmatically in `_ready()`
- Uses signals (`start_game`, `quit_game`) to communicate with MainScene
- Bounding boxes use the same `create_hollow_border()` function as in-game boxes
- Options button creates a centered "NOne" label that flashes for 1 second

## Testing
To test the implementation:
1. Run the game (F5 in Godot or run MainScene.tscn)
2. You should see the start menu with Title and three buttons
3. Click "Options" to see "NOne" flash
4. Click "Start" to begin the game (intro sequence will play)
5. Click "Quit" to exit

## Notes
- The "NOne" text in Options is styled to match the game's aesthetic (deliberate non-standard spelling)
- All bounding boxes use the same visual style as in-game object detection boxes
- Confidence scores are randomized for variety but maintain realistic ranges
- The menu is fully keyboard-navigable (buttons respond to mouse clicks)

