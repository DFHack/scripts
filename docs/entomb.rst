entomb
======

.. dfhack-tool::
    :summary: Entomb any corpse into tomb zones.
    :tags: fort items buildings

Assign any unit regardless of citizenship, residency, pet status,
or affiliation to an unassigned tomb zone for burial.

Usage
-----

``entomb [<options>]``

Select a unit's corpse or body part, or specify the unit's ID
when executing this script to assign an unassigned tomb zone to
the unit, and flag the unit's corpse as well as any severed body
parts to become valid items for interment.

Optionally, specify the tomb zone's ID to assign a specific tomb
zone to the unit.

A non-citizen, non-resident, or non-pet unit that is still alive
may even be assigned a tomb zone if they have lost any body part
that can be placed inside a tomb, e.g. teeth or severed limbs.
New corpse items after a tomb has already been assigned will not
be properly interred until the script is executed again with the
unit ID specified, or the unit's corpse or any body part selected.

If executed on slaughtered animals, all its butchering returns will
become valid burial items and no longer usable for cooking or crafting.

Examples
--------

``entomb --unit <id>``
    Assign an unassigned tomb zone to the unit with the specified ID.

``entomb --tomb <id>``
    Assign a tomb zone with the specified ID to the selected corpse
    item's unit.

``entomb -u <id> -t <id> -h``
    Assign a tomb zone with the specified ID to the unit with the
    specified ID and task all its burial items for simultaneous
    hauling into the coffin in the tomb zone.

Options
-------

``-u``, ``--unit <id>``
    Specify the ID of the unit to be assigned to a tomb zone.

``-t``, ``--tomb <id>``
    Specify the ID of the zone into which a unit will be interred.

``-a``, ``--add-item``
    Add a selected item, or multiple items at the keyboard cursor's
    position to be interred together with a unit. A unit or tomb
    zone ID must be specified when calling this option.

``-n``, ``--haul-now``
    Task all of the unit's burial items for simultaneous hauling
    into the coffin of its assigned tomb zone. This option can be
    called even after a tomb zone is already assigned to the unit.
