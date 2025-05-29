uniform-unstick
===============

.. dfhack-tool::
    :summary: Make military units reevaluate their uniforms.
    :tags: fort bugfix military

This tool prompts military units to reevaluate their uniform, making them
remove and drop potentially conflicting worn items. If multiple units claim the
same item, the item will be unassigned from all units that are not already
wearing the item. If this happens, you'll have to click the "Update equipment"
button on the Squads "Equip" screen in order for them to get new equipment
assigned.

Unlike a "replace clothing" designation, it won't remove additional clothing if
it's coexisting with a uniform item already on that body part. It also won't
remove clothing (e.g. shoes, trousers) if the unit has yet to claim an armor
item for that bodypart (e.g. if you're still manufacturing them).

Uniforms that have no issues are being properly worn will not be affected.

When generating a report of conflicts, items that simply haven't been picked up
yet or uniform components that haven't been assigned by DF are not considered
conflicts and are not included in the report.

Usage
-----

``uniform-unstick [--all]``
    List problems with the uniform for the currently selected unit (or all
    units).
``uniform-unstick [--all] <strategy options>``
    Fix the problems with the unit's uniform (or all units' uniforms) using the
    specified strategies.

Examples
--------

``uniform-unstick --all --drop --free``
    Fix all issues with uniforms that have only one item per body part (like all
    default uniforms).

Strategy options
----------------

``--drop``
    Force the unit to drop conflicting worn items onto the ground, where they
    can then be reclaimed in the correct order.
``--free``
    Remove items from the uniform assignment if someone else has a claim on
    them. This will also remove items from containers and place them on the
    ground, ready to be claimed.
``--multi``
    Attempt to fix issues with uniforms that allow multiple items per body part.

Overlay
-------

This script adds a small link to the squad equipment page that will run
``uniform-unstick --all`` and show the report when clicked. After reviewing the
report, you can right click to exit and do nothing or you can click the "Try to
resolve conflicts" button, which runs the equivalent of
``uniform-unstick --all --drop --free``. If any items are unassigned (they'll
turn red on the equipment screen), hit the "Update Equipment" button to
reassign equipment.
