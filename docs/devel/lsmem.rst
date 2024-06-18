devel/lsmem
===========

.. dfhack-tool::
    :summary: Print memory ranges of the DF process.
    :tags: dev

Useful for checking whether a pointer is valid, whether a certain library/plugin
is loaded, etc.

Usage
-----

::

    devel/lsmem [<address> ...] [<name|pattern> ...]

Examples
--------

``devel/lsmem 0x1234 5678 90ab``
    List any ranges containing the addresses ``0x1234``, ``0x5678``, or ``0x90ab``.
    Addresses are interpreted as hex; the ``0x`` prefix is optional.

``devel/lsmem dwarf g_src``
    List any ranges corresponding to files matching ``dwarf`` or ``g_src``
    (case-insensitive).

``devel/lsmem .+``
    List any ranges with non-empty filenames. Any Lua patterns are allowed.
