fix/dead-units
==============

.. dfhack-tool::
    :summary: Remove dead units from the list so migrants can arrive again.
    :tags: fort bugfix units

If so many units have died at your fort that your dead units list exceeds about
3000 units, migrant waves can stop coming. This fix removes uninteresting units
(like slaughtered animals and nameless goblins) from the unit list, allowing
migrants to start coming again.

It also supports scanning burrows and cleaning out dead units from burrow
assignments. The vanilla UI doesn't provide any way to remove dead units, and
the dead units artificially increase the reported count of units that are
assigned to the burrow.

Usage
-----

::

    fix/dead-units [--active] [-q]
    fix/dead-units --burrow [-q]

Options
-------

``--active``
    Scrub units that have been dead for more than a month from the ``active``
    vector. This is the default if no option is specified.
``--burrow``
    Scrub dead units from burrow membership lists.
``-q``, ``--quiet``
    Surpress console output (final status update is still printed if at least one item was affected).
