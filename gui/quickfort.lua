-- in-game dialog interface for the quickfort script
--[====[
gui/quickfort
=============
In-game dialog interface for the `quickfort` script. Any arguments passed to
this script are passed directly to `quickfort`. Invoking this script without
arguments is equivalent to running ``quickfort gui``.

Examples:

==============================  ======================================
Command                         Effect
==============================  ======================================
gui/quickfort                   opens quickfort interactive dialog
gui/quickfort gui               same as above
gui/quickfort gui -l dreamfort  opens the dialog with a custom filter
gui/quickfort help              prints quickfort help (on the console)
==============================  ======================================
]====]

local args = {...}

if #args == 0 then
    dfhack.run_script('quickfort', 'gui')
else
    dfhack.run_script('quickfort', table.unpack(args))
end
