autosave
========

.. dfhack-tool::
    :summary: Automatically save the game on a real-time schedule.
    :tags: fort gameplay

When enabled, ``autosave`` periodically checks how much real time has passed
since the game was last saved (or loaded), and runs `quicksave` once the
configured interval has elapsed.

Unlike the vanilla seasonal autosaves, the interval is measured in real time
rather than game time, and it keeps counting even while the game is paused.
The interval applies globally across all your forts and worlds, while the
enabled state is remembered per fort.

Usage
-----

::

    enable autosave
    autosave [status]
    autosave set <minutes>
    autosave now

``autosave`` or ``autosave status``
    Show whether autosave is enabled, the configured interval, and how much
    time has passed since the last save.
``autosave set <minutes>``
    Set how often the game is saved, in minutes of real time. The default is
    30 minutes.
``autosave now``
    Save the game immediately.

You can also enable and disable ``autosave`` on the Automation tab of the
DFHack control panel.
