hide-tutorials
==============

.. dfhack-tool::
    :summary: Hide new fort tutorial popups.
    :tags: adventure fort interface

If you've played the game before and don't need to see the tutorial popups that
show up on every new fort, ``hide-tutorials`` can hide them for you. You can
enable this tool as a system service in the "Services" tab of
`gui/control-panel` so it takes effect for all forts and adventures.

Specifically, this tool hides:

- The popup displayed when creating a new world
- The "Do you want to start a tutorial embark" popup
- Popups displayed the first time you open the labor, burrows, justice, and
  other similar screens in a new fort
- Popups displayed when you perform certain actions for the first time in an
  adventure

Note that only unsolicited tutorial popups are hidden. If you directly request
a tutorial page from the help, then it will still function normally.

Usage
-----

::

    enable hide-tutorials
    hide-tutorials
    hide-tutorials reset

If you haven't enabled the tool, but you run the command while a fort or
adventure is loaded, all future popups for the loaded game will be hidden.

If you run the command with the ``reset`` option, all popups will be re-enabled
as if they had never been seen or dismissed.
