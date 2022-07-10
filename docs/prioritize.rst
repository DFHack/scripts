
prioritize
==========

The prioritize script sets the ``do_now`` flag on all of the specified types of
jobs that are ready to be picked up by a dwarf but not yet assigned to a dwarf.
This will force them to get assigned and completed as soon as possible.

This script can also continue to monitor new jobs and automatically boost the
priority of jobs of the specified types.

This is useful for ensuring important (but low-priority -- according to DF) jobs
don't get indefinitely ignored in busy forts. The list of monitored job types is
cleared whenever you unload a map, so you can add a section like the one below
to your ``onMapLoad.init`` file to ensure important and time-sensitive job types
are always completed promptly in your forts::

    prioritize -a --haul-labor=Food,Body StoreItemInStockpile
    prioritize -a --reaction-name=TAN_A_HIDE CustomReaction
    prioritize -a PrepareRawFish ExtractFromRawFish CleanSelf

It is important to automatically prioritize only the *most* important job types.
If you add too many job types, or if there are simply too many jobs of those
types in your fort, the other tasks in your fort can get ignored. This causes
the same problem the ``prioritize`` script is designed to solve. See the
`onMapLoad-dreamfort-init` file in the ``hack/examples/init`` folder for a more
complete, playtested set of job types to automatically prioritize.

If you need a bunch of jobs of a specific type prioritized *right now*, consider
running ``prioritize`` without the ``-a`` parameter, which only affects
currently available (but unassigned) jobs. For example::

    prioritize ConstructBuilding

Also see the ``do-job-now`` `tweak` for adding a hotkey to the jobs screen that
can toggle the priority of specific individual jobs and the `do-job-now`
script, which boosts the priority of current jobs related to the selected
job/unit/item/building/order.

Usage::

    prioritize [<options>] [<job_type> ...]

Examples:

``prioritize``
    Prints out which job types are being automatically prioritized and how many
    jobs of each type we have prioritized since we started watching them.

``prioritize -j``
    Prints out the list of active job types that you can prioritize right now.

``prioritize ConstructBuilding DestroyBuilding``
    Prioritizes all current building construction and destruction jobs.

``prioritize -a --haul-labor=Food,Body StoreItemInStockpile``
    Prioritizes all current and future food and corpse hauling jobs.

Options:

:``-a``, ``--add``:
    Prioritize all current and future jobs of the specified job types.
:``-d``, ``--delete``:
    Stop automatically prioritizing new jobs of the specified job types.
:``-h``, ``--help``:
    Show help text.
:``-j``, ``--jobs``:
    Print out how many unassigned jobs of each type there are. This is useful
    for discovering the types of the jobs that you can prioritize right now. If
    any job types are specified, only returns the count for those types.
:``-l``, ``--haul-labor`` <labor>[,<labor>...]:
    For StoreItemInStockpile jobs, match only the specified hauling labor(s).
    Valid <labor> strings are: "Stone", "Wood", "Body", "Food", "Refuse",
    "Item", "Furniture", and "Animals". If not specified, defaults to matching
    all StoreItemInStockpile jobs.
:``-n``, ``--reaction-name`` <name>[,<name>...]:
    For CustomReaction jobs, match only the specified reaction name(s). See the
    registry output (``-r``) for the full list of reaction names. If not
    specified, defaults to matching all CustomReaction jobs.
:``-q``, ``--quiet``:
    Suppress informational output (error messages are still printed).
:``-r``, ``--registry``:
    Print out the full list of valid job types, hauling labors, and reaction
    names.
