multihaul
=========

.. dfhack-tool::
    :summary: Let citizens haul multiple items in one trip.
    :tags: fort productivity items

When a citizen picks up an item for a stockpile, they will also grab up to
``max`` additional loose items of the same type within ``radius`` tiles --
both at the pickup site and opportunistically along the way -- then drop
everything off in one trip. Extras that are dropped or interrupted along
the way are simply left for normal hauling, so a cancelled job never leaves
items stuck or claimed. Jobs already assisted by a wheelbarrow are skipped,
since the wheelbarrow already carries multiple items.

This tool is not enabled by default. Enable it with ``enable multihaul`` or
by running ``multihaul enable``.

Usage
-----

    ``multihaul enable|disable``
        Turn multi-hauling on or off. Disabling releases all items that are
        currently being piggybacked.
    ``multihaul status``
        Show whether the tool is enabled and the current limits.
    ``multihaul max <n>``
        Maximum extra items carried per trip (default 4).
    ``multihaul radius <n>``
        Search radius in tiles around the dwarf for opportunistic pickups
        made along the way (default 2).
    ``multihaul fetch <n>``
        How far around the pickup site the dwarf will detour to collect
        extras before departing (default 8).
    ``multihaul weight <n>``
        Maximum combined weight of the whole carried load, in DF mass units
        (default 0 = unlimited). Covers the job's own item plus all extras,
        so a dwarf never carries more than this total. Use
        ``multihaul weight auto`` to derive the cap from each citizen's
        strength and body size instead (a typical dwarf can manage roughly
        three boulders), or ``multihaul weight unlimited`` to remove it.
    ``multihaul types same|all|pile``
        ``same`` (default) only grabs loose items of the same type as the
        job's item. ``all`` also grabs items of other types that a different
        haul job has already claimed for the same destination, effectively
        letting one trip do the work of several jobs. ``pile`` is like
        ``all``, plus it grabs unclaimed items of any type that the
        destination stockpile's filter provably accepts, so a dwarf heading
        to a mixed goods pile sweeps up everything nearby that belongs
        there.
    ``multihaul targets piles|all``
        ``piles`` (default) only piggybacks stockpile jobs. ``all`` also
        piggybacks loads destined for minecarts, barrels, and bins, where
        the extras are inserted into the container along with the job's
        own item.

Only loose items that are not forbidden, owned, rotten, marked for
dumping/melting, inside containers, or already inside a stockpile or other
building are picked up as extras. Items claimed by unrelated jobs are never
taken.
