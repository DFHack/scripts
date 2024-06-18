catsplosion
===========

.. dfhack-tool::
    :summary: Cause pregnancies.
    :tags: fort armok animals

This tool makes cats (or anything else) immediately pregnant. If you value your
fps, it is a good idea to use this tool sparingly. Only adult females of the
chosen race(s) will become pregnant.

Usage
-----

``catsplosion [<id> ...]``
    Makes animals with the given identifiers pregnant. Defaults to ``CAT``.
``catsplosion list``
    List IDs of all animals on the map.

Units will give birth within two in-game hours (100 ticks or fewer).

Examples
--------

``catsplosion``
    Make all cats pregnant.
``catsplosion PIG SHEEP ALPACA``
    Get some quick butcherable meat.
``catsplosion DWARF``
    Have a population boom in your fort.
