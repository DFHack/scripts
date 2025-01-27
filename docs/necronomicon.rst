necronomicon
============

.. dfhack-tool::
    :summary: Find books that contain the secrets of life and death.
    :tags: fort inspection items

Lists all books in the fortress (or world) that contain the secrets to life and
death. To zoom to the books in fortress mode, go to the ``Artifacts`` tab in
`gui/sitemap` and click on their names. Slabs are not listed by default since
dwarves cannot read secrets from a slab in fort mode.

Usage
-----

::

    necronomicon [<options>]

Options
-------

``-s``, ``--include-slabs``
    Also list slabs that contain the secrets of life and death. Note that
    dwarves cannot read the secrets from a slab in fort mode.

``-w``, ``--world``
    Lists ALL secret-containing items across the entire world, not just your
    fortress.
