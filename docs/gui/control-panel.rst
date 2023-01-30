gui/control-panel
=================

.. dfhack-tool::
    :summary: Configure DFHack.
    :tags: dfhack

The DFHack control panel allows you to quickly see what DFHack tools are enabled
and how configuration options are set. It also provides convenient links to the
tool help pages and the GUI configuration frontends. The control panel has four
pages that you can cycle through with the :kbd:`Ctrl`:kbd:`N` hotkey or by
clicking on the hotkey hint at the top of the window.

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

You can hit :kbd:`Ctrl`:kbd:`H` or click on the ``[help]`` button next to a
tool name to show its help page in `gui/launcher`. You can also use this as
shortcut to run custom commandline commands to configure that tool manually.
If the tool has an associated GUI config screen, a ``[configure]`` button will
also appear next to the tool name. Hit :kbd:`Ctrl`:kbd:`G` or click on that
button to launch the configuration interface.

Overlays
--------

The overlays page is a more concise version of `gui/overlay`, allowing you to
easily see which overlays are enabled and toggle them on and off. If you want
to reposition any of the overlay widgets, hit :kbd:`Ctrl`:kbd:`G` or click on
the ``[configure]`` button to launch `gui/overlay`.

Preferences
-----------

The preferences page allows you to change DFHack's internal settings and
defaults. Anything you change here will only be used for the current game
session. To persist your settings changes across game sessions, hit
:kbd:`Ctrl`:kbd:`G` or click on the hotkey hint at the bottom of the page.

System Services
---------------

The system services page shows the "global" DFHack tools whose state is not
tied to a particular fort. It is generally not advisable to turn these tools
off since they provide background services to other tools. If you toggle them
off in the control panel, they will be re-enabled when you restart the game.
If you need to turn these tools off permanently, add a line like
``disable toolname`` to your ``dfhack-config/init/dfhack.init`` file.

Usage
-----

::

    gui/control-panel
