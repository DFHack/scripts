gui/pathable
============

.. dfhack-tool::
    :summary: Highlights tiles reachable from the cursor or a trade depot.
    :tags: fort inspection map

This tool highlights each visible map tile to indicate whether it is possible to
path to that tile. It has two modes: Follow mouse, which shows which tiles are
pathable from the tile that the mouse cursor is hovering over, and Depot, which
shows which tiles a wagon can traverse on the way to your trade depot.

If graphics are enabled, then tiles show a yellow box if they are pathable and
a red X if not, and the target tiles (the tile under the mouse or the map edge
tiles where wagons can enter the map, depending on which mode you're in) show a
yellow box with a dot in them.

In ASCII mode, the tiles are highlighted in green if pathing is possible and red
if not. Target tiles are highlighted in cyan.

.. note::
    This tool uses a cache used by DF, which currently does *not* account for
    climbing or flying. If an area of the map is only accessible by climbing or
    flying, this tool may report it as inaccessible. For example, this tool
    will not highlight where flying cavern creatures can fly up through holes
    in cavern ceilings.

Usage
-----

::

  gui/pathable
