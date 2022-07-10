
modtools/add-syndrome
=====================
This allows adding and removing syndromes from units.

Arguments::

    -syndrome name|id
        the name or id of the syndrome to operate on
        examples:
            "gila monster bite"
            14
    -resetPolicy policy
        specify a policy of what to do if the unit already has an
        instance of the syndrome.  examples:
            NewInstance
                default behavior: create a new instance of the syndrome
            DoNothing
            ResetDuration
            AddDuration
    -erase
        instead of adding an instance of the syndrome, erase one
    -eraseAll
        erase every instance of the syndrome
    -eraseClass SYN_CLASS
        erase every instance of every syndrome with the given SYN_CLASS
    -target id
        the unit id of the target unit
        examples:
            0
            28
    -skipImmunities
        add the syndrome to the target even if it is immune to the syndrome
