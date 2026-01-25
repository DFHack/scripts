Select Lock Overlay
===================

This is a DFHack overlay plugin for Dwarf Fortress (`SelectLockLabors`) that simulates the selection and locking of multiple units within the **Work Details** screen. It provides a simple UI interface to batch-toggle units' labor assignments, either by selecting, locking, or both.

Features
--------

- **Overlay Interface**: Integrated directly into the `LABOR/WORK_DETAILS` viewscreen.
- **Action Modes**: Choose between `Select only`, `Lock only`, or `Select + Lock`.
- **Batch Processing**: Specify how many entries to affect and apply actions with one click.
- **Non-Intrusive**: Uses DFHack GUI input simulation to trigger existing functionality.

Usage
-----

Once the plugin is loaded and you're in the `Work Details` screen (e.g., `y` -> `Work Details`), the overlay will automatically appear.

1. Use the **Mode** dropdown to select what action(s) to simulate:
   - `Select only`: Just toggles unit selection.
   - `Lock only`: Just toggles the lock status.
   - `Select + Lock`: Toggles both selection and lock.

2. Adjust the number of entries to apply actions to (default is 7).

3. Press the **RUN** button (or the hotkey defined for it) to execute the actions.
