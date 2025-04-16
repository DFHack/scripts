gui/adv-finder
==============

.. dfhack-tool::
    :summary: Find and track historical figures and artifacts
    :tags: adventure armok inspection items units

A real-time tracker for historical figures and artifacts. Select a target by
clicking the settings icon [☼] and selecting an entry from the list in the
relevant tab. The list can be filtered by search string, as well as by
excluding dead figures (displayed in red text). Artifacts can exclude books,
and the "dead" option excludes artifacts held by dead figures (which are
generally unrecoverable). Dismissing the screen (e.g., right-click) will
close the target search window first. A second dismissal will close the
finder window, but target settings will be preserved until the world is
unloaded.

Your coordinates will be kept up to date alongside your target's. There are
two types of coordinates, and they will be displayed as long as they can be
determined.

==========  ==========
Coord Type  Meaning
==========  ==========
Global      Distance in map blocks from the world origin (northwest corner).
            The adventurer usually moves by 3 blocks during fast travel, but
            slows to 1 when the zoomed site map is displayed. Equivalent to
            16 local tiles. Always available except for targets with an
            indeterminate location.
Local       Tile coordinates, available outside of fast travel and sleeping.
            Your target's local coordinates are displayed when nearby and
            loaded. Local coordinates will remain consistent within a site, but
            may jump around in the wilderness as areas of the world are loaded.
==========  ==========

For global coordinates, the Z component will only be displayed if it can be
specifically determined by the location type. This represents an underground
layer depth, so the surface is indicated by ``Z0`` and the first cavern layer
is ``Z-1``.

A compass and relative coordinates will be displayed. The relative coordinate
display uses the most precise coordinate type shared between you and your
target.

There are six types of location types displayed for targets:

=============  ==========
Location Type  Meaning
=============  ==========
Nearby         The target is loaded into the map area and the local
               coordinates will be displayed. If you don't see this when you're
               in the correct area and outside fast travel, then the target
               isn't loading for some reason and you'll never be able to find
               them.
Site           The target is located within a site. The text displays
               "At <Sitename>" and the global coords will represent the center
               of the site if the target doesn't track its own precise
               coordinates (e.g., worldgen being vague).
Traveling      The target is traveling around the world map like an army.
Wilderness     The target is somewhere on the surface not in a site.
Underground    The target is somewhere in the caverns not in a site.
None           The target's location isn't defined in the game world.
               Maybe they're a deity. Maybe they got dropped off in limbo
               after their army disbanded. If they're dead, the location
               wasn't recorded properly in history. The text displays "Missing"
               if they're dead or can die of old age, else "Transcendent"
               because nothing can touch them.
=============  ==========

Dead figures generally can't be encountered at all, and they take their items
with them if they weren't separated properly by worldgen. The coord given is
usually a death or abstract burial location, but the corpse isn't guaranteed to
exist. Generally, wilderness and underground locations only have coords if you
left something there in adventure mode. Anything lost there during worldgen or a
fort mode mission likely can't be located. Anything in a site is usually a safe
bet, but sometimes items won't load. (Fort missions can be used to acquire these
for later retrieval, however.) Traveling targets are always valid.

Usage
-----

::

    gui/adv-finder [<options>]

Examples
--------

``gui/adv-finder``
    Open the finder window (unless already open). Target will be blank on first
    use, but maintained on future invocations.
``gui/adv-finder --histfig 1234``
    Track the historical figure with ID #1234. Finder will be opened if not
    already.
``gui/adv-finder -h -1 -a -1``
    Clear any target so it's just the adventurer. Finder will be opened if not
    already.
``gui/adv-finder --debug``
    Display selected target IDs in the finder window title bar. Finder will be
    opened if not already. This setting isn't saved, so it can be disabled by
    invoking ``gui/adv-finder`` again without the option.

Options
-------

``-h``, ``--histfig <id>``
    Set the target to the historical figure with the given ID.
``-a``, ``--artifact <id>``
    Set the target to the artifact record with the given ID. (Not an item ID!)
``-d``, ``--debug``
    Display selected target IDs in the finder window title bar. Doesn't persist
    between invocations.
