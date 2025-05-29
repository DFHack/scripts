undump-buildings
================

.. dfhack-tool::
    :summary: Undesignate building base materials for dumping.
    :tags: fort productivity buildings

If you designate a bunch of tiles in dump mode, all the items on those tiles
will be marked for dumping. Unfortunately, if there are buildings on any of
those tiles, the items that were used to *build* those buildings will also be
uselessly and confusingly marked for dumping.

This tool will scan for buildings that have their construction materials marked
for dumping and will unmark them.

Usage
-----

::

    undump-buildings
