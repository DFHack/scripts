
modtools/syndrome-trigger
=========================
Triggers dfhack commands when syndromes are applied to units.

Arguments::

    -clear
        clear any previously registered syndrome triggers

    -syndrome SYN_NAME
        specify a syndrome by its SYN_NAME
        enclose the name in quotation marks if it includes spaces
        example:
            -syndrome "gila monster bite"

    -synclass SYN_CLASS
        any syndrome with the specified SYN_CLASS will act as a trigger
        enclose in quotation marks if it includes spaces
        example:
            -synclass VAMPCURSE

    -command [ commandStrs ]
        specify the command to be executed after infection
        remember to include a space after/before the square brackets!
        the following may be added to appropriate commands where relevant:
            \\UNIT_ID
                inserts the ID of the infected unit
            \\LOCATION
                inserts the x, y, z coordinates of the infected unit
            \\SYNDROME_ID
                inserts the ID of the syndrome
        note that:
            \\anything -> \anything
            anything -> anything
        examples:
            -command [ full-heal -unit \\UNIT_ID ]
                heals units when they acquire the specified syndrome
            -command [ modtools/spawn-flow -flowType Dragonfire -location [ \\LOCATION ] ]
                spawns dragonfire at the location of infected units

