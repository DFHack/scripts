locate-stone
============

.. dfhack-tool::
    :summary: Finds stone and ore mineral events on the map.
    :tags: fort armok inspection productivity 

Fork of `locate-ore` to also include stone and fuel sources.
This tool scans the map for stone and ore mineral events. With no arguments, or with
``list``, prints a list of  stone and ore types with tile
counts. 

With a stone or ore or metal argument, selects a random matching undesignated wall tile, 
centers the camera on it, and designates it for digging.

If you want to dig **all** tiles of that kind of ore, highlight that tile with the
keyboard cursor and run `digtype <dig>`.

By default, the tool only searches ore veins that your dwarves have discovered.

Note that looking for a particular metal might find an ore that contains that
metal along with other metals. For example, locating silver may find
tetrahedrite, which contains silver and copper.

``locate-stone`` only scans mineral events, so it is quick but does not find
ordinary layer-stone walls like flux stones.

Usage
-----

``locate-stone``
    List discovered visible stone and ore mineral events.

``locate-stone <type> [<options>] ``
    Select a random matching undesignated wall tile and designate it for digging.

Examples
--------

``locate-stone -all``
    List all mineral events on the map, including those that have not been discovered.

``locate-stone iron``
    Find and designate a visible tile of any ore that produces iron.

``locate-stone magnetite``
    Find and designate a visible magnetite tile.

``locate-stone coal``
    Find and designate a visible bituminous coal or lignite tile.

``locate-stone -a lignite``
    Include undiscovered/unrevealed mineral events when searching for lignite.

Options
-------

``-a``, ``--all``
    Include undiscovered/unrevealed mineral events.

Aliases
-------

``coal``, ``coke``, and ``fuel`` match both ``coal_bituminous`` and ``lignite``.
