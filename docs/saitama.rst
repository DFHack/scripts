saitama
=======

.. dfhack-tool::
    :summary: Multiply the attribute potential of units.
    :tags: fort armok units

Multiplies the potential (max_value) of every mental and physical attribute
for the selected unit, all citizens, all map creatures, or an entire squad.
The current attribute values are left unchanged -- units must still train to
reach their new potential.

Usage
-----

``saitama <multiplier>``
    Multiply the attribute potential of the selected unit.
``saitama --citizens <multiplier>``
    Multiply the attribute potential of all fort citizens.
``saitama --all <multiplier>``
    Multiply the attribute potential of every creature on the map.
``saitama --squad <number> <multiplier>``
    Multiply the attribute potential of every member in the given squad.
    Squad numbers start at 1. Use ``saitama --listsquads`` to see them.
``saitama --unit <id> <multiplier>``
    Multiply the attribute potential of the unit with the given ID.
``saitama --listsquads``
    List all squads and their numbers.

Examples
--------

``saitama 100``
    The selected unit's max attributes become 100x their current potential.
``saitama --citizens 10``
    All citizens get 10x attribute potential.
``saitama --squad 1 50``
    First squad members get 50x attribute potential.
