fix/retrieve-units
==================

.. dfhack-tool::
    :summary: Allow stuck offscreen units to enter the map.
    :tags: fort bugfix units

This script finds units that are marked as pending entry to the active map and
forces them to enter. This can fix issues such as:

- Stuck [SIEGE] tags due to invisible armies (or parts of armies)
- Forgotten beasts that never appear
- Packs of wildlife that are missing from the surface or caverns
- Caravans that are partially or completely missing

.. note::
    For caravans that are missing entirely, this script may retrieve the
    merchants but not the items. Using `fix/stuck-merchants` to dismiss the
    caravan followed by ``force Caravan`` to create a new one may work better.

Usage
-----

::

    fix/retrieve-units
