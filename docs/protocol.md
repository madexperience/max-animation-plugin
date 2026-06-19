# Studio to DCC Protocol

The first Max port should remain compatible with the existing Blender addon API. This keeps Roblox Studio plugin changes small and lets the Max server become a drop-in local endpoint.

Default host:

```text
http://127.0.0.1:31337
```

## Endpoints

### `GET /list_armatures`

Returns rig or armature names available in the DCC scene.

Response:

```json
{
  "success": true,
  "armatures": [
    {
      "name": "RigName",
      "num_bones": 15,
      "has_animation": true,
      "frame_range": [0, 60],
      "fps": 30
    }
  ]
}
```

### `GET /get_bone_rest/{armature}`

Returns rest-pose calibration data for a selected rig. The exact payload must match what the Studio plugin expects when importing animation data.

Temporary response shape:

```json
{
  "success": true,
  "armature": "RigName",
  "bones": {}
}
```

### `GET /export_animation/{armature}`

Exports the active animation from Max to Studio. The existing Blender addon returns an octet-stream payload that Studio decodes into Roblox animation data.

The Max bridge currently returns uncompressed JSON bytes with content type `application/octet-stream`. The Studio deserializer accepts this through its binary JSON fallback.

Response content type:

```text
application/octet-stream
```

### `POST /export_animation/{armature}`

Same as `GET /export_animation/{armature}`, but accepts target bone rest calibration from Studio.

Request:

```json
{
  "target_bone_rest": {}
}
```

### `POST /import_animation`

Imports Studio animation data into the DCC scene. The request body may be raw JSON, zlib data, or gzip-wrapped zlib data depending on the Studio exporter path.

Query parameters:

```text
?armature=RigName
```

Response:

```json
{
  "success": true
}
```

### `GET /animation_status`

Used by live sync polling. The Max port can initially return no changes until live sync is implemented.

Response:

```json
{
  "success": true,
  "changed": false
}
```

## Compatibility Rule

Do not rename endpoints during the first port. UI labels can say "Max", but the transport layer should remain compatible until import/export works end to end.
