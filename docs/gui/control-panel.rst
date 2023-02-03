gui/control-panel
=================

.. dfhack-tool::
    :summary: Configure DFHack.
    :tags: dfhack

The DFHack control panel allows you to quickly see and change what DFHack tools
are enabled now, which tools will run when you start a new fort, and how global
DFHack configuration options are set. It also provides convenient links to
relevant help pages and GUI configuration frontends. The control panel has
several pages that you can switch among by clicking on the tabs at the top of
the window. Each page has a search filter so you can quickly find the tools and
options that you're looking for.

Fort Services
-------------

The fort services page shows tools that you can enable in fort mode. You can
select the tool name to see a short description at the bottom of the list. Hit
:kbd:`Enter` or click on the toggle on the far left to enable or disable that
tool.

Note that the fort services displayed on this page can only be enabled when a
fort is loaded. They will be disabled in the list and cannot be enabled or have
their GUI config screens shown until you have loaded a fortress. Once you do
enable them, they will save their state with your fort and automatically
re-enable themselves when you load your fort again.

You can hit :kbd:`Ctrl`:kbd:`H` or click on the help icon to show the help page
for the selected tool in `gui/launcher`. You can also use this as shortcut to
run custom commandline commands to configure that tool manually. If the tool has
an associated GUI config screen, a gear icon will also appear next to the help
icon. Hit :kbd:`Ctrl`:kbd:`G` or click on that icon to launch the relevant
configuration interface.

New Fort Autostart Commands
---------------------------

This page shows the tools that you can configure DFHack to auto-enable or
auto-run when you start a new fort. You'll recognize many tools from the
previous page here, but there are also useful one-time commands that you might
want to run at the start of a fort, like `ban-cooking all <ban-cooking>`.

Periodic Maintenance Operations
-------------------------------

This page shows commands that DFHack can regularly run for you in order to keep
your fort (and the game) running smoothly. For example, there are commands to
periodically enqueue orders for shearing animals that are ready to be shorn or
sort your manager orders so slow-moving daily orders won't prevent your
high-volume one-time orders from ever being completed.

System Services
---------------

The system services page shows "core" DFHack tools that provide background
services to other tools. It is generally not advisable to turn these tools
off. If you do toggle them off in the control panel, they will be re-enabled
when you restart the game. If you really need to turn these tools off
permanently, add a line like ``disable toolname`` to your
``dfhack-config/init/dfhack.init`` file.

Overlays
--------

The overlays page allows you to easily see which overlays are enabled and lets
you toggle them on and off and see the help for the owning tools. If you want to
reposition any of the overlay widgets, hit :kbd:`Ctrl`:kbd:`G` or click on
the the hotkey hint to launch `gui/overlay`.

Preferences
-----------

The preferences page allows you to change DFHack's internal settings and
defaults, like whether DFHack tools pause the game when they come up, or how
long you can wait between clicks and still have it count as a double-click. Hit
:kbd:`Ctrl`:kbd:`G` or click on the hotkey hint at the bottom of the page to
restore all preferences to defaults.

Usage
-----

::

    gui/control-panel
