AutoCeiling
=============

This is a DFHack Lua script for **Dwarf Fortress (Steam version)** that automatically places constructed floors above any dug-out area. It uses a flood-fill algorithm to detect connected dug tiles on the selected Z-level, then creates planned floor constructions directly above them to seal the area. This helps prevent surface collapse and creature intrusion when mining under open ground.

Features
--------

- **Automatic Flood Fill Detection**: Finds all connected dug tiles from the cursor location.
- **Smart Floor Placement**: Builds floors one level above the dug region.
- **Buildingplan Integration**: When the `buildingplan` plugin is active, floors are added as planned constructions and will auto-assign materials.
- **Native DF Construction Support**: Falls back to native designations if `buildingplan` is unavailable.
- **Safety Checks**: Skips tiles that already have player-made constructions or any existing buildings.
- **Parameter Input**: Run `autoceiling t` to enable diagonal flood fill (8-way). Default is 4-way fill.
- **Performance Limit**: Caps flood-fill to a configurable number of tiles (default 4000) for safety.

Usage
-----

1. Move the **game cursor** to a dug-out tile at the level you want to seal the ceiling.
2. In the DFHack console, run:

   ```
   autoceiling
   ```
   or, for diagonal (8-way) flood fill:
   ```
   autoceiling t
   ```

3. The script will automatically:
   - Scan connected walkable tiles at the current Z-level.
   - Attempt to place floor constructions one Z-level above.
   - Report how many tiles were placed and skipped.

4. If the `buildingplan` plugin is active, you’ll see a message confirming planned floor placement. Otherwise, the script will use standard construction designations.

Notes
-----

- Ideal for use after large excavation projects to prevent breaches to the surface.
- Works well in conjunction with the **buildingplan** plugin for automatic material management.
