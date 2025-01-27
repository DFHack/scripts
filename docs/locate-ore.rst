locate-ore
==========

.. dfhack-tool::
    :summary: Scan the map for metal ores.
    :tags: fort armok productivity map

This tool finds and designates for digging one tile of a specific metal ore. If
you want to dig **all** tiles of that kind of ore, highlight that tile with the
keyboard cursor and run `digtype <dig>`.

By default, the tool only searches ore veins that your dwarves have discovered.

Note that looking for a particular metal might find an ore that contains that
metal along with other metals. For example, locating silver may find
tetrahedrite, which contains silver and copper.

Usage
-----

``locate-ore [list] [<options>]``
    List metal ores available on the map.
``locate-ore <type> [<options>]``
    Finds a tile of the specified ore type, zooms the screen so that tile is
    visible, and designates that tile for digging.

Options
-------

``-a``, ``--all``
    Also search undiscovered ore veins.

Examples
--------

``locate-ore``
    List discovered

::

    locate-ore hematite
    locate-ore iron
    locate-ore silver --all
