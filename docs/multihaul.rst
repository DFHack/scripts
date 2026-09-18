multihaul
=========

.. dfhack-tool::
    :summary: Let citizens haul multiple items to a stockpile in one trip.
    :tags: fort productivity items

When a citizen picks up an item for a stockpile, they will also grab up to
``max`` additional loose items of the same type within ``radius`` tiles of
the pickup, then drop everything off in one trip. Extras that are dropped or
interrupted along the way are simply left for normal hauling, so a cancelled
job never leaves items stuck or claimed.

This tool is not enabled by default. Enable it with ``enable multihaul`` or
by running ``multihaul enable``.

Usage
-----

    ``multihaul enable|disable``
        Turn multi-hauling on or off.
    ``multihaul status``
        Show whether the tool is enabled and the current limits.
    ``multihaul max <n>``
        Maximum extra items carried per trip (default 4).
    ``multihaul radius <n>``
        Search radius in tiles around the pickup (default 2).

Only unclaimed, loose items that are not forbidden, owned, rotten, marked for
dumping/melting, inside containers, or already inside a stockpile are picked
up as extras.
