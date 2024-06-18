spawnunit
=========

.. dfhack-tool::
    :summary: Create a unit.
    :tags: unavailable

This tool allows you to easily spawn a unit of your choice. It is a simplified
interface to `modtools/create-unit`, which this tool uses to actually create
the requested unit.

Usage
-----

::

    spawnunit [-command] <race> <caste> [<name> [<x> <y> <z>]] [...]

If ``-command`` is specified, the generated `modtools/create-unit` command is
printed to the terminal instead of being run.

The name and coordinates of the unit are optional. Any further arguments are
simply passed on to `modtools/create-unit`. See documentation for that tool for
information on what you can pass through.

To see the full list of races and castes for your world, run the following
command::

    devel/query --table df.global.world.raws.creatures.all --search [ creature_id caste_id ] --maxdepth 3 --maxlength 5000

Examples
--------

``spawnunit GOBLIN MALE``
    Warp in a (male) goblin for your squads to beat on.
``spawnunit JABBERER FEMALE --domesticate``
    Spawn a tame female jabberer for breeding an army!
