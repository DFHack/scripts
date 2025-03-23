gui/mass-remove
===============

.. dfhack-tool::
    :summary: Mass select things to remove.
    :tags: fort design productivity buildings stockpiles

This tool lets you remove buildings, constructions, stockpiles, and/or zones
using a mouse-driven box selection. You can choose which you want to remove
with the given filters, then box select to apply to the map.

Planned buildings, constructions, stockpiles, and zones will be removed
immediately. Built buildings and constructions will be designated for
deconstruction.

Usage
-----

::

    gui/mass-remove

Overlay
-------

This tool also provides one overlay that is managed by the `overlay`
framework.

massremovetoolbar
~~~~~~~~~~~~~~~~~

The ``mass-remove.massremovetoolbar`` overlay adds a button to the toolbar at the bottom of the
screen when eraser mode is active. It allows you to conveniently open the ``gui/mass-remove``
interface.
