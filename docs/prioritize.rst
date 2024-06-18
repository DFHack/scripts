prioritize
==========

.. dfhack-tool::
    :summary: Automatically boost the priority of important job types.
    :tags: fort auto jobs

This tool encourages specified types of jobs to get assigned and completed as
soon as possible. Finally, you can be sure your food will be hauled before
rotting, your hides will be tanned before going bad, and the corpses of your
enemies will be cleared from your entranceway expediently.

You can prioritize a bunch of active jobs that you need done *right now*, or you
can mark certain job types as high priority, and ``prioritize`` will watch for
and boost the priority of those types of jobs as they are created. This is
especially useful for ensuring important (but low-priority -- according to DF)
jobs don't get ignored indefinitely in busy forts.

It is important to automatically prioritize only the *most* important job types.
If you add too many job types, or if there are simply too many jobs of those
types in your fort, the *other* tasks in your fort can get ignored. This causes
the same problem that ``prioritize`` is designed to solve. The script provides
a good default set of job types to prioritize that have been suggested and
playtested by the DF community.

Usage
-----

::

    enable prioritize
    disable prioritize
    prioritize [<options>] [defaults|<job_type> ...]

Examples
--------

``prioritize``
    Print out which job types are being automatically prioritized and how many
    jobs of each type we have prioritized since we started watching them. The
    counts are saved with your game, so they will be accurate even if the game
    has been saved and reloaded since ``prioritize`` was started.
``enable prioritize``, ``prioritize -a defaults``
    Watch for and prioritize the default set of job types that the community has
    suggested and playtested (see below for details).
``prioritize -j``
    Print out the list of active jobs that you can prioritize right now.
``prioritize ConstructBuilding DestroyBuilding``
    Prioritize all current building construction and destruction jobs.
``prioritize -a --haul-labor=Food,Body StoreItemInStockpile``
    Prioritize all current and future food and corpse hauling jobs.
``disable prioritize``
    Remove all job types from the watch list and clear tracking data.

Options
-------

``-a``, ``--add``
    Prioritize all current and future jobs of the specified job types.
``-d``, ``--delete``
    Stop automatically prioritizing new jobs of the specified job types.
``-j``, ``--jobs``
    Print out how many unassigned jobs of each type there are. This is useful
    for discovering the types of the jobs that you can prioritize right now. If
    any job types are specified, only jobs of those types are listed.
``-l``, ``--haul-labor <labor>[,<labor>...]``
    For StoreItemInStockpile jobs, match only the specified hauling labor(s).
    Valid ``labor`` strings are: "Stone", "Wood", "Body", "Food", "Refuse",
    "Item", "Furniture", and "Animals". If not specified, defaults to matching
    all StoreItemInStockpile jobs.
``-n``, ``--reaction-name <name>[,<name>...]``
    For CustomReaction jobs, match only the specified reaction name(s). See the
    registry output (``-r``) for the full list of reaction names. If not
    specified, defaults to matching all CustomReaction jobs.
``-q``, ``--quiet``
    Suppress informational output (error messages are still printed).
``-r``, ``--registry``
    Print out the full list of valid job types, hauling labors, and reaction
    names.

Which job types should I prioritize?
------------------------------------

In general, you should prioritize job types that you care about getting done
especially quickly and that the game does not prioritize for you. Time-sensitive
tasks like food hauling, medical care, and lever pulling are good candidates.

For greater fort efficiency, you should also prioritize jobs that can block the
completion of other jobs. For example, dwarves often fill a stockpile up
completely, ignoring the barrels, pots, and bins that could be used to organize
the items more efficiently. Prioritizing those organizational jobs can mean the
difference between having space in your food stockpile for fresh meat and being
forced to let it rot in the butcher shop.

It is also convenient to prioritize tasks that block you (the player) from doing
other things. When you designate a group of trees for chopping, it's often
because you want to *do* something with those logs and/or that free space.
Prioritizing tree chopping will get your dwarves on the task and keep you from
staring at the screen too long.

You may be tempted to automatically prioritize ``ConstructBuilding`` jobs, but
beware that if you engage in megaprojects where many constructions must be
built, these jobs can consume your entire fortress if prioritized. It is often
better to run ``prioritize ConstructBuilding`` by itself (i.e. without the
``-a`` parameter) as needed to just prioritize the construction jobs that you
have ready at the time.

Default list of job types to prioritize
---------------------------------------

The community has assembled a good default list of job types that most players
will benefit from. They have been playtested across a wide variety of fort
types. It is a good idea to enable `prioritize` with at least these defaults
for all your forts.

The default prioritize list includes:

- Handling items that can rot
- Medical, hygiene, and hospice tasks
- Interactions with animals and prisoners
- Noble-specific tasks (like managing workorders)
- Dumping items, felling trees, and other tasks that you, as a player, might
  stare at and internally scream "why why why isn't this getting done??".

Overlay
-------

This script also provides an overlay that is managed by the `overlay`
framework. A panel is added to the info sheet for buildings that are queued for
construction or destruction. If a unit has taken the job, their name will be
listed. Click on the name to zoom to the unit. There is also a toggle button
for high priority status for the job. Toggle it on if the job is not being
taken and you need it to be completed quickly.
