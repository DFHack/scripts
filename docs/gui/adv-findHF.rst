gui/adv-findHF
===========

.. dfhack-tool::
    :summary: Find and track down historical figures.
    :tags: adventure inspection units

Allows you to search for all :wiki:`Historical Figure <Historical_figure>` in the current world, which includes every creature with a name.
Your coordinates, as well as the selected historical figures, are kept up to date as you or your target moves.
Note that it might be impossible to find dead historical figures or those that are not in the physical realm.
There are three types of coordinates, and the relevant ones will be displayed on the UI, depending on the situation:

==========  ==========
Coord Type  Meaning
==========  ==========
Local       Relative coordinates, when you are in a site
Global      The smallest step when traveling the world.
Region      World map region - the coordinate system you see in worldgen, and when pressing m while traveling. Corresponding to 48 global.
==========  ==========


Usage
-----

::

    gui/adv-findHF
