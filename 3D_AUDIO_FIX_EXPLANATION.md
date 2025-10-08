# 3D Spatial Audio Fix for TV

## The Problem

The player could not hear the TV's 3D spatial audio because the **Camera3D and the TV were in different 3D worlds**.

### Original Structure (BROKEN)
```
TestScene (Node3D)
├── Player
│   └── PlayerUI (Control)
│       └── SubViewportContainer
│           └── SubViewport (separate 3D world)
│               └── FirstPersonController
│                   └── Camera3D ← Audio Listener HERE
├── LivingRoomScene
│   └── TV
│       └── AudioStreamPlayer3D ← Audio Source HERE (different world!)
└── Other scenes...
```

## Why It Didn't Work

1. **SubViewport Creates Isolated World**: The `SubViewport` creates its own separate 3D rendering context
2. **Camera3D in SubViewport**: The Camera3D (which acts as the audio listener) was inside the SubViewport
3. **TV in Main World**: The TV with its AudioStreamPlayer3D was in the main scene tree (TestScene)
4. **No Audio Bridge**: 3D spatial audio cannot work across different viewport boundaries - the audio listener and audio source must be in the same 3D world

## The Solution

### 1. Enabled 3D Audio Listener on SubViewport
**File: `PlayerUI.tscn`**
```gdscript
[node name="SubViewport" type="SubViewport" parent="ViewportFrame/SubViewportContainer"]
handle_input_locally = false
audio_listener_enable_3d = true  ← ADDED THIS
size = Vector2i(979, 550)
render_target_update_mode = 4
```

### 2. Moved All 3D Content Into SubViewport
**File: `TestScene.tscn`**

Moved all 3D scenes from the main TestScene into the SubViewport so they share the same 3D world as the Camera3D:

```
TestScene (Node3D)
└── Player
    └── PlayerUI (Control)
        └── SubViewportContainer
            └── SubViewport ← audio_listener_enable_3d = true
                ├── WorldEnvironment
                ├── FirstPersonController
                │   └── Camera3D ← Audio Listener
                ├── LivingRoomScene
                │   └── TV
                │       └── AudioStreamPlayer3D ← Audio Source (SAME WORLD NOW!)
                ├── HallwayScene
                ├── StudyScene
                ├── StairwellScene
                ├── KitchenScene
                ├── FreezerScene
                ├── NavigationRegion3D
                └── DormHallwayScene
```

## How 3D Audio Works in Godot

1. **AudioListener3D**: In Godot 4, Camera3D nodes automatically act as audio listeners (no separate AudioListener3D node needed)
2. **AudioStreamPlayer3D**: Emits sound in 3D space with distance attenuation and direction
3. **Same World Requirement**: The audio listener (Camera3D) and audio source (AudioStreamPlayer3D) MUST be in the same 3D world/viewport
4. **SubViewport Audio**: When using SubViewports, you must enable `audio_listener_enable_3d = true` to make the Camera3D inside the viewport act as the audio listener for that viewport's 3D world

## TV Audio Settings

The TV's AudioStreamPlayer3D has these settings:
```gdscript
volume_db = -3.0
unit_size = 1.0
max_distance = 10.0
attenuation_model = 1
```

This means:
- **Max Distance**: Player must be within 10 units to hear the TV
- **Attenuation**: Sound gets quieter as player moves away
- **Volume**: -3dB (slightly quieter than default)

## Testing

To verify the fix works:
1. Run the game
2. Navigate to the Living Room
3. Turn on the TV (interact with it)
4. Walk towards and away from the TV
5. You should hear the TV sound getting louder when close and quieter when far
6. The sound should be spatial (left/right balance based on TV position)

## Why This Architecture Exists

The SubViewport design creates a "screen within a screen" effect with the green border frame. This is intentional for the game's visual style. All game content must be rendered inside this viewport to maintain this aesthetic.
