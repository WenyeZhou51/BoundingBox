# Enemy AI Setup Guide

## Overview
This enemy AI system uses Godot's NavigationAgent3D for pathfinding around obstacles. The enemy chases the player using only horizontal movement (X, Z axes).

## Files Created
1. **EnemyPrefab.gd** - Enemy AI script with pathfinding logic
2. **EnemyPrefab.tscn** - Enemy prefab scene (red capsule)
3. **EnemyTestScene.tscn** - Test scene with navigation setup

## How to Use

### Testing the Enemy (Quick Start)
1. Open the Godot project
2. Open `EnemyTestScene.tscn` in the editor
3. **IMPORTANT**: You must bake the navigation mesh first (see below)
4. Run the scene (F6)
5. Move around with WASD - the red enemy will chase you around obstacles!

### Baking the Navigation Mesh (REQUIRED)
The navigation mesh tells the enemy where it can walk. You must bake it before the enemy will work:

1. In the Scene tree, select the **NavigationRegion3D** node
2. In the Inspector panel (right side), scroll down to find the "Bake NavigationMesh" section
3. Click the **"Bake NavMesh"** button
4. The floor should now show a blue overlay indicating the walkable area
5. Save the scene (Ctrl+S)

**You need to rebake the navigation mesh whenever you:**
- Move obstacles or walls
- Add new objects to the scene
- Change the floor layout

### Adding Enemy to Existing Scenes

#### Option 1: Use EnemyTestScene (Recommended for Testing)
- Just open and run `EnemyTestScene.tscn` after baking the navigation mesh

#### Option 2: Add to Your Own Scenes
1. Open your scene (e.g., KitchenScene.tscn)

2. **Add NavigationRegion3D:**
   - Add a NavigationRegion3D node at the root
   - Move your Floor and obstacle StaticBody3D nodes inside it
   - Click the NavigationRegion3D and click "Bake NavMesh" in the Inspector

3. **Add the Enemy:**
   - Drag `EnemyPrefab.tscn` into your scene
   - Position it where you want the enemy to spawn
   - The enemy must be at the root level (not inside NavigationRegion3D)

4. **Ensure Player is in "player" Group:**
   - Select the Player's CharacterBody3D node
   - In the Inspector, go to Node tab → Groups
   - Make sure "player" is in the groups list (it should already be there)

## Enemy Configuration

Select the Enemy node and adjust these settings in the Inspector:

### Movement Settings
- **Move Speed** (default: 3.0)
  - How fast the enemy moves
  - Player speed is 5.0, so enemy is slightly slower by default
  - Increase to make enemy faster/more dangerous
  
- **Detection Range** (default: 100.0)
  - How far the enemy can detect and chase the player
  - Reduce for a "proximity-based" enemy that only chases when close
  
- **Path Update Interval** (default: 0.5)
  - How often (in seconds) the enemy recalculates its path
  - Lower = more responsive but more CPU usage
  - Higher = less responsive but better performance

## How It Works

### Pathfinding System
1. **NavigationRegion3D** defines the walkable area
2. **NavigationMesh** is baked from the floor geometry
3. **NavigationAgent3D** (on enemy) calculates paths around obstacles
4. Enemy follows the path while maintaining horizontal-only movement

### Movement Behavior
- Enemy finds player using the "player" group
- Updates target position every 0.5 seconds
- Follows navigation path waypoints
- Only moves horizontally (X, Z), uses gravity for Y axis
- Smoothly rotates to face movement direction
- Stops if player is out of detection range

### Debug Visualization
The NavigationAgent3D has debug enabled, so you'll see:
- **Red line**: The path the enemy is following
- **Blue overlay**: Walkable navigation mesh areas

## Troubleshooting

### Enemy doesn't move
- **Check**: Did you bake the NavigationMesh? (See "Baking" section above)
- **Check**: Is the player node in the "player" group?
- **Check**: Is the enemy positioned on the navigation mesh (not floating/underground)?
- **Check**: Run the scene and look for console messages like "Enemy: Found player"

### Enemy walks through walls
- **Fix**: Make sure walls are StaticBody3D with CollisionShape3D
- **Fix**: Walls should be inside NavigationRegion3D before baking
- **Fix**: Rebake the navigation mesh after adding/moving walls

### Enemy gets stuck
- **Fix**: Increase `path_max_distance` on NavigationAgent3D (default: 3.0)
- **Fix**: Adjust `radius` on NavigationAgent3D to match enemy size
- **Fix**: Rebake navigation mesh with adjusted settings

### Enemy is too slow/fast
- **Fix**: Adjust `move_speed` in the Inspector (3.0 = slower than player)
- Player moves at 5.0 units/second by default

### Navigation mesh doesn't cover the floor
- **Fix**: In NavigationRegion3D settings, adjust:
  - Agent Radius (default 0.5) - clearance around obstacles
  - Agent Height (default 1.8) - how tall the agent is
  - Cell Size (default 0.25) - smaller = more detailed but slower to bake

## Advanced: Multiple Enemies

To add multiple enemies:
1. Instance EnemyPrefab multiple times in your scene
2. Position each enemy at different spawn points
3. Each enemy will independently chase the player
4. They all use the same NavigationRegion3D

## Code Overview

### EnemyPrefab.gd Key Functions

```gdscript
_ready()
    # Finds player, sets up navigation agent

_physics_process(delta)
    # Updates path, moves toward player, applies gravity

update_target_location()
    # Sets navigation target to player's current position
```

### Customization Ideas
- Add detection cone (only chase if player is in front)
- Add patrol points when player is out of range
- Add attack behavior when close to player
- Add different enemy types (fast/slow, different detection ranges)
- Make enemy run away when player has a weapon

## Integration with Existing Game

Your game already has:
- Player in "player" group ✓
- StaticBody3D for walls ✓
- Scenes with floors and obstacles ✓

You just need to:
1. Add NavigationRegion3D to your scenes
2. Bake navigation meshes
3. Add enemy instances

The enemy will work with your existing bounding box vision system and game mechanics!

