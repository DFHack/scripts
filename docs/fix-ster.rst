
fix-ster
========
Utilizes the orientation tag to either fix infertile creatures or inflict
infertility on creatures that you do not want to breed.  Usage::

    fix-ster [fert|ster] [all|animals|only:<creature>]

``fert`` or ``ster`` is a required argument; whether to make the target fertile
or sterile.  Optional arguments specify the target: no argument for the
selected unit, ``all`` for all units on the map, ``animals`` for all non-dwarf
creatures, or ``only:<creature>`` to only process matching creatures.

