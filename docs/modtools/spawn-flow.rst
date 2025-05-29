modtools/spawn-flow
===================

.. dfhack-tool::
    :summary: Creates flows at the specified location.
    :tags: unavailable

Creates flows at the specified location.

Usage
-----

::

    modtools/spawn-flow --material <TOKEN> --flowType <type> --location [ <x> <y> <z> ] [--flowSize <size>]

Options
-------

``--material <TOKEN>``
    Specify the material of the flow, if applicable. E.g. ``INORGANIC:IRON``,
    ``CREATURE_MAT:DWARF:BRAIN``, or ``PLANT_MAT:MUSHROOM_HELMET_PLUMP:DRINK``.
``--flowType <type>``
    The flow type, one of::

        Miasma
        Steam
        Mist
        MaterialDust
        MagmaMist
        Smoke
        Dragonfire
        Fire
        Web
        MaterialGas
        MaterialVapor
        OceanWave
        SeaFoam

``--location [ <x> <y> <z> ]``
    The location to spawn the flow
``--flowSize <size>``
    Specify how big the flow is (default: 100).
