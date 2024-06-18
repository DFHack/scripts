devel/tile-browser
==================

.. dfhack-tool::
    :summary: Browse graphical tile textures by their texpos values.
    :tags: dev

This script pops up a panel that shows a page of 1000 textures. You can change
the starting texpos index with :kbd:`Ctrl`:kbd:`A` or scan forward or backwards
in increments of 1000 with :kbd:`Shift` :kbd:`Up`/:kbd:`Down`.

Textures are resized to the dimensions of the interface grid (8px by 12px), so
map textures (nominally 32px by 32px) will be squished. If no texture is
assigned to the texpos index, the window will be transparent at that spot.

Usage
-----

::

    devel/tile-browser
