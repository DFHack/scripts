gui/autodump
============

.. dfhack-tool::
    :summary: Teleport or destroy items.
    :tags: fort armok items

This is a general point and click interface for teleporting or destroying
items. By default, it will teleport items you have marked for dumping, but if
you draw boxes around items on the map, it will act on the selected items
instead. Double-click anywhere on the map to teleport the items there. Be wary
(or excited) that if you teleport the items into an unsupported position
(e.g., mid-air), then they will become projectiles and fall. Items may not be
teleported into walls or hidden tiles.

There are options to include or exclude forbidden items, items that are
currently tagged as being used by an active job, and items dropped by traders.
If trader items are included, the ``trader`` flag will be cleared upon teleport
so the items can be used.

Usage
-----

::

    gui/autodump

Destroying items
----------------

This tool also allows you to destroy the target items instead of teleporting
them. When you click the destroy button (or hit the hotkey), `gui/autodump`
will force-pause the game and enable an "Undo" button, just in case you want
those items back. Once you exit the `gui/autodump` tool, those items will be
unrecoverable.
