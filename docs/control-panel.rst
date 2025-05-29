control-panel
=============

.. dfhack-tool::
    :summary: Configure DFHack and manage active DFHack tools.
    :tags: dfhack

This is the commandline interface for configuring DFHack behavior, toggling
which functionality is enabled right now, and setting up which tools are
enabled/run when starting new fortress games. For an in-game
graphical interface, please use `gui/control-panel`. For a commandline
interface for configuring which overlays are enabled, please use `overlay`.

This interface controls three kinds of configuration:

1. Tools that are enabled right now. These are DFHack tools that run in the
background, like `autofarm`, or tools that DFHack can run on a repeating
schedule, like the "autoMilk" functionality of `workorder`. Most tools that can
be enabled are saved with your fort, so you can have different tools enabled
for different forts. If a tool is marked "global", however, like
`hide-tutorials`, then enabling it will make it take effect for all games.

2. Tools or commands that should be auto-enabled or auto-run when you start a
new fortress. In addition to tools that can be "enabled", this includes
commands that you might want to run once just after you embark, such as
commands to configure `autobutcher` or to drain portions of excessively deep
aquifers.

3. DFHack system preferences, such as whether "Armok" (god-mode) tools are
shown in DFHack lists (including the lists of commands shown by the control
panel) or mouse configuration like how fast you have to click for it to count
as a double click (for example, when maximizing DFHack tool windows).
Preferences are "global" in that they apply to all games.

Run ``control-panel list`` to see the current settings and what tools and
preferences are available for configuration.

Usage
-----

::

    control-panel list <search string>
    control-panel enable|disable <command or number from list>
    control-panel autostart|noautostart <command or number from list>
    control-panel set <preference> <value>
    control-panel reset <preference>

Examples
--------
``control-panel list butcher``
    Shows the current configuration of all commands related to `autobutcher`
    (and anything else that includes the text "butcher" in it).
``control-panel enable fix/empty-wheelbarrows`` or ``control-panel enable 25``
    Starts to run `fix/empty-wheelbarrows` periodically to maintain the
    usability of your wheelbarrows. In the second version of this command, the
    number "25" is used as an example. You'll have to run
    ``control-panel list`` to see what number this command is actually listed
    as.
``control-panel autostart autofarm``
    Configures `autofarm` to become automatically enabled when you start a new
    fort.
``control-panel autostart fix/blood-del``
    Configures `fix/blood-del` to run once when you start a new fort.
``control-panel set HIDE_ARMOK_TOOLS true``
    Enable "mortal mode" and hide "armok" tools in the DFHack UIs. Note that
    this will also remove some entries from the ``control-panel list`` output.
    Run ``control-panel list`` to see all preference options and their
    descriptions.

API
---

Other scripts can query whether a command is set for autostart via the script
API::

    local control_panel = reqscript('control-panel')
    local enabled, default = control_panel.get_autostart(command)
