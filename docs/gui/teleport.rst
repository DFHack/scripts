gui/teleport
============

.. dfhack-tool::
    :summary: Teleport units anywhere.
    :tags: fort armok units

This tool allows you to interactively select units to teleport by drawing boxes
around them on the map. Double clicking on a destination tile will teleport the selected units there.

If a unit is already selected in the UI when you run `gui/teleport`, it will be
pre-selected for teleport.

Note that you *can* select enemies that are lying in ambush and are not visible
on the map yet, so you if you select an area and see a marker that indicates
that a unit is selected, but you don't see the unit itself, this is likely what
it is. You can stil teleport these units while they are hidden.

Usage
-----

::

    gui/teleport
