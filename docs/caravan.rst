
caravan
=======

Adjusts properties of caravans on the map. See also `force` to create caravans.

This script has multiple subcommands. Commands listed with the argument
``[IDS]`` can take multiple caravan IDs (see ``caravan list``). If no IDs are
specified, then the commands apply to all caravans on the map.

**Subcommands:**

- ``list``: lists IDs and information about all caravans on the map.
- ``extend [DAYS] [IDS]``: extends the time that caravans stay at the depot by
  the specified number of days (defaults to 7 if not specified). Also causes
  caravans to return to the depot if applicable.
- ``happy [IDS]``: makes caravans willing to trade again (after seizing goods,
  annoying merchants, etc.). Also causes caravans to return to the depot if
  applicable.
- ``leave [IDS]``: makes caravans pack up and leave immediately.
- ``unload``: fixes endless unloading at the depot. Run this if merchant pack
  animals were startled and now refuse to come to the trade depot.
