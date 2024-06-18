hide-tutorials
==============

.. dfhack-tool::
    :summary: Hide new fort tutorial popups.
    :tags: fort interface

If you've played the game before and don't need to see the tutorial popups that
show up on every new fort, ``hide-tutorials`` can hide them for you. You can
enable this tool as a system service in the "Services" tab of
`gui/control-panel` so it takes effect for all new or loaded forts.

Specifically, this tool hides:

- The popup displayed when creating a new world
- The "Do you want to start a tutorial embark" popup
- Popups displayed the first time you open the labor, burrows, justice, and
  other similar screens in a new fort

Note that only unsolicited tutorial popups are hidden. If you directly request
a tutorial page from the help, then it will still function normally.

Usage
-----

::

    enable hide-tutorials
    hide-tutorials

If you haven't enabled the tool, but you run the command while a fort is
loaded, all future popups for the loaded fort will be hidden.
