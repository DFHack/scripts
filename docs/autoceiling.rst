autoceiling
===========

.. dfhack-tool::
    :summary: Place floors above dug areas to seal surface openings.
    :tags: construction automation utility

**AutoCeiling** is a DFHack Lua script that automatically places constructed
floors above any dug-out area. It uses a flood-fill algorithm to detect connected
dug tiles on the selected Z-level, then creates planned floor constructions
directly above them to seal the area. This prevents surface collapse and stops
creatures from entering your fortress through unexpected openings. It’s
especially useful when building farms directly below the surface, since those
areas are prone to collapsing without warning and can leave open spaces that
allow surface creatures to breach your fort.

Usage
-----

::

    autoceiling [t] [<max>]

Examples
--------

``autoceiling``
    Run with default settings (4,000 tile flood-fill limit, no diagonal fill).

``autoceiling t``
    Enable diagonal flood-fill connections (8-way fill).

``autoceiling 500``
    Raise or lower flood-fill limits.

``autoceiling t 6000`` or ``autoceiling 6000 t``
    Allow diagonals and increase fill limit to 6,000 tiles.

Options
-------

``t``
    Enables 8-directional (diagonal) flood fill mode.

``<max>``
    Sets the maximum number of tiles the flood fill can cover (default: 4000).

These are the only two options available for this command. Use ``t`` to toggle
diagonal fill and ``<max>`` to control the tile limit for flood fill.
