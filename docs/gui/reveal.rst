gui/reveal
==========

.. dfhack-tool::
    :summary: Reveal map tiles.
    :tags: fort armok map

This script provides a means for you to safely glimpse at unexplored areas of
the map, such as the caverns, so you can plan your fort with full knowledge of
the terrain. When you open `gui/reveal`, the map will be revealed. You can see
where the caverns are, and you can designate what you want for digging. When
you close `gui/reveal`, the map will automatically be unrevealed so you can
continue normal gameplay. If you want the reveal to be permanent, you can
toggle the setting before you close `gui/reveal`.

Usage
-----

::

    gui/reveal [hell]

Examples
--------

``gui/reveal``
    Reveal all "normal" terrain, but keep areas with late-game surprises hidden.
``gui/reveal hell``
    Fully reveal adamantine spires, gemstone pillars, and the underworld. The
    game cannot be unpaused with these features revealed, so the choice to keep
    the map unrevealed when you close `gui/reveal` is disabled when this option
    is specified.
