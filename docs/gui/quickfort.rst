gui/quickfort
=============
Graphical interface for the `quickfort` script. Once you load a blueprint, you
will see a blinking "shadow" over the tiles that will be modified. You can use
the cursor to reposition the blueprint or the hotkeys to rotate and repeat the
blueprint up or down z-levels. Once you are satisfied, hit :kbd:`ENTER` to apply
the blueprint to the map.

Usage::

    gui/quickfort [<search terms>]

If the (optional) search terms match a single blueprint (e.g. if the search
terms are copied from the ``quickfort list`` output like
``gui/quickfort library/dreamfort.csv -n /industry1``), then that blueprint is
pre-loaded into the UI and a preview for that blueprint appears. Otherwise, a
dialog is shown where you can select a blueprint to load.

You can also type search terms in the dialog and the list of matching blueprints
will be filtered as you type. You can search for directory names, file names,
blueprint labels, modes, or comments. Note that, depending on the active list
filters, the id numbers in the list may not be contiguous.

To rotate or flip the blueprint around, enable transformations with :kbd:`t` and
use :kbd:`Ctrl` with the arrow keys to add a transformation step:

:kbd:`Ctrl`:kbd:`Left`:  Rotate counterclockwise (ccw)
:kbd:`Ctrl`:kbd:`Right`: Rotate clockwise (cw)
:kbd:`Ctrl`:kbd:`Up`:    Flip vertically (vflip)
:kbd:`Ctrl`:kbd:`Down`:  Flip horizontally (hflip)

If a shorter transformation sequence can be used to get the blueprint into the
configuration you want, it will automatically be used. For example, if you
rotate clockwise three times, gui/quickfort will shorten the sequence to a
single counterclockwise rotation for you.

Any settings you set in the UI, such as search terms for the blueprint list or
transformation options, are saved for the next time you run the script.

Examples:

============================== =================================================
Command                        Effect
============================== =================================================
gui/quickfort                  opens the quickfort interface with saved settings
gui/quickfort dreamfort        opens with a custom blueprint filter
gui/quickfort myblueprint.csv  opens with the specified blueprint pre-loaded
============================== =================================================
