necronomicon
============

.. dfhack-tool::
    :summary: Find books that contain the secrets of life and death.
    :tags: fort inspection items

Lists all books in the fortress that contain the secrets to life and death.
To find the books in fortress mode, go to the Written content submenu in
Objects (O). Slabs are not shown by default since dwarves cannot read secrets
from a slab in fort mode.

Usage
-----

::

    necronomicon [<options>]

Options
-------

``-s``, ``--include-slabs``
    Also list slabs that contain the secrets of life and death. Note that
    dwarves cannot read the secrets from a slab in fort mode.
