fix/engravings
==============

.. dfhack-tool::
    :summary: Fixes unengravable corrupted tiles so they are able to be engraved.
    :tags: fort bugfix

When constructing a new wall or new floor over a previously engraved tile, the tile may become corrupted and unengravable.
This fix detects the problem and resets the state of those tiles so they may be engraved again.

Usage
-----

::

    fix/engravings [<options>]

Options
-------

``-q``, ``--quiet``
    Only output status when something was actually fixed.
