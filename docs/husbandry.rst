husbandry
=========

.. dfhack-tool::
    :summary: Automatically milk and shear animals.
    :tags: fort auto

This tool will automatically create milking and shearing orders at farmer's
workshops. Unlike the ``automilk`` and ``autoshear`` options from the control
panel, which create general work orders for milking and shearing jobs,
``husbandry`` will directly create jobs for individual animals at specific
workshops. This allows milking and shearing jobs to reliably be created at
nearby workshops (e.g. inside the pasture that an animal is assigned to),
minimizing the labor required to re-pasture animals after milking or shearing,
in particular in the case of multiple pastures that are far apart.


Usage
-----

::

    enable husbandry
    husbandry [status]
    husbandry now
    husbandry [set|unset] [shearing|milking|roaming|pasture]+

Flags can be set or unset using the command ``husbandry set`` or ``husbandry
unset``. The ``shearing`` and ``milking`` flags (both enabled by default)
control whether shearing or milking jobs are created at all.

Further, ``husbandry`` distinguishes between animals that are assigned to
pastures and those that are "roaming".

If an animal is pastured and the pasture contains at least one workshop with the
appropriate labour (i.e. milking or shearing) enabled, jobs will be created
exclusively at those workshops. If the pasture does not contain a workshop with
the appropriate labor enabled the behavior depends on the ``pasture`` flag
(disabled by default): if set, no jobs will be created at workshops outside of
pastures, otherwise jobs may be created at the closest workshop in your fort.

For animals that are roaming, jobs will only be created if the ``roaming`` flag
is set, which is the default. In this case, jobs are created at the closest
workshop with the appropriate labours enabled.

Examples
--------

``enable husbandry``
    Start generating milking and shearing orders for animals.

``husbandry now``
    Run a single cycle, detecting animals that can be milked/sheared an creating
    jobs. Does not require the tool to be enabled.

``husbandry unset roaming``
    Disable the creation of jobs for roaming animals.

``husbandry set milking shearing pasture``
    Create milking and shearing jobs for pastured animals, but only at workshops
    inside their pastures.
