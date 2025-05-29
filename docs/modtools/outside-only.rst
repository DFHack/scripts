modtools/outside-only
=====================

.. dfhack-tool::
    :summary: Set building inside/outside restrictions.
    :tags: unavailable

This allows you to specify certain custom buildings as outside only, or inside
only. If the player attempts to build a building in an inappropriate location,
the building will be destroyed.

Arguments::

    -clear
        clears the list of registered buildings
    -checkEvery n
        set how often existing buildings are checked for whether they
        are in the appropriate location to n ticks
    -type [EITHER, OUTSIDE_ONLY, INSIDE_ONLY]
        specify what sort of restriction to put on the building
    -building name
        specify the id of the building
