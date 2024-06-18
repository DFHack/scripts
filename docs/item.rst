item
====

.. dfhack-tool::
    :summary: Perform bulk operations on groups of items.
    :tags: fort productivity items

Filter items in you fort by various properties (e.g., item type, material,
wear-level, quality, ...), and perform bulk operations like forbid, dump, melt,
and their inverses. By default, the tool does not consider artifacts and owned
items. Outputs the number of items that matched the filters and were modified.

Usage
-----

``item [count|[un]forbid|[un]dump|[un]hide|[un]melt] [<filter options>] [<search>]``

The ``count`` action counts up the items that are matched by the given filter
options. Otherwise, the named property is set (or unset) on all the items
matched by the filter options. The counts reported when you actually apply a
property might differ from those reported by ``count``, because applying a
property skips over all items that already have the property set (see
``--dry-run``)

The (optional) search string will filter by the item description. It will be
interpreted as a Lua pattern, so any special regular expression characters
(like ``-``) will need to be escaped with ``%`` (e.g. ``%-``) to be interpreted
as a literal string. See https://www.lua.org/manual/5.3/manual.html#6.4.1 for
details. For example "cave spider silk" will match both "cave spider silk web"
and "cave spider silk cloth". Use ``^pattern$`` to match the entire description.

Examples
--------

``item count steel -v``
    Scan your stocks for (unowned) items that contain the word "steel" and
    print out the counts for each steel item found.

``item count --verbose --by-type steel``
    Scan your stocks for (unowned) items that contain the word "steel" and
    print out the descriptions of the matched items and the counts, grouped by
    item type.

``item forbid --unreachable``
    Forbid all items that cannot be reached by any of your citizens.

``item unforbid --inside Cavern1 --type wood``
    Unforbid/reclaim all logs inside the burrow named "Cavern1" (Hint: use 3D
    flood-fill to create a burrow covering an entire cavern layer).

``item melt -t weapon -m steel --max-quality 3``
    Designate all steel weapons whose quality is at most superior for melting.

``item hide -t boulder --scattered``
    Hide all scattered boulders, i.e. those that are not in stockpiles.

``item unhide``
    Makes all hidden items visible again.

Options
-------

``-n``, ``--dry-run``
    Get a count of the items that would be modified by an operation, which will
    be the number returned by the ``count`` action minus the number of items
    with the desired property already set.

``--by-type``
    Only applies to the ``count`` action. Outputs, in addition to the total
    count, a table of item counts grouped by item type.

``-a``, ``--include-artifacts``
    Include artifacts in the item list. Regardless of this setting, artifacts
    are never dumped or melted.

``--include-owned``
    Include items owned by units (e.g., your dwarves or visitors)

``--ignore-webs``
    Ignore undisturbed spider webs.

``-i``, ``--inside <burrow>``
    Only include items inside the given burrow.

``-o``, ``--outside <burrow>``
    Only include items outside the given burrow.

``-r``, ``--reachable``
    Only include items reachable by one of your citizens.

``-u``, ``--unreachable``
    Only include items not reachable by any of your citizens.

``-t``, ``--type <string>``
    Filter by item type (e.g., BOULDER, CORPSE, ...). Also accepts lower case
    spelling (e.g. "corpse"). Use ``:lua @df.item_type`` to get the list of all
    item types.

``-m``, ``--material <string>``
    Filter by material the item is made out of (e.g., "iron").

``-c``, ``--mat-category <string>``
    Filter by material category of the material item is made out of (e.g.,
    "metal"). Use ``:lua @df.dfhack_material_category`` to get a list of all
    material categories.

``-w``, ``--min-wear <integer>``
    Only include items whose wear/damage level is at least ``integer``. Useful
    values are 0 (pristine) to 3 (XX).

``-W``, ``--max-wear <integer>``
    Only include items whose wear/damage level is at most ``integer``. Useful
    values are 0 (pristine) to 3 (XX).

``-q``, ``--min-quality <integer>``
    Only include items whose quality level is at least ``integer``. Useful
    values are 0 (ordinary) to 5 (masterwork). Use ``:lua @df.item_quality`` to
    get the mapping between numbers and adjectives.

``-Q``, ``--max-quality <integer>``
    Only include items whose quality level is at most ``integer``. Useful
    values are 0 (ordinary) to 5 (masterwork).

``--stockpiled``
    Only include items that are in stockpiles. Does not include empty bins,
    barrels, and wheelbarrows assigned as storage and transport for stockpiles.

``--scattered``
    Opposite of ``--stockpiled``

``--marked=<flag>,<flag>,...``
    Only include items that have all provided flag set to true. Valid flags are:
    ``forbid`` (or ``forbidden``), ``dump``, ``hidden``, ``melt``, and
    ``owned``.

``--not-marked=<flag>,<flag>,...``
    Only include items that have all provided flag set to false. Valid flags the
    same as for ``--marked``.

``--visible``
    Same as ``--not-marked=hidden``

``-v``, ``--verbose``
    Print out a description of each matched item.

API
---

The item script can be called programmatically by other scripts, either via the
commandline interface with ``dfhack.run_script()`` or via the API functions
defined in :source-scripts:`item.lua`, available from the return value of
``reqscript('item')``:

* ``execute(action, conditions, options [, return_items])``

Performs ``action`` (``forbid``, ``melt``, etc.) on all items satisfying
``conditions`` (a table containing functions from item to boolean). ``options``
is a table containing the boolean flags ``artifact``, ``dryrun``, ``bytype``,
and ``owned`` which correspond to the (filter) options described above.

The function ``execute`` performs no output, but returns three values:

1. the number of matching items
2. a table containing all matched items, if ``return_items`` is provided and true.
3. a table containing a mapping from numeric item types to their occurrence
   count, if ``options.bytype=true``

* ``executeWithPrinting(action, conditions, options)``

Performs the same action as ``execute`` and performs the same output as the
``item`` tool, but returns nothing.

The API provides a number of helper functions to aid in the construction of the
filter table. The first argument ``tab`` is always the table to which the filter
should be added. The final ``negate`` argument is optional, passing ``{ negate =
true }`` negates the added filter condition. Below, only the positive version of
the filter is described.

* ``condition_burrow(tab, burrow, negate)``
    Corresponds to ``--inside``. The ``burrow`` argument must be a burrow
    object, not a string.

* ``condition_type(tab, match, negate)``
    If ``match`` is a string, this corresponds to ``--type <match>``. Also
    accepts numbers, matching against ``item:getType()``.

* ``condition_reachable(tab, negate)``
    Corresponds to ``--reachable``.

* ``condition_description(tab, pattern, negate)``
    Corresponds to the search string passed on the commandline.

* ``condition_material(tab, match, negate)``
    Corresponds to ``--material <match>``.

* ``condition_matcat(tab, match, negate)``
    Corresponds to ``--mat-category <match>``.

* ``condition_wear(tab, lower, upper, negate)``
    Selects items with wear level between ``lower`` and ``upper`` (Range 0-3,
    see above).

* ``condition_quality(tab, lower, upper, negate)``
    Selects items with quality between ``lower`` and ``upper`` (Range 0-5, see
    above).

* ``condition_stockpiled(tab, negate)``
    Corresponds to ``--stockpiled``.

* ``condition_[forbid|melt|dump|hidden|owned](tab, negate)``
    Selects items with the respective flag set to ``true`` (e.g.,
    ``condition_forbid`` checks for ``item.flags.forbid``).

 API usage example::

   local itemtools = reqscript('item')
   local cond = {}

   itemtools.condition_type(cond, "BOULDER")
   itemtools.execute('unhide', cond, {}) -- reveal all boulders

   itemtools.condition_stockpiled(cond, { negate = true })
   itemtools.execute('hide', cond, {})   -- hide all boulders not in stockpiles
