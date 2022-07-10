
fix/retrieve-units
==================

This script forces some units off the map to enter the map, which can fix issues
such as the following:

- Stuck [SIEGE] tags due to invisible armies (or parts of armies)
- Forgotten beasts that never appear
- Packs of wildlife that are missing from the surface or caverns
- Caravans that are partially or completely missing.

.. note::
    For caravans that are missing entirely, this script may retrieve the
    merchants but not the items. Using `fix/stuck-merchants` followed by `force`
    to create a new caravan may work better.

