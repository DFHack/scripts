
modtools/spawn-flow
===================
Creates flows at the specified location.

Arguments::

    -material mat
        specify the material of the flow, if applicable
        examples:
            INORGANIC:IRON
            CREATURE_MAT:DWARF:BRAIN
            PLANT_MAT:MUSHROOM_HELMET_PLUMP:DRINK
    -location [ x y z]
        the location to spawn the flow
    -flowType type
        specify the flow type
        examples:
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
    -flowSize size
        specify how big the flow is
