# Quick Guide: Adding Enemy to Existing Scenes

## Step-by-Step Process

### 1. Open Your Scene
Open any existing scene (e.g., `LivingRoomScene.tscn`, `StudyScene.tscn`, etc.)

### 2. Add NavigationRegion3D
1. Right-click on the root node
2. Add Child Node → Search for `NavigationRegion3D`
3. Add it

### 3. Move Static Geometry Inside NavigationRegion3D
**Important:** The navigation system needs to "see" your walls and floors to know where the enemy can walk.

Move these nodes **into** the NavigationRegion3D:
- Floor (StaticBody3D)
- All Walls (StaticBody3D nodes)
- Any obstacles (furniture with collision)

**DO NOT move these:**
- Player node (keep at root)
- Environment/Lighting nodes
- Any prefabs that are pickups/interactables

Your hierarchy should look like:
```
YourScene (Node3D)
├─ NavigationRegion3D
│  ├─ Floor (StaticBody3D)
│  ├─ Walls (StaticBody3D nodes)
│  ├─ Furniture (obstacles with collision)
│  └─ KitchenItems/Furniture/etc (nodes with StaticBody3D)
├─ Player
├─ Enemy (add next step)
└─ Environment
```

### 4. Bake the Navigation Mesh
1. Select the **NavigationRegion3D** node
2. Look at the Inspector panel (right side)
3. Scroll down until you see "Bake NavigationMesh"
4. Click the **"Bake NavMesh"** button
5. You should see a blue overlay on the floor showing walkable areas
6. If the blue overlay doesn't appear:
   - Check that Floor is inside NavigationRegion3D
   - Check that Floor has a CollisionShape3D
   - Try adjusting settings in NavigationMesh → Geometry

### 5. Add the Enemy
1. Drag `EnemyPrefab.tscn` from FileSystem into your scene
2. Place it at the **root level** (next to Player, not inside NavigationRegion3D)
3. Position it where you want (e.g., opposite corner from player)
4. Make sure Y position is at floor level (usually 0)

### 6. Test It!
1. Save the scene (Ctrl+S)
2. Run the scene (F6)
3. Move around - the red enemy should chase you!

## Example: Converting KitchenScene

**Before:**
```
KitchenScene
├─ Environment
├─ Room (contains Floor, Walls)
├─ KitchenItems (Counter, Stove, etc.)
└─ Doors
```

**After:**
```
KitchenScene
├─ Environment
├─ NavigationRegion3D
│  ├─ Room (contains Floor, Walls)
│  ├─ KitchenItems (Counter, Stove, etc.)
│  └─ Doors
├─ Player
└─ Enemy
```

See `KitchenSceneWithEnemy.tscn` for a complete working example!

## Navigation Settings (Advanced)

If the navigation isn't working well, select NavigationRegion3D and adjust these in the Inspector:

### Under NavigationMesh → Agents:
- **Agent Height**: 1.8 (matches character height)
- **Agent Radius**: 0.5 (how much clearance around obstacles)
- **Agent Max Climb**: 0.5 (can climb small steps)

### Under NavigationMesh → Geometry:
- **Parsed Geometry Type**: Static Colliders (default)
- **Source Geometry Mode**: NavMesh Children (default)

### After changing any settings:
**You must rebake!** Click "Bake NavMesh" again.

## Common Issues

### Blue navigation mesh doesn't appear after baking
- **Cause**: Floor isn't inside NavigationRegion3D
- **Fix**: Move Floor node inside NavigationRegion3D, rebake

### Enemy doesn't move
- **Cause**: Navigation mesh not baked
- **Fix**: Select NavigationRegion3D, click "Bake NavMesh"

### Enemy walks through walls
- **Cause**: Walls aren't inside NavigationRegion3D before baking
- **Fix**: Move walls inside NavigationRegion3D, rebake

### Enemy can't reach certain areas
- **Cause**: Agent radius too large, can't fit through gaps
- **Fix**: Reduce Agent Radius in NavigationMesh settings, rebake

### Navigation mesh has gaps
- **Cause**: Cell size too large
- **Fix**: In NavigationMesh → Cells, reduce Cell Size to 0.1, rebake (warning: slower)

## Multiple Rooms / Large Scenes

If you have a scene with multiple connected rooms (like TestScene with multiple room instances):

**Option 1: Single NavigationRegion3D**
- Add one NavigationRegion3D at root
- Move ALL room floors/walls inside it
- Bake once
- Enemies can navigate between all rooms

**Option 2: Multiple NavigationRegion3D**
- Add one NavigationRegion3D per room
- Each has its own navigation mesh
- Enemies can navigate within their room
- Won't automatically path between rooms

**Recommended:** Option 1 for most cases

## Performance Tips

- **Path Update Interval**: Default 0.5 seconds is good. Don't set below 0.1 unless needed
- **Detection Range**: Lower = better performance. Set to room size if enemies shouldn't chase far
- **Navigation Mesh Detail**: Higher Cell Size = faster baking, less precise. 0.25 is good default
- **Multiple Enemies**: The system handles multiple enemies well, they'll all use the same navigation mesh

## Testing Checklist

✅ NavigationRegion3D added
✅ Floor and walls moved inside NavigationRegion3D  
✅ Navigation mesh baked (blue overlay visible)
✅ Enemy prefab added at root level
✅ Enemy positioned on the floor (Y = 0 or floor level)
✅ Player is in "player" group
✅ Scene runs without errors
✅ Enemy chases player
✅ Enemy paths around obstacles

## Need More Help?

See `ENEMY_SETUP_README.md` for detailed information about:
- Enemy configuration options
- How the system works internally
- Troubleshooting specific issues
- Advanced customization

Try running `EnemyTestScene.tscn` first to see a working example!

