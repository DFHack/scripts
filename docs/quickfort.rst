quickfort
=========

.. dfhack-tool::
    :summary: Apply layout blueprints to your fort.
    :tags: fort design productivity buildings map stockpiles

Quickfort reads stored blueprint files and applies them to the game map.
You can apply blueprints that designate digging, build buildings, place
stockpiles, mark zones, and more. If you find yourself spending time doing
similar or repetitive designs in your forts, this tool can be an immense help.

Note that this is the commandline tool. Please see `gui/quickfort` if you'd like
a graphical in-game UI for selecting, previewing, and applying blueprints.

You can create the blueprints by hand (see the `quickfort-blueprint-guide` for
details) or you can build your plan "for real" in Dwarf Fortress, and then
export your map using `gui/blueprint`. This way you can effectively copy and
paste sections of your fort. Player-created blueprints are stored in the
``dfhack-config/blueprints`` directory.

There are many ready-to-use blueprints in the
`blueprint library <blueprint-library-guide>` that is distributed with DFHack,
so you can use this tool productively even if you haven't created any blueprints
yourself. Additional library blueprints can be
`added with mods <modding-guide>` as well.

Usage
-----

``quickfort list [-m|--mode <mode>] [-u|--useronly] [-h|--hidden] [<search string>]``
    Lists available blueprints. Blueprints are ``.csv`` files or sheets within
    ``.xlsx`` files that contain a ``#<mode>`` comment in the upper-left cell
    (please see `quickfort-blueprint-guide` for more information on modes). By
    default, library blueprints are included and blueprints that contain a
    ``hidden()`` marker in their modeline are excluded from the returned list.
    Specify ``-u`` or ``-h`` to exclude library or include hidden blueprints,
    respectively. The list can additionally be filtered by a specified mode
    (e.g. ``-m build``) and/or strings to search for in a path, filename, mode,
    or comment. The id numbers in the reported list may not be contiguous if
    there are hidden or filtered blueprints that are not being shown.
``quickfort delete <filename> [<filename> ...]``
    Delete the specified blueprint file(s). Only player-owned blueprints (stored
    in the ``dfhack-config/blueprints`` directory) can be deleted. Blueprints
    provided by mods or the standard DFHack library cannot be deleted by this
    command.
``quickfort gui [<filename or search terms>]``
    Invokes the quickfort UI with the specified parameters, giving you an
    interactive blueprint preview to work with before you apply it to the map.
    See the `gui/quickfort` documentation for details.
``quickfort <command>[,<command>...] <list_id>[,<list_id>...] [<options>]``
    Applies the blueprint(s) with the id number(s) reported from the ``list``
    command.
``quickfort <command>[,<command>...] <filename> [-n|--name <name>[,<name>...]] [<options>]``
    Applies a blueprint in the specified file. The optional ``name`` parameter
    can select a specific blueprint from a file that contains multiple
    blueprints with the format ``<sheetname>/<label>`` for .xlsx files, or just
    ``/<label>`` for .csv files. The label is defined in the blueprint modeline,
    or, if not defined, defaults to its order in the sheet or file (e.g.
    ``/2``). If the ``-n`` parameter is not specified, the first blueprint in
    the first sheet is used.
``quickfort set [<key> <value>]``
    Allows you to modify the global quickfort configuration. Just run
    ``quickfort set`` to show current settings. See the Configuration_ section
    below for available keys and values.
``quickfort reset``
    Resets quickfort configuration to defaults.

``<command>`` is one of:

:run:     Applies the blueprint at your current in-game cursor position.
:orders:  Uses the manager interface to queue up workorders to manufacture items
          needed by the specified blueprint(s).
:undo:    Applies the inverse of the specified blueprint. Dig tiles are
          undesignated, buildings are canceled or scheduled for destruction
          (depending on their construction status), and stockpiles/zones are
          removed.

Examples
--------

``quickfort gui library/aquifer_tap.csv -n /dig``
    Show the in-game preview for the "dig" blueprint in the
    ``library/aquifer_tap.csv`` file. You can interactively reposition the
    blueprint and apply it where you like (it's intended to be applied in a
    light aquifer layer -- run the associated "help" blueprint for more info).
``quickfort list``
    List all available blueprints.
``quickfort list dreamfort help``
    List all the blueprints that have both "dreamfort" and "help" as keywords.
``quickfort run library/dreamfort.csv``
    Run the first blueprint in the ``library/dreamfort.csv`` file (which happens
    to be the "notes" blueprint that displays the help).
``quickfort run library/pump_stack.csv -n /dig --repeat up,80 --transform ccw,flipv``
    Dig a pump stack through 160 z-levels up from the current cursor location
    (each repetition of the ``library/pump_stack.csv -n /dig`` blueprint is 2
    z-levels). Also transform the blueprint by rotating counterclockwise and
    flipping vertically in order to fit the pump stack through some
    tricky-shaped caverns 50 z-levels above. Note that this kind of careful
    positioning is much easier to do interactively with `gui/quickfort`, but it
    can be done via the commandline as well if you know exactly what
    transformations and positioning you need.
``quickfort orders 10,11,12 --dry-run``
    Process the blueprints with ids ``10``, ``11``, and ``12`` (run
    ``quickfort list`` to see which blueprints these are for you) and calculate
    what materials will be needed by your dwarves to actually complete the
    structures that the blueprints will designate. Display that list to the
    screen, but don't actually enqueue the workorders (the ``--dry-run`` option
    prevents actual changes to the game).

Command options
---------------

``<options>`` can be zero or more of:

``-c``, ``--cursor <x>,<y>,<z>``
    Use the specified map coordinates instead of the current keyboard map
    cursor for the the blueprint start position. If this option is specified,
    then an active keyboard map cursor is not necessary.
``-d``, ``--dry-run``
    Go through all the motions and print statistics on what would be done, but
    don't actually change any game state.
``-m``, ``--marker <type>[,<type>...]``
    Apply the given marker(s) to the tiles designated by the ``#dig`` blueprint
    that you are applying. Valid marker types are: ``blueprint`` (designate but
    don't dig), ``warm`` (dig even if the tiles are warm), and ``damp`` (dig
    even if the tiles are damp). ``warm`` and ``damp`` markers are interpreted
    by the `dig` tool for interruption-free digging through warm and damp tiles.
``-p``, ``--priority <num>``
    Set the priority to the given number (1-7) for tiles designated by the
    ``#dig`` blueprint that you are applying. That is, tiles that normally have
    a priority of ``4`` will instead have the priority you specify. If the
    blueprint uses other explicit priorities, they will be shifted up or down
    accordingly.
``--preserve-engravings <quality>``
    Don't designate tiles for digging/carving if they have an engraving with at
    least the specified quality. Valid values for ``quality`` are: ``None``,
    ``Ordinary``, ``WellCrafted``, ``FinelyCrafted``, ``Superior``,
    ``Exceptional``, and ``Masterful``. Specify ``None`` to ignore engravings
    when designating tiles. Note that if ``Masterful`` tiles are dug out, the
    dwarf who engraved the masterwork will get negative thoughts. If not
    specified, ``Masterful`` engravings are preserved by default.
``-q``, ``--quiet``
    Suppress non-error console output.
``-r``, ``--repeat <direction>[,]<num levels>``
    Repeats the specified blueprint(s) up or down the requested number of
    z-levels. Direction can be ``up`` or ``down``, and can be abbreviated with
    ``<`` or ``>``. For example, the following options are equivalent:
    ``--repeat down,5``, ``-rdown5``, and ``-r>5``.
``-s``, ``--shift <x>[,<y>]``
    Shifts the blueprint by the specified offset before modifying the game map.
    The values for ``<x>`` and ``<y>`` can be negative. If both ``--shift`` and
    ``--transform`` are specified, the shift is always applied last.
``-t``, ``--transform <transformation>[,<transformation>...]``
    Applies geometric transformations to the blueprint before modifying the game
    map. See the Transformations_ section below for details.
``-v``, ``--verbose``
    Output extra debugging information. This is especially useful if you're
    trying to figure out why the blueprint isn't being applied like you expect.

Transformations
---------------

All transformations are anchored at the blueprint start cursor position. This is
the upper left corner by default, but it can be modified if the blueprint has a
`start() modeline marker <quickfort-start>`. This means that the blueprint tile
that would normally appear under your cursor will still appear under your
cursor, regardless of how the blueprint is rotated or flipped.

``<transformation>`` is one of:

:rotcw or cw:   Rotates the blueprint 90 degrees clockwise.
:rotccw or ccw: Rotates the blueprint 90 degrees counterclockwise.
:fliph:         Flips the blueprint horizontally (left edge becomes right edge).
:flipv:         Flips the blueprint vertically (top edge becomes bottom edge).

Configuration
-------------

The quickfort script has a few global configuration options that you can
customize with the ``quickfort set`` command. Modified settings are only kept
for the current session and will be reset when you restart DF.

``blueprints_user_dir`` (default: ``dfhack-config/blueprints``)
    Directory tree to search for player-created blueprints. It can be set to an
    absolute or relative path. If set to a relative path, it resolves to a
    directory under the DF folder. Note that if you change this directory, you
    will not see blueprints written by the DFHack `blueprint` plugin (which
    always writes to the ``dfhack-config/blueprints`` dir).
``blueprints_library_dir`` (default: ``hack/data/blueprints``)
    Directory tree to search for library blueprints.
``force_marker_mode`` (default: ``false``)
    If true, will designate all dig blueprints in marker=blueprint mode. If
    false, only cells with dig codes explicitly prefixed with ``mb`` in the
    blueprint cell will be designated in marker mode.
``stockpiles_max_barrels``, ``stockpiles_max_bins``, and ``stockpiles_max_wheelbarrows`` (defaults: ``-1``, ``-1``, ``0``)
    Set to the maximum number of resources you want assigned to stockpiles of
    the relevant types. Set to ``-1`` for DF defaults (number of stockpile tiles
    for stockpiles that take barrels and bins, and 1 wheelbarrow for stone
    stockpiles). The default here for wheelbarrows is ``0`` since using
    wheelbarrows can *decrease* the efficiency of your fort unless you assign
    an appropriate number of wheelbarrows to the stockpile. Blueprints can
    `override <quickfort-place-containers>` this value for specific stockpiles.

API
---

The quickfort script can be called programmatically by other scripts, either via
the commandline interface with ``dfhack.run_script()`` or via the API functions
defined in :source-scripts:`quickfort.lua`, available from the return value of
``reqscript('quickfort)``:

* ``quickfort.apply_blueprint(params)``

Applies the specified blueprint data and returns processing statistics. The
statistics structure is a map of stat ids to ``{label=string, value=number}``.

``params`` is a table with the following fields:

``mode`` (required)
    The blueprint mode, e.g. ``dig``, ``build``, etc.
``data`` (required)
    A sparse map populated such that ``data[z][y][x]`` yields the blueprint text
    that should be applied to the tile at map coordinate ``(x, y, z)``. You can
    also just pass a string instead of a table and it will be interpreted as
    the value of ``data[0][0][0]``.
``command``
    The quickfort command to execute, e.g. ``run``, ``orders``, etc. Defaults to
    ``run``.
``pos``
    A coordinate that serves as the reference point for the coordinates in the
    data map. That is, the text at ``data[z][y][x]`` will be shifted to be
    applied to coordinate ``(pos.x + x, pos.y + y, pos.z + z)``. If not
    specified, defaults to ``{x=0, y=0, z=0}``, which means that the coordinates
    in the ``data`` map are used without shifting.
``aliases``
    A map of blueprint alias names to their expansions. If not specified,
    defaults to ``{}``.
``marker``
    A map of strings to booleans indicating which markers should be applied to
    this ``dig`` mode blueprint. See `Command options`_ above for details. If
    not specified, defaults to ``{blueprint=false, warm=false, damp=false}``.
``priority``
    An integer between ``1`` and ``7``, inclusive, indicating the base priority
    for this ``dig`` blueprint. If not specified, defaults to ``4``.
``preserve_engravings``
    Don't designate tiles for digging or carving if they have an engraving with
    at least the specified quality. Value is a ``df.item_quality`` enum name or
    value, or the string ``None`` (or, equivalently, ``-1``) to indicate that no
    engravings should be preserved. Defaults to ``df.item_quality.Masterful``.
``dry_run``
    Just calculate statistics, such as how many tiles are outside the boundaries
    of the map; don't actually apply the blueprint. Defaults to ``false``.
``verbose``
    Output extra debugging information to the console. Defaults to ``false``.

API usage example::

    local quickfort = reqscript('quickfort')

    -- dig a 10x10 block at the mouse cursor position
    quickfort.apply_blueprint{mode='dig', data='d(10x10)',
                              pos=dfhack.gui.getMousePos()}

    -- dig a 10x10 block starting at coordinate x=30, y=40, z=50
    quickfort.apply_blueprint{mode='dig', data={[50]={[40]={[30]='d(10x10)'}}}}
