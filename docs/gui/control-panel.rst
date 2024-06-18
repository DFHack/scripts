gui/control-panel
=================

.. dfhack-tool::
    :summary: Configure DFHack and manage active DFHack tools.
    :tags: dfhack

The DFHack control panel allows you to quickly see and change what DFHack tools
are enabled, which tools will run when you start a new fort, which UI overlays
are enabled, and how global DFHack configuration options are set. It also
provides convenient links to relevant help pages and GUI configuration
frontends (where available). The control panel has several sections that you
can access by clicking on the tabs at the top of the window. Each tab has a
search filter so you can quickly find the tools and options that you're looking
for.

The tabs can also be navigated with the keyboard, with the :kbd:`Ctrl`:kbd:`T`
and :kbd:`Ctrl`:kbd:`Y` hotkeys. These are the default hotkeys for navigating
DFHack tab bars.

The "Automation", "Bug Fixes", and "Gameplay" tabs
--------------------------------------------------

These three tabs provide access to the three main subcategories of DFHack tools.
In general, you'll probably want to start with only the "Bugfix" tools enabled.
As you become more comfortable with vanilla systems, and some of them start to
become less fun and more toilsome, you can enable more of the "Automation"
tools to manage them for you. Finally, you can examine the tools on the
"Gameplay" tab and enable whatever you think sounds like fun :).

Under each of these tabs, there are two subtabs: "Enabled" and "Autostart". The
subtabs can be navigated with the keyboard, using the :kbd:`Ctrl`:kbd:`N` and
:kbd:`Ctrl`:kbd:`M` hotkeys.

The "Enabled" subtab
~~~~~~~~~~~~~~~~~~~~

The "Enabled" tab allows you to toggle which tools are enabled right now. You
can select the tool in the list to see a short description at the bottom. Hit
:kbd:`Enter`, double click on the tool name, or click on the toggle on the far
left to enable or disable that tool.

Note that before a fort is loaded, there will be very few tools listed here.
Come back when a fort is loaded to see much more.

Once tools are enabled, they will save their state with your fort and
automatically re-enable themselves when you load that same fort again.

You can hit :kbd:`Ctrl`:kbd:`H` or click on the help icon to show the help page
for the selected tool in `gui/launcher`. You can also use this as shortcut to
run custom commandline commands to configure that tool manually. If the tool has
an associated GUI config screen, a gear icon will also appear next to the help
icon. Hit :kbd:`Ctrl`:kbd:`G`, click on the gear icon, or Shift-double click
the tool name to launch the relevant configuration interface.

.. _dfhack-examples-guide:

The "Autostart" subtab
~~~~~~~~~~~~~~~~~~~~~~

This subtab is organized similarly to the "Enabled" subtab, but instead of
tools you can enable now, it shows the tools that you can configure DFHack to
auto-enable or auto-run when you start the game or a new fort. You'll recognize
many tools from the "Enabled" subtab here, but there are also useful one-time
commands that you might want to run at the start of a fort, like
`ban-cooking all <ban-cooking>` or (if you have "mortal mode" disabled in the
"Preferences" tab) god-mode tools like `light-aquifers-only`.

The "UI Overlays" tab
---------------------

DFHack overlays add information and additional functionality to the vanilla DF
screens. For example, the popular DFHack `Building Planner <buildingplan>` is
an overlay named ``buildingplan.planner`` that appears when you are building
something.

The "Overlays" tab allows you to easily see which overlays are enabled, gives
you a short description of what each one does, lets you toggle them on and off,
and gives you links for the related help text (which is normally added at the
bottom of the help page for the tool that provides the overlay). If you want to
reposition any of the overlay widgets, hit :kbd:`Ctrl`:kbd:`G` or click on the
the hotkey hint to launch `gui/overlay`.

The "Preferences" tab
---------------------

The "Preferences" tab allows you to change DFHack's internal settings and
defaults, like whether DFHack's "mortal mode" is enabled -- hiding the god-mode
tools from the UI, whether DFHack tools pause the game when they come up, or how
long you can take between clicks and still have it count as a double-click.
Click on the gear icon or hit :kbd:`Enter` to toggle or edit the selected
preference.

Usage
-----

::

    gui/control-panel
