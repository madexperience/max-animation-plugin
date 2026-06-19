# Roadmap

## Phase 1: Connection Skeleton

- Start a localhost HTTP server inside 3ds Max.
- Respond to `/list_armatures`.
- Update Studio plugin labels from Blender to Max.
- Verify Studio can connect to Max.
- Package animator-friendly `.rbxm` and Max companion `.zip` artifacts.

## Phase 2: Rig Export

- Export selected Roblox rig metadata from Studio.
- Rebuild a matching bone hierarchy in 3ds Max.
- Preserve Motor6D names and rest transforms.

## Phase 3: Animation Import to Studio

- Read sampled Max transforms from a selected rig. (MVP complete)
- Convert transforms to Roblox pose data. (MVP complete)
- Create or update a Roblox `KeyframeSequence`. (MVP complete via Studio importer)
- Validate axis and unit presets on real Biped/CAT/custom rigs.

## Phase 4: Animation Export to Max

- Serialize Roblox `KeyframeSequence` data. (MVP already handled by Studio plugin)
- Apply animation keys to the corresponding Max rig. (MVP complete)
- Improve key tangent/easing preservation.

## Phase 5: Feature Parity

- Live Sync
- Weapon/accessory export
- Marker/event transfer
- Animation simplifier
- Camera controls
