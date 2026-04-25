gui/harvest
============

.. dfhack-tool::
    :summary: Instantly harvest plants, shrubs, and crops in a selected area.
    :tags: fort armok plants

Opens a GUI window that lets you box-select an area of the map and
instantly harvest all shrubs, mature farm crops, and fallen fruit or
plant items within it.

Harvested goods are automatically placed into the nearest available
barrel or bag, or dropped on the ground if no container is free. You
can also double-click a specific container to use it.

Yield quantities are based on the best grower and herbalist skill
levels in your fortress, or you can toggle forced maximum yields.

Usage
-----

::

    gui/harvest

Click and drag on the map to select harvestable plants. Double-click
on the ground (or on a container) to execute the harvest.

In-window controls
------------------

``Ctrl-a``
    Select all harvestable tiles on the current z-level.
``Ctrl-c``
    Clear the current selection.
``Ctrl-m``
    Toggle between simulating your best dwarf's skill level and
    forcing maximum yields.
``Ctrl-s``
    Toggle whether saplings are included in the harvest.
