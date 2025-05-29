modtools/moddable-gods
======================

.. dfhack-tool::
    :summary: Create deities.
    :tags: dev

This script allows you to create new gods in an existing world.

Usage
-----

::

    moddable-gods --name <name> --spheres <sphereList> [<options>]

Examples
--------

``modtools/moddable-gods --name "Slarty Bog" --spheres FATE,WEATHER``
    Create a new god named "Slarty Bog" with spheres of influence of FATE and
    WEATHER. The god will have a random gender and will be depicted as a dwarf.

``modtools/moddable-gods -n Og -s SPEECH,SALT,SACRIFICE -g neuter -d emu``
    Create a new god named "Og" with spheres of influence of SPEECH, SALT, and
    SACRIFICE. The god will be genderless and will be depicted as an emu.

Options
-------

``-n``, ``--name <name>``
    The name of the god to create. This is a required argument. The name must
    be unique in the world. If the name is already taken, the script will exit
    without action.
``-s``, ``--spheres <sphereList>``
    A comma-separated list of spheres of influence for the god. This is a
    required argument. To see the available spheres, run this command::

        lua @df.sphere_type

``-g``, ``--gender (male|female|neuter)``
    The gender of the god. If not specified, a random gender will be chosen.
``-d``, ``--depicted-as <str or race ID>``
    When the deity is referenced in-game, it will be described as "often
    depicted as a <str>". The string must match the token ID or descriptive
    name of a race that exists in the world. You can also specify a numeric
    race ID. If not specified, it defaults to "dwarf".
``-q``, ``--quiet``
    If specified, suppresses all non-error output.
