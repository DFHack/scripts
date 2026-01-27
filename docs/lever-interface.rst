Lever Interface
===============

Overview
--------
The lever interface provides a consolidated list of all levers in the current map
and lets you queue or remove pull tasks. The list is kept up to date automatically
so queued, completed, and cancelled pulls are reflected without manual refreshes.

Main features
-------------
- Lists all levers with a status prefix (``[Pulled]`` or ``[Not Pulled]``).
- Shows queued pull counts per lever and a global queued pull total.
- Allows queuing a pull task for the selected lever.
- Allows removing queued pull tasks from the selected lever.
- Supports hover focus to pan the map to the lever without clicking.
- Supports search filtering by lever name.

Using the interface
-------------------
- **Search**: Type in the search field to filter levers by name. Filtering is
  case-insensitive and matches substrings.
- **Hover**: Move the mouse over a lever entry to pan and highlight the lever.
- **Click**: Click a lever entry (or press Enter) to queue a pull task.
- **Remove queued pulls**: Use the remove hotkey to clear queued pull jobs for
  the selected lever.

Hotkeys
-------
- ``P``: Queue a pull task for the selected lever.
- ``X``: Remove queued pull tasks from the selected lever.
- ``R``: Refresh the list.
