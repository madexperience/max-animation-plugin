# Roadmap

## Phase 1: Connection Skeleton

- Start a localhost HTTP server inside 3ds Max.
- Respond to `/list_armatures`.
- Update Studio plugin labels from Blender to Max.
- Verify Studio can connect to Max.

## Phase 2: Rig Export

- Export selected Roblox rig metadata from Studio.
- Rebuild a matching bone hierarchy in 3ds Max.
- Preserve Motor6D names and rest transforms.

## Phase 3: Animation Import to Studio

- Read Max keyframes from a selected rig.
- Convert transforms to Roblox pose data.
- Create or update a Roblox `KeyframeSequence`.

## Phase 4: Animation Export to Max

- Serialize Roblox `KeyframeSequence` data.
- Apply animation keys to the corresponding Max rig.

## Phase 5: Feature Parity

- Live Sync
- Weapon/accessory export
- Marker/event transfer
- Animation simplifier
- Camera controls
