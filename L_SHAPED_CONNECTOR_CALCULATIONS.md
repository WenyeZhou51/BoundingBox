# L-Shaped Storage Connector - Detailed Calculations

## Room Analysis

### Lab Room (LabRoomScene.tscn)
**Floor Dimensions:**
- Size: Vector3(10, 0.1, 10)
- Local bounds: X[-5 to +5], Z[-5 to +5]

**East Door (SideDoor):**
- Local position: (5, 0, 0)
- Rotation: (0, 0, -1, 0, 1, 0, 1, 0, 0) = faces EAST
- Transform in TestScene: (-30.1874, -0.141889, -1.11275)

**Lab's East Door in World Space:**
```
Lab world + Door local = Door world
(-30.1874, -0.141889, -1.11275) + (5, 0, 0) = (-25.1874, -0.141889, -1.11275)
```

### Freezer Room (FreezerScene.tscn)
**Floor Dimensions:**
- Size: Vector3(12, 0.1, 10)
- Local bounds: X[-6 to +6], Z[-5 to +5]

**West Door (LockedFromOtherSideDoor):**
- Local position: (-6, 0, 0)
- Rotation: (0, 0, 1, 0, 1, 0, -1, 0, 0) = faces WEST

## L-Shaped Connector Design

### Segment 1 (East-West Corridor)
- **Dimensions**: 10 units (X) × 4 units (Z)
- **Floor center**: (5, 0, 0)
- **Floor bounds**: X[0 to 10], Z[-2 to +2]
- **Purpose**: Connect Lab to turn point

### Segment 2 (North-South Corridor)
- **Dimensions**: 4 units (X) × 10 units (Z)
- **Floor center**: (10, 0, 7)
- **Floor bounds**: X[8 to 12], Z[2 to 12]
- **Purpose**: Connect turn point to Freezer

### Door Positions (Local to Connector)
- **West entrance**: (0, 0, 0) - from Lab
- **East exit**: (12, 0, 10) - to Freezer

### Wall Structure
**Segment 1 Walls:**
- North wall at Z = -2.1 (length 10)
- South wall at Z = +2.1 (length 10)
- West wall at X = 0 (with door opening)

**Segment 2 Walls:**
- North wall at Z = 12.1 (length 10)
- West wall at X = 7.9 (length 10)
- East wall at X = 12.1 (with door at Z=10)
- Corner wall at X = 10.1, spans Z[2 to 10] (length 8)

## Position Calculations

### Step 1: Place Connector to Align with Lab's East Door
**Requirement:** Connector's west door must be at Lab's east door world position

```
Connector world position = Lab door world - Connector west door local
= (-25.1874, -0.141889, -1.11275) - (0, 0, 0)
= (-25.1874, -0.141889, -1.11275)
```

### Step 2: Calculate Connector's East Door World Position
```
Connector east door world = Connector world + East door local
= (-25.1874, -0.141889, -1.11275) + (12, 0, 10)
= (-13.1874, -0.141889, 8.88725)
```

Wait, I made an error in my connector design. The east door should be at (12, 0, 10), not (10, 0, 10).

Let me recalculate:
- Segment 1 goes from X=0 to X=10
- Segment 2 goes from X=8 to X=12
- The east door on segment 2 should be at X=12, Z=10

So east door local = (12, 0, 10)

Connector east door world = (-25.1874, -0.141889, -1.11275) + (12, 0, 10)
= (-13.1874, -0.141889, 8.88725)

### Step 3: Calculate Freezer Position
**Requirement:** Freezer's west door must be at Connector's east door

```
Freezer world position = Connector east door world - Freezer west door local
= (-13.1874, -0.141889, 8.88725) - (-6, 0, 0)
= (-13.1874 + 6, -0.141889, 8.88725)
= (-7.1874, -0.141889, 8.88725)
```

## Path Verification

### Player Journey:
1. **Lab center**: (-30.1874, -0.141889, -1.11275)
2. **Lab east door** (exit): **(-25.1874, -0.141889, -1.11275)**
   
3. **Connector west door** (entrance): **(-25.1874, -0.141889, -1.11275)** ✅ MATCH
4. Walk EAST through 10-unit corridor (Segment 1)
5. Reach turn point at world (-15.1874, -0.141889, -1.11275)
6. Turn SOUTH into Segment 2
7. Walk SOUTH through 10-unit corridor
8. **Connector east door** (exit): **(-13.1874, -0.141889, 8.88725)**

9. **Freezer west door** (entrance): **(-13.1874, -0.141889, 8.88725)** ✅ MATCH
10. **Freezer center**: (-7.1874, -0.141889, 8.88725)

### Distance Verification:
- Lab to Connector: 0 units (doors aligned)
- Through Connector Segment 1: 10 units EAST
- Through Connector Segment 2: 10 units SOUTH
- Connector to Freezer: 0 units (doors aligned)
- Total path: 20 units

### Floor Height:
All rooms at Y = -0.141889 (same level) ✅

## Storage Items

### Box Stacks (using FrozenBoxPrefab):
1. **BoxStack1** at (2, 0, -0.5): 3 boxes + **Debris (conf 0.4)** + **Watch (conf 0.9)**
2. **BoxStack2** at (7, 0, 0.5): 2 boxes
3. **BoxStack3** at (9, 0, 9): 3 boxes
4. **BoxStack4** at (11, 0, 4): 2 boxes

### Corner Debris (8 pieces):
Scattered in corners and along walls for environmental clutter

