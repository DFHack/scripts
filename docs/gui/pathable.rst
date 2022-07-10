
gui/pathable
============

Highlights each visible map tile to indicate whether it is possible to path to
from the tile at the cursor - green if possible, red if not, similar to
`gui/siege-engine`. A few options are available:

* :kbd:`l`: Lock cursor: when enabled, the movement keys move around the map
  instead of moving the cursor. This is useful to check whether parts of the map
  far away from the cursor can be pathed to from the cursor.
* :kbd:`d`: Draw: allows temporarily disabling the highlighting entirely.
* :kbd:`u`: Skip unrevealed: when enabled, unrevealed tiles will not be
  highlighed at all. (These would otherwise be highlighted in red.)

.. note::
    This tool uses a cache used by DF, which currently does *not* account for
    climbing. If an area of the map is only accessible by climbing, this tool
    may report it as inaccessible. Care should be taken when digging into the
    upper levels of caverns, for example.

