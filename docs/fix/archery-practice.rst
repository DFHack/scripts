fix/archery-practice
====================

.. dfhack-tool::
    :summary: Fix quivers and training ammo items to allow archery practice to take place.
    :tags: fort bugfix items

Make quivers the last item in the inventory of every ranged unit currently
training and split stacks of ammo items assigned for training inside the
quivers to ensure each training unit can have more than one stack to allow
archery practice to take place.

Note
----

The bug preventing units from initiating archery practice was fixed in
DF version 53.01. See below for more information about the issue and how
this tool works to mitigate it. Running this tool for any other archery
related issues will not yield useful results.

Usage
-----

``fix/archery-practice``
    Move quivers to the end of units' inventory list and split stacks of
    training ammo items inside the quivers.

``fix/archery-practice -q``, ``fix/archery-practice --quiet``
    Move quivers to the end of units' inventory list and split stacks of
    training ammo items inside the quivers. Do not print to console.

This tool will set quivers as the last item in the inventory of units in
squads that are currently set to train as well as split ammo items inside
their quivers into multiple stacks if a quiver contains only ammo item
with a stack size of 25 or larger assigned for training. The original
training ammo item with a reduced stack size will remain in the quiver
while new ammo items split from it will be placed on the ground where
the unit is located to be picked up later.

Why are archers not practicing archery?
---------------------------------------

Due to a bug in the game, a unit that is scheduled to train will not be
able to practice archery at the archery range when their quiver contains
only one stack of ammo item assigned for training. This is sometimes
indicated on the unit by the 'Soldier (no item)' status.

During versions 52.03 and 52.04, the issue was the complete reverse;
units would not practice when their quivers contained more than one
stack of ammo items assigned for training.

Another issue in 52.05 is that units will not practice archery if their
quiver is not the last item in their inventory.

This tool provides an interim remedy by moving quivers to the end of
every training unit's inventory list and splitting stacks of ammo items
inside their quivers to prompt the game to give them multiple stacks
of training ammo items.

Limitations
-----------

The game has a tendency to reshuffle the squad's ammo/unit pairings if
the newly split ammo items are force paired to the units holding the
original ammo item. As a compromise, the new items are placed on the
ground instead and added to the squad's training ammo assignment pool,
so that the game can distribute the items normally without causing the
pairing for ammo items already in quivers to be reshuffled.

Although this tool would allow units to practice archery, the activity
will still be aborted once they have only one stack of training ammo
item remaining in their quivers. Practicing units will gain skill from
practice, but not the positive thought they would have gained from
having completed the activity. Once the game assigns more training
ammo items to them, they can continue practicing archery.
