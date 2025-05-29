gui/sandbox
===========

.. dfhack-tool::
    :summary: Create units, trees, or items.
    :tags: adventure fort armok animals items map plants units

This tool provides a spawning interface for units, trees, and/or items. Units
can be created with arbitrary skillsets, and trees can be created either as
saplings or as fully grown (depending on the age you set). The item creation
interface is the same as `gui/create-item`.

You can choose whether spawned units are:

- hostile (default)
- hostile undead
- independent/wild
- friendly
- citizens/pets (only available when launching from fort mode)

Note that if you create new citizens and you're not using `autolabor`, you'll
have to got into the labors screen and make at least one change (any change) to
get DF to assign them labors. Otherwise they'll stand around with "No job".

Usage
-----

::

    gui/sandbox

Caveats
-------

If running from adventure mode, the map will show fort-mode "dig" markers on
tiles that were within the code of vision of your adventurers. This is visually
distracting, but it is not an error and can be ignored.

When spawning undead, you'll need to save and reload before they gain their
distinctive purple cast.
