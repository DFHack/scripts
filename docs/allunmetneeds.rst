allunmetneeds
========

.. dfhack-tool::
    :summary: Show the cumulative needs of all citizens.
    :tags: fort units

Provides an overview of the needs of the fort in general, output is sorted to
show most unfullfiled needs.
show only needs that needs attention now (damaging focus) and garantee it shows on dwarf overview
(obs: multiple Prays counts as unique Pray need)

needs_code is usually capital letters from each need, nds tags stands for nds needs_code nds in dwarf names

Usage
-----
    ``allunmetneeds``
    ``allunmetneeds [<options>]``

::

    allunmetneeds

Examples
--------
``allunmetneeds``
    Show the cumulative needs of all citizens.

``allunmetneeds n``
    it adds a TAG NDS TAGS to citizens prefix names

``allunmetneeds r``
    it removes all NDS TAGS citizens prefix names

``allunmetneeds u``
    it update all NDS TAGS citizens prefix names

Options
--------
``n``, ``add-nicknames``
    it adds a TAG NDS TAGS to citizens prefix names

``r``, ``remove-nicknames``
    it removes all NDS TAGS citizens prefix names

``u``, ``update-nicknames``
    it update all NDS TAGS citizens prefix names