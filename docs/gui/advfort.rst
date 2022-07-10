
gui/advfort
===========
This script allows performing jobs in adventure mode. For more complete help
press :kbd:`?` while the script is running. It's most comfortable to use this as a
keybinding (see below for the default binding). Possible arguments:

* ``-a``, ``--nodfassign``:
    uses a different method to assign job items, instead of relying on DF.
* ``-i``, ``--inventory``:
    checks inventory for possible items to use in the job.
* ``-c``, ``--cheat``:
    relaxes item requirements for buildings (e.g. walls from bones). Implies -a
* ``-e [NAME]``, ``--entity [NAME]``:
    uses the given civ to determine available resources (specified as an entity raw ID). Defaults to ``MOUNTAIN``; if the entity name is omitted, uses the adventurer's civ
* ``job``: selects the specified job (must be a valid ``job_type``, e.g. ``Dig`` or ``FellTree``)

.. warning::
    changes only persist in non-procedural sites, namely player forts, caves, and camps.

An example of a player digging in adventure mode:

.. image:: /docs/images/advfort.png
