gui/reveal
==========

.. dfhack-tool::
    :summary: Reveal map tiles.
    :tags: adventure fort armok map

This script provides a means for you to safely glimpse at unexplored areas of
the map, such as aquifers or the caverns, so you can plan your fort with full
knowledge of the terrain. When you open `gui/reveal`, the map will be revealed.
You can see where the caverns are, and you can designate what you want for
digging. When you close `gui/reveal`, the map will automatically be unrevealed
so you can continue normal gameplay. If you want the reveal to be permanent,
you can toggle the setting before you close `gui/reveal`.

You can choose to only reveal the aquifers and not other tiles by toggling the
settings in the UI or by specifying the appropriate commandline parameter when
starting `gui/reveal`.

Areas with event triggers, such as gem boxes and adamantine spires, are not
revealed by default. This allows you to choose to keep the map unrevealed when
you close the `gui/reveal` UI without being immediately inundated with
thousands of event message popups.

In graphics mode, solid tiles that are not adjacent to open space will not be
rendered, but they can still be examined by hovering over them with the mouse.
Switching to ASCII mode (in the game settings) will allow the display of the
revealed tiles, allowing you to quickly determine where the ores and gem
clusters are.

Usage
-----

::

    gui/reveal [hell] [<options>]

Pass the ``hell`` keyword to fully reveal adamantine spires, gemstone pillars,
and the underworld. The game cannot be unpaused with these features revealed,
so the choice to keep the map unrevealed when you close `gui/reveal` is
disabled when this option is specified.

Examples
--------

``gui/reveal``
    Reveal all "normal" terrain, but keep areas with late-game surprises hidden.
``gui/reveal hell``
    Fully reveal adamantine spires, gemstone pillars, and the underworld. The
    game cannot be unpaused with these features revealed, so the choice to keep
    the map unrevealed when you close `gui/reveal` is disabled when this option
    is specified.

Options
-------

``-o``, ``--aquifers-only``
    Don't reveal any map tiles, but continue to display markers to identify
    aquifers and damp tiles as per the `dig.warmdamp <dig>` overlay.
