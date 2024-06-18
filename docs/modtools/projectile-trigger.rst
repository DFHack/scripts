modtools/projectile-trigger
===========================

.. dfhack-tool::
    :summary: Run DFHack commands when projectiles hit their targets.
    :tags: unavailable

This triggers dfhack commands when projectiles hit their targets.

Usage
-----

::

    -clear
        unregister all triggers
    -material
        specify a material for projectiles that will trigger the command
        examples:
            INORGANIC:IRON
            CREATURE_MAT:DWARF:BRAIN
            PLANT_MAT:MUSHROOM_HELMET_PLUMP:DRINK
    -command [ commandList ]
        \\LOCATION
        \\PROJECTILE_ID
        \\FIRER_ID
        \\anything -> \anything
        anything -> anything
