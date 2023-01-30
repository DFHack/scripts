armoks-blessing
===============

.. dfhack-tool::
    :summary: Bless units with superior stats and traits.
    :tags: fort armok units

Runs the equivalent of `rejuvenate`, `elevate-physical`, `elevate-mental`, and
`brainwash` on all dwarves currently on the map. This is an extreme change,
which sets every stat and trait to an ideal easy-to-satisfy preference.

Usage
-----

``armoks-blessing``
    Adjust stats and personalities to an ideal for all dwarves. No skills will
    be modified.
``armoks-blessing all``
    In addition to the stat and personality adjustments, set all skills for all
    dwarves to legendary.
``armoks-blessing list``
    Prints list of all skills.
``armoks-blessing classes``
    Prints list of all skill classes (i.e. named groups of skills).
``armoks-blessing <skill name>``
    Set a specific skill for all dwarves to legendary.
``armoks-blessing <class name>``
    Set a specific class (group of skills) for all dwarves to legendary.

Examples
--------

``armoks-blessing Medical``
    All dwarves will have all medical related skills set to legendary.
``armoks-blessing RANGED_COMBAT``
    All dwarves become legendary archers.
