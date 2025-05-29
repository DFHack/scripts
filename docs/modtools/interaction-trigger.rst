modtools/interaction-trigger
============================

.. dfhack-tool::
    :summary: Run DFHack commands when a unit attacks or defends.
    :tags: unavailable

This triggers events when a unit uses an interaction on another. It works by
scanning the announcements for the correct attack verb, so the attack verb
must be specified in the interaction. It includes an option to suppress this
announcement after it finds it.

Usage
-----

::

    -clear
        unregisters all triggers
    -onAttackStr str
        trigger the command when the attack verb is "str". both onAttackStr and onDefendStr MUST be specified
    -onDefendStr str
        trigger the command when the defend verb is "str". both onAttackStr and onDefendStr MUST be specified
    -suppressAttack
        delete the attack announcement from the combat logs
    -suppressDefend
        delete the defend announcement from the combat logs
    -command [ commandStrs ]
        specify the command to be executed
        commandStrs
            \\ATTACK_VERB
            \\DEFEND_VERB
            \\ATTACKER_ID
            \\DEFENDER_ID
            \\ATTACK_REPORT
            \\DEFEND_REPORT
            \\anything -> \anything
            anything -> anything

You must specify both an attack string and a defend string to guarantee
correct performance. Either will trigger the script when it happens, but
it will not be triggered twice in a row if both happen.
