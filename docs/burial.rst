burial
======

.. dfhack-tool::
    :summary: Create tomb zones for unzoned coffins.
    :tags: fort productivity buildings

Creates a 1x1 tomb zone for each built coffin that isn't already contained in a
zone.

Usage
-----

    ``burial [<options>]``

Examples
--------

``burial``
    Create a general use tomb for every unzoned coffin on the map.

``burial -z``
    Create tombs only on the current zlevel.

``burial -c``
    Create tombs designated for burial of citizens only.

``burial -p``
    Create tombs designated for burial of pets only.

``burial -cp``
    Create tombs with automatic burial disabled for both citizens and pets,
    requiring manual assignment of deceased units to each tomb.

Options
-------

``-z``, ``--cur-zlevel``
    Only create tombs on the current zlevel.

``-c``, ``--citizens-only``
    Only automatically bury citizens.

``-p``, ``--pets-only``
    Only automatically bury pets.
