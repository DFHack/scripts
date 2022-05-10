-- DFHack-native implementation of the classic Quickfort utility
--@module = true
--[====[

quickfort
=========
Processes Quickfort-style blueprint files.

Quickfort blueprints record what you want at each map coordinate in a
spreadsheet, storing the keys in a spreadsheet cell that you would press to make
something happen at that spot on the DF map. Quickfort runs in one of five
modes: ``dig``, ``build``, ``place``, ``zone``, or ``query``. ``dig`` designates
tiles for digging, ``build`` builds buildings and constructions, ``place``
places stockpiles, ``zone`` manages activity zones, and ``query`` changes
building or stockpile settings. The mode is determined by a marker in the
upper-left cell of the spreadsheet (e.g.: ``#dig`` in cell ``A1``).

You can create these blueprints by hand or by using any spreadsheet application,
saving them as ``.xlsx`` or ``.csv`` files. You can also build your plan "for
real" in Dwarf Fortress, and then export your map using the DFHack
`blueprint` plugin (or `gui/blueprint` script) for later replay. Blueprint files
should go in the ``blueprints`` subfolder in the main DF folder.

For more details on blueprint file syntax, see the `quickfort-blueprint-guide`
or browse through the ready-to-use examples in the `blueprint-library-guide`.

Usage:

**quickfort set [<key> <value>]**
    Allows you to modify the active quickfort configuration. Just run
    ``quickfort set`` to show current settings. See the Configuration section
    below for available keys and values.
**quickfort reset**
    Resets quickfort configuration to the defaults in ``quickfort.txt``.
**quickfort list [-m|-\-mode <mode>] [-l|-\-library] [-h|-\-hidden] [search string]**
    Lists blueprints in the ``blueprints`` folder. Blueprints are ``.csv`` files
    or sheets within ``.xlsx`` files that contain a ``#<mode>`` comment in the
    upper-left cell. By default, blueprints in the ``blueprints/library/``
    subfolder or blueprints that contain a ``hidden()`` marker in their modeline
    are not shown. Specify ``-l`` or ``-h`` to include library or hidden
    blueprints, respectively. The list can be filtered by a specified mode (e.g.
    "-m build") and/or strings to search for in a path, filename, mode, or
    comment. The id numbers in the list may not be contiguous if there are
    hidden or filtered blueprints that are not being shown.
**quickfort gui [filename or search terms]**
    Invokes the quickfort UI with the specified parameters, giving you an
    interactive blueprint preview to work with before you apply it to the map.
    See the `gui/quickfort` documentation for details.
**quickfort <command>[,<command>...] <list_num>[,<list_num>...] [<options>]**
    Applies the blueprint(s) with the number(s) from the ``list`` command.
**quickfort <command>[,<command>...] <filename> [-n|-\-name <name>[,<name>...]] [<options>]**
    Applies a blueprint in the specified file. The optional ``name`` parameter
    can select a specific blueprint from a file that contains multiple
    blueprints with the format "sheetname/label", or just "/label" for .csv
    files. The label is defined in the blueprint modeline, or, if not defined,
    defaults to its order in the sheet or file (e.g. "/2"). If the ``-n``
    parameter is not specified, the first blueprint in the first sheet is used.

**<command>** is one of:

:run:     Applies the blueprint at your current in-game cursor position.
:orders:  Uses the manager interface to queue up orders to manufacture items for
          the specified blueprint(s).
:undo:    Applies the inverse of the specified blueprint. Dig tiles are
          undesignated, buildings are canceled or removed (depending on their
          construction status), and stockpiles/zones are removed. There is no
          effect for query blueprints since they can contain arbitrary key
          sequences.

**<options>** can be zero or more of:

``-c``, ``--cursor <x>,<y>,<z>``
    Use the specified map coordinates instead of the current map cursor for the
    the blueprint start position. If this option is specified, then an active
    game map cursor is not necessary.
``-d``, ``--dry-run``
    Go through all the motions and print statistics on what would be done, but
    don't actually change any game state.
``--preserve-engravings <quality>``
    Don't designate tiles for digging if they have an engraving with at least
    the specified quality. Valid values for ``quality`` are: ``None``,
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
    map. See the Transformations section below for details.
``-v``, ``--verbose``
    Output extra debugging information. This is especially useful if the
    blueprint isn't being applied like you expect.

Example commands::

    quickfort list
    quickfort list -l dreamfort help
    quickfort run library/dreamfort.csv
    quickfort run,orders library/dreamfort.csv -n /industry2
    quickfort run 10 -dv

Transformations:

All transformations are anchored at the blueprint start cursor position. This is
the upper left corner by default, but it can be modified if the blueprint has a
`start() modeline marker <quickfort-start>`. This just means that the blueprint
tile that would normally appear under your cursor will still appear under your
cursor, regardless of how the blueprint is rotated or flipped.

**<transformation>** is one of:

:rotcw or cw:   Rotates the blueprint 90 degrees clockwise.
:rotccw or ccw: Rotates the blueprint 90 degrees counterclockwise.
:fliph:         Flips the blueprint horizontally (left edge becomes right edge).
:flipv:         Flips the blueprint vertically (top edge becomes bottom edge).

Configuration:

The quickfort script reads its startup configuration from the
``dfhack-config/quickfort/quickfort.txt`` file, which you can customize. The
settings may be dynamically modified by the ``quickfort set`` command for the
current session, but settings changed with the ``quickfort set`` command will
not change the configuration stored in the file:

``blueprints_dir`` (default: 'blueprints')
    Directory tree to search for blueprints. Can be set to an absolute or
    relative path. If set to a relative path, resolves to a directory under the
    DF folder. Note that if you change this directory, you will not see
    blueprints written by the DFHack `blueprint` plugin (which always writes to
    the ``blueprints`` dir) or blueprints in the quickfort blueprint library.
``force_marker_mode`` (default: 'false')
    If true, will designate all dig blueprints in marker mode. If false, only
    cells with dig codes explicitly prefixed with ``m`` will be designated in
    marker mode.
``query_unsafe`` (default: 'false')
    Skip query blueprint sanity checks that detect common blueprint errors and
    halt or skip keycode playback. Checks include ensuring a configurable
    building exists at the designated cursor position and verifying the active
    UI screen is the same before and after sending keys for the cursor
    position. If you find you need to enable this for one of your own
    blueprints, you should probably be using a
    `config blueprint <quickfort-config-blueprints>`, not a query blueprint.
    Most players will never need to enable this setting.
``stockpiles_max_barrels``, ``stockpiles_max_bins``, and ``stockpiles_max_wheelbarrows`` (defaults: -1, -1, 0)
    Set to the maximum number of resources you want assigned to stockpiles of
    the relevant types. Set to -1 for DF defaults (number of stockpile tiles
    for stockpiles that take barrels and bins, 1 wheelbarrow for stone
    stockpiles). The default here for wheelbarrows is 0 since using wheelbarrows
    can *decrease* the efficiency of your fort unless you know how to use them
    properly. Blueprints can `override <quickfort-place-containers>` this value
    for specific stockpiles.

There is one other configuration file in the ``dfhack-config/quickfort`` folder:
:source:`aliases.txt <dfhack-config/quickfort/aliases.txt>`. It defines keycode
shortcuts for query blueprints. The format for this file is described in the
`quickfort-alias-guide`, and default aliases that all players can use and build
on are available in the `quickfort-alias-library`. Some quickfort library
aliases require the `search-plugin` plugin to be enabled.

API:

The quickfort script can be called programmatically by other scripts either via
the commandline interface with ``dfhack.run_script()`` or via the API functions
defined in :source-scripts:`quickfort.lua`:

* ``apply_blueprint(params)``

Applies the specified blueprint data and returns processing statistics. The
statistics structure is a map of stat ids to ``{label=string, value=number}``.

``params`` is a table with the following fields:

:``mode``: (required) The name of the blueprint mode, e.g. 'dig', 'build', etc.
:``data``: (required) A sparse map populated such that ``data[z][y][x]`` yields
    the blueprint text that should be applied to the tile at map coordinate
    ``(x, y, z)``. You can also just pass a string and it will be interpreted
    as the value of ``data[0][0][0]``.
:``command``: The quickfort command to execute, e.g. 'run', 'orders', etc.
    Defaults to 'run'.
:``pos``: A coordinate that serves as the reference point for the coordinates in
    the data map. That is, the text at ``data[z][y][x]`` will be shifted to be
    applied to coordinate ``(pos.x + x, pos.y + y, pos.z + z)``. If not
    specified, defaults to ``{x=0, y=0, z=0}``, which means that the coordinates
    in the ``data`` map are used directly.
:``aliases``: a map of query blueprint aliases names to their expansions. If not
    specified, defaults to ``{}``.
:``preserve_engravings``: Don't designate tiles for digging if they have an
    engraving with at least the specified quality. Value is a df.item_quality
    enum name or value, or "None" (or, equivalently, -1) to indicate that no
    engravings should be preserved. Defaults to ``df.item_quality.Masterful``.
:``dry_run``: Just calculate statistics, such as how many tiles are outside the
    boundaries of the map; don't actually apply the blueprint. Defaults to
    false.
:``verbose``: Output extra debugging information to the console. Defaults to
    false.

API usage example::

    local guidm = require('gui.dwarfmode')
    local quickfort = reqscript('quickfort')
    -- dig a 10x10 block at the cursor position
    quickfort.apply_blueprint{mode='dig', data={[0]={[0]={[0]='d(10x10)'}}},
                              pos=guidm.getCursorPos()}
]====]

local argparse = require('argparse')

-- reqscript all internal files here, even if they're not directly used by this
-- top-level file. this ensures modified transitive dependencies are properly
-- reloaded when this script is run.
local quickfort_aliases = reqscript('internal/quickfort/aliases')
local quickfort_api = reqscript('internal/quickfort/api')
local quickfort_build = reqscript('internal/quickfort/build')
local quickfort_building = reqscript('internal/quickfort/building')
local quickfort_command = reqscript('internal/quickfort/command')
local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_config = reqscript('internal/quickfort/config')
local quickfort_dig = reqscript('internal/quickfort/dig')
local quickfort_keycodes = reqscript('internal/quickfort/keycodes')
local quickfort_list = reqscript('internal/quickfort/list')
local quickfort_map = reqscript('internal/quickfort/map')
local quickfort_meta = reqscript('internal/quickfort/meta')
local quickfort_notes = reqscript('internal/quickfort/notes')
local quickfort_orders = reqscript('internal/quickfort/orders')
local quickfort_parse = reqscript('internal/quickfort/parse')
local quickfort_place = reqscript('internal/quickfort/place')
local quickfort_preview = reqscript('internal/quickfort/preview')
local quickfort_query = reqscript('internal/quickfort/query')
local quickfort_reader = reqscript('internal/quickfort/reader')
local quickfort_set = reqscript('internal/quickfort/set')
local quickfort_transform = reqscript('internal/quickfort/transform')
local quickfort_zone = reqscript('internal/quickfort/zone')

-- keep this in sync with the full help text above
local function print_short_help()
    print [=[
Usage:

quickfort set [<key> <value>]
    Allows you to temporarily modify the active quickfort configuration. Just
    run "quickfort set" to show current settings.
quickfort reset
    Resets quickfort configuration to defaults in quickfort.txt.
quickfort list [-m|--mode <mode>] [-l|--library] [-h|--hidden] [search string]
    Lists blueprints in the "blueprints" folder. Specify -l to include library
    blueprints and -h to include hidden blueprints. The list can be filtered by
    a specified mode (e.g. "-m build") and/or strings to search for in a path,
    filename, mode, or comment.
quickfort gui [filename or search terms]
    Invokes the quickfort UI with the specified parameters, giving you an
    interactive blueprint preview to work with before you apply it to the map.
    See the gui/quickfort documentation for details.
quickfort <command>[,<command>...] <list_num>[,<list_num>...] [<options>]
    Applies the blueprint(s) with the number(s) from the list command.
quickfort <command>[,<command>...] <filename> [-n|--name <name>[,<name>...]] [<options>]
    Applies a blueprint in the specified file. The optional name parameter can
    select a specific blueprint from a file that contains multiple blueprints
    with the format "sheetname/label", or just "/label" for .csv files. If -n is
    not specified, the first blueprint in the first sheet is used.

<command> is one of:

run     Applies the blueprint at your current in-game cursor position.
orders  Uses the manager interface to queue up orders to manufacture items for
        the specified blueprint.
undo    Applies the inverse of the specified blueprint. Dig tiles are
        undesignated, buildings are canceled or removed (depending on their
        construction status), and stockpiles/zones are removed. There is no
        effect for query blueprints since they can contain arbitrary key
        sequences.

<options> can be zero or more of:

-c, --cursor <x>,<y>,<z>
    Use the specified map coordinates instead of the current map cursor for the
    blueprint start position. If this option is specified, then an active game
    map cursor is not necessary.
-d, --dry-run
    Go through all the motions and print statistics on what would be done, but
    don't actually change any game state.
--preserve-engravings <quality>
    Don't designate tiles for digging if they have an engraving with at least
    the specified quality. Valid values for "quality" are: "None", "Ordinary",
    "WellCrafted", "FinelyCrafted", "Superior", "Exceptional", and "Masterful".
    Specify "None" to ignore engravings when designating tiles. Note that if
    "Masterful" tiles are dug out, the dwarf who engraved the masterwork will
    get negative thoughts. If not specified, "Masterful" engravings are
    preserved by default.
-q, --quiet
    Suppress non-error console output.
-r, --repeat <direction>[,]<num levels>
    Repeats the specified blueprint(s) up or down the requested number of
    z-levels. Direction can be "up" or "down", and can be abbreviated with "<"
    or ">". For example, the following options are equivalent:
    "--repeat down,5", "-rdown5", and "-r>5".
-s, --shift <x>[,<y>]
    Shifts the blueprint by the specified offset before modifying the game map.
    The values for "<x>" and "<y>" can be negative. If both "--shift" and
    "--transform" are specified, the shift is always applied last.
-t, --transform <transformation>[,<transformation>...]
    Applies geometric transformations to the blueprint before modifying the game
    map. Valid transformations are: rotcw (or cw), rotccw (or ccw), fliph, and
    flipv.
-v, --verbose
    Output extra debugging information. This is especially useful if the
    blueprint isn't being applied like you expect.

For more info, see:
https://docs.dfhack.org/en/stable/docs/_auto/base.html#quickfort and
https://docs.dfhack.org/en/stable/docs/guides/quickfort-user-guide.html
]=]
end

-- public API
function apply_blueprint(params)
    local data, cursor = quickfort_api.normalize_data(params.data, params.pos)
    local ctx = quickfort_api.init_api_ctx(params, cursor)

    quickfort_common.verbose = not not params.verbose
    dfhack.with_finalize(
        function() quickfort_common.verbose = false end,
        function()
            for zlevel,grid in pairs(data) do
                quickfort_command.do_command_raw(params.mode, zlevel, grid, ctx)
            end
        end)
    return quickfort_api.clean_stats(ctx.stats)
end

-- interactive script
if dfhack_flags.module then
    return
end

local function do_gui(params)
    dfhack.run_script('gui/quickfort', table.unpack(params))
end

local action_switch = {
    set=quickfort_set.do_set,
    reset=quickfort_set.do_reset,
    list=quickfort_list.do_list,
    gui=do_gui,
    run=quickfort_command.do_command,
    orders=quickfort_command.do_command,
    undo=quickfort_command.do_command
}
setmetatable(action_switch, {__index=function() return print_short_help end})

local args = {...}
local action = table.remove(args, 1) or 'help'
args.commands = argparse.stringList(action)

local action_fn = action_switch[args.commands[1]]

if (action == 'run' or action == 'orders' or action == 'undo') and
        not dfhack.isMapLoaded() then
    qerror('quickfort needs a fortress map to be loaded.')
end

action_fn(args)
