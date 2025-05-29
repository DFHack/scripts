gui/biomes
==========

.. dfhack-tool::
    :summary: Visualize and inspect biome regions on the map.
    :tags: fort inspection map

This script shows the boundaries of the biome regions on the map.
Hover over a biome entry in the list to get detailed info about it.

Note that up in mid-air, there may be additional biomes inherited from
neighboring embark squares due to DF :bug:`8781`. This does not usually affect
the player unless:

- You build up into the sky, cast obsidian to make natural flooring, muddy it,
  and designate a farm plot
- The inherited sky biome is evil and has an effect on fliers that happen to
  enter its space (e.g. avian wildlife can unexpectedly get zombified or drop
  dead from syndromes)

Usage
-----

::

    gui/biomes
