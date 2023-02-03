all-unmet-needs
===============

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
    ``all-unmet-needs``
    ``all-unmet-needs [<options>]``

::

    all-unmet-needs

Examples
--------
``all-unmet-needs``
    Show the cumulative needs of all citizens.

``all-unmet-needs n``
    it adds a TAG NDS TAGS to citizens prefix names

``all-unmet-needs r``
    it removes all NDS TAGS citizens prefix names

``all-unmet-needs u``
    it update all NDS TAGS citizens prefix names

Options
--------
``n``, ``add-nicknames``
    it adds a TAG NDS TAGS to citizens prefix names

``r``, ``remove-nicknames``
    it removes all NDS TAGS citizens prefix names

``u``, ``update-nicknames``
    it update all NDS TAGS citizens prefix names
