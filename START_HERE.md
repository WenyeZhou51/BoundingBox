# 🎮 Enemy AI - START HERE!

## Quick Test (5 Minutes)

### 1. Open the Test Scene
In Godot editor, open: `EnemyTestScene.tscn`

### 2. Bake Navigation
- In Scene tree (left), click on **NavigationRegion3D**
- In Inspector (right), scroll down
- Find and click **"Bake NavMesh"** button
- You should see blue overlay on the floor

### 3. Run It!
- Press **F6** (or click Play Scene button)
- Move with **WASD**
- Watch the red enemy chase you around obstacles!
- Press **F** to toggle vision mode

**That's it!** The enemy is working! 🎉

---

## What You Get

✅ **Enemy AI Script** (`EnemyPrefab.gd`)
- Chases player using pathfinding
- Avoids obstacles automatically
- Horizontal movement only (X, Z)
- Configurable speed & detection range

✅ **Enemy Prefab** (`EnemyPrefab.tscn`)
- Red capsule character (easy to spot)
- Drag-and-drop into any scene
- Works immediately after baking nav mesh

✅ **Test Scenes**
- `EnemyTestScene.tscn` - Simple test with obstacles
- `KitchenSceneWithEnemy.tscn` - Real scene example

✅ **Complete Documentation**
- `ENEMY_AI_SUMMARY.md` - Overview of everything
- `ENEMY_SETUP_README.md` - Detailed setup & config
- `CONVERT_SCENE_TO_NAVIGATION.md` - Add to your scenes

---

## Add Enemy to Your Scenes

**3 Simple Steps:**

1. **Add NavigationRegion3D**
   - Right-click root → Add Child → NavigationRegion3D

2. **Move Floor & Walls Into It**
   - Drag Floor and Wall nodes into NavigationRegion3D
   - This tells the system where enemy can walk

3. **Bake & Add Enemy**
   - Select NavigationRegion3D → Click "Bake NavMesh"
   - Drag `EnemyPrefab.tscn` into scene
   - Done!

**Detailed Guide:** See `CONVERT_SCENE_TO_NAVIGATION.md`

---

## Configuration

Select enemy in scene, adjust in Inspector:

| Setting | Default | What It Does |
|---------|---------|--------------|
| Move Speed | 3.0 | Enemy speed (player is 5.0) |
| Detection Range | 100.0 | Chase distance |
| Path Update Interval | 0.5 | How often to recalculate path |

---

## Files Created

```
📁 Your Project
├─ 🤖 EnemyPrefab.gd          # Enemy AI script
├─ 🎬 EnemyPrefab.tscn        # Enemy prefab (drag into scenes)
├─ 🎮 EnemyTestScene.tscn     # Quick test scene
├─ 🏠 KitchenSceneWithEnemy.tscn  # Example integration
├─ 📖 START_HERE.md           # This file
├─ 📘 ENEMY_AI_SUMMARY.md     # Complete overview
├─ 📗 ENEMY_SETUP_README.md   # Detailed setup guide
├─ 📙 CONVERT_SCENE_TO_NAVIGATION.md  # Scene conversion
└─ 🔧 EnemyWithVision.gd      # Optional: Vision system integration
```

---

## Troubleshooting

### Enemy doesn't move?
→ Did you click "Bake NavMesh"? (Most common issue!)

### Enemy walks through walls?
→ Move walls into NavigationRegion3D, then rebake

### Can't find player?
→ Make sure player CharacterBody3D is in "player" group

**More help:** See `ENEMY_SETUP_README.md` troubleshooting section

---

## Next Steps

1. ✅ **Test it** - Run `EnemyTestScene.tscn` (you've done this!)
2. 📚 **Read docs** - Check `ENEMY_AI_SUMMARY.md` for overview
3. 🏗️ **Add to your game** - Follow `CONVERT_SCENE_TO_NAVIGATION.md`
4. 🎨 **Customize** - Adjust speed, color, behavior
5. 🚀 **Expand** - Add multiple enemies, patrol routes, attacks, etc.

---

## That's It!

You have a **fully functional enemy AI system** with:
- ✅ Pathfinding around obstacles
- ✅ Player chasing behavior
- ✅ Horizontal-only movement
- ✅ Easy configuration
- ✅ Complete documentation

**Enjoy!** 🎉

---

**Need help?** All answers are in the documentation files!

