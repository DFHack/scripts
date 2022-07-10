
exterminate
===========
Kills any unit of a given race.

With no argument, lists the available races and count eligible targets.

With the special argument ``this``, targets only the selected creature.
Alternatively, ``him``, ``her``, ``it``, ``target``, and ``selected``
do the same thing.

With the special argument ``undead``, targets all undeads on the map,
regardless of their race.

When specifying a race, a caste can be specified to further restrict the
targeting. To do that, append and colon and the caste name after the race.

Any non-dead non-caged unit of the specified race gets its ``blood_count``
set to 0, which means immediate death at the next game tick. For creatures
such as vampires, it also sets animal.vanish_countdown to 2.

An alternate mode is selected by adding a 2nd argument to the command,
``magma``. In this case, a column of 7/7 magma is generated on top of the
targets until they die (Warning: do not call on magma-safe creatures. Also,
using this mode on birds is not recommended.)  The final alternate mode
is ``butcher``, which marks them for butchering but does not kill.

Will target any unit on a revealed tile of the map, including ambushers,
but ignore caged/chained creatures.

Ex::

    exterminate gob
    exterminate gob:male
    exterminate gob:enemy

To kill a single creature, select the unit with the 'v' cursor and::

    exterminate this

To purify all elves on the map with fire (may have side-effects)::

    exterminate elve magma
