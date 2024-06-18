warn-stranded
=============

.. dfhack-tool::
    :summary: Reports citizens who can't reach any other citizens.
    :tags: fort units

If any groups of sane fort citizens are stranded from the main (largest) group,
you'll get a warning dialog telling you which citizens are isolated. This gives
you a chance to rescue them before they get overly stressed or starve.

There is a command line interface that can print status of citizens without
pausing or bringing up a window.

If there are citizens that you are ok with stranding (say, you have isolated a
potential werebeast or vampire), you can mark them as ignored so they won't
trigger a warning.

This tool is integrated with `gui/notify` to automatically show notifications
when a stranded unit is detected.

Usage
-----

::

    warn-stranded
    warn-stranded status
    warn-stranded clear
    warn-stranded (ignore|unignore) <unit id>
    warn-stranded (ignoregroup|unignoregroup) <group id>

Examples
--------

``warn-stranded``
    Standard command that checks citizens and pops up a warning if any are
    stranded. Does nothing when there are no unignored stranded citizens.

``warn-stranded status``
    List all groups of stranded citizens and all ignored citizens. Also shows
    individual unit ids.

``warn-stranded clear``
    Clear (unignore) all ignored citizens.

``warn-stranded ignore 15343``
    Ignore citizen with unit id 15343.

``warn-stranded ignoregroup 2``
    Ignore stranded citizen group 2.
