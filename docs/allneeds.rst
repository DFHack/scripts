allneeds
========

.. dfhack-tool::
    :summary: Show the cumulative needs of all citizens.
    :tags: fort units

Provides an overview of the needs of the fort in general, output is sorted to
show most unfullfiled needs.
show only needs that needs attention now (damaging focus) and garantee it shows on dwarf overview
(obs: multiple Prays counts as unique Pray need)

NEEDS_CODE is usually capital letters from each need, NDS TAGS stands for NDS_ NEEDS_CODE _NDS in dwarf names

Usage
-----
    ``allneeds``
    ``allneeds n``
    ``allneeds r``
    ``allneeds u``

::

    allneeds

Examples
--------
``allneeds``
    Show the cumulative needs of all citizens.

``allneeds n``
    it adds a TAG NDS TAGS to citizens prefix names

``allneeds r``
    it removes all NDS TAGS citizens prefix names

``allneeds u``
    it update all NDS TAGS citizens prefix names
