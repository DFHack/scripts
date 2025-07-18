entomb
======

.. dfhack-tool::
    :summary: Entomb any corpse into tomb zones.
    :tags: fort items buildings

Assign any corpse regardless of citizenship, residency, pet status,
or affiliation to an unassigned tomb zone for burial.

Usage
-----

``entomb [<options>]``

This script must be executed with either a unit's corpse or body part
selected or with a unit ID specified. An unassigned tomb zone will then
be assigned to the unit for burial and all its corpse and/or body parts
will become valid items for interment.

Optionally, the zone ID may also be specified to assign a specific tomb
zone to the unit.

A non-citizen, non-resident, or non-pet unit that is still alive may
even be assigned a tomb zone if they have lost any body part that can
be placed inside a tomb, e.g. teeth or severed limbs. New corpse items
after a tomb has already been assigned will not be properly interred
until the script is executed again on either the unit, its corpse, or
any of its body parts.

If executed on slaughtered animals, all its butchering returns will
become valid burial items and no longer usable for cooking or crafting.

Examples
--------

``entomb unit <id>``
    Assign an unassigned tomb zone to the unit with the specified ID.

``entomb tomb <id>``
    Assign a tomb zone with the specified ID to the selected corpse
    item's unit.

``entomb unit <id> tomb <id> now``
    Assign a tomb zone with the specified ID to the unit with the
    specified ID and teleport its corpse and/or body parts into the
    coffin in the tomb zone.

Options
-------

``unit <id>``
    Specify the ID of the unit to be assigned to a tomb zone.

``tomb <id>``
    Specify the ID of the zone into which a unit will be interred.

``now``
    Instantly teleport the unit's corpse and/or body parts into the
    coffin of its assigned tomb zone. This option can be called on
    corpse items or units that are already assigned a tomb zone.
