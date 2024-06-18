pop-control
===========

.. dfhack-tool::
    :summary: Limit the maximum size of migrant waves.
    :tags: fort gameplay

This tool dynamically adjusts the game population caps to limit the number of
migrants that can arrive in a single wave. This prevents migration waves from
getting too large and overwhelming a fort's infrastructure.

.. warning::

    This tool will change the population cap in the game settings. If you exit
    out of a fort that has this tool enabled and then load a fort that doesn't
    have this tool enabled, or if you start a new fort and `pop-control` is not
    set for autostart, your population cap will be set to whatever value was
    currently used for the previously loaded fort.

If you want to more severely limit immigration and other "people" events, see
`hermit`.

Usage
-----

::

    enable pop-control
    pop-control [status]
    pop-control set wave-size <wave_size>
    pop-control set max-pop <max_pop>
    pop-control reset

By default, migration waves are capped at 10 migrants and the fort max
population is set at 200.

When `pop-control` is disabled, the game population cap is set to the value
configured for ``max-pop``. If you have manually adjusted the population caps
outside of this tool, the value that is restored may differ from what you had
originally set.

Likewise, if you manually adjust the population caps while this tool is
enabled, your manual settings will be overwritten when `pop-control` next
compares your fort population to the settings configured for `pop-control`.

Examples
--------

``enable pop-control``
    Dynamically adjust the population cap for this fort so all future migrant waves are no larger than the configured ``wave-size``.
``pop-control``
    Show currently configured settings.
``pop-control set wave-size 5``
    Ensure future migration waves have 5 or fewer members.
``pop-control reset``
    Reset the wave size and max population to defaults.
