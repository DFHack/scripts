gui/quickfort
=============

.. dfhack-tool::
    :summary: Apply layout blueprints to your fort.
    :tags: fort design productivity buildings map stockpiles

This is the graphical interface for the `quickfort` script. Once you load a
blueprint, you will see a highlight over the tiles that will be modified. You
can use the mouse cursor to reposition the blueprint and the hotkeys to
rotate and repeat the blueprint up or down z-levels. Once you are satisfied,
click the mouse or hit :kbd:`Enter` to apply the blueprint to the map.

You can apply the blueprint as many times as you wish to different spots on the
map. If a blueprint that you designated was only partially applied (due to job
cancellations, incomplete dig area, or any other reason) you can apply the
blueprint a second time in the same spot to fill in any gaps. Any part of the
blueprint that has already been completed will be harmlessly skipped. Right
click or hit :kbd:`Esc` to close the `gui/quickfort` UI.

Note that `quickfort` blueprints will use the DFHack building planner
(`buildingplan`) material filter settings. If you want specific materials to be
used, use the building planner UI to set the appropriate filters before
applying a blueprint.

Usage
-----

::

    gui/quickfort [<search terms>]

If the (optional) search terms match a single blueprint (e.g. if the search
terms are copied from the ``quickfort list`` output like
``gui/quickfort library/aquifer_tap.csv -n /dig``), then that blueprint is
pre-loaded into the UI and a preview for that blueprint appears. Otherwise, a
dialog is shown where you can select a blueprint to load.

You can also type search terms in the dialog and the list of matching blueprints
will be filtered as you type. You can search for directory names, file names,
blueprint labels, modes, or comments. Note that, depending on the active
filters, the id numbers in the list may not be contiguous.

To rotate or flip the blueprint around, enable transformations with :kbd:`t` and
use the following keys to add a transformation step:

:kbd:`(`:  Rotate counterclockwise (ccw)
:kbd:`)`: Rotate clockwise (cw)
:kbd:`_`:    Flip vertically (vflip)
:kbd:`=`:  Flip horizontally (hflip)

If you have applied several transformations, but there is a shorter sequence
that can be used to get the blueprint into the configuration you want, it will
automatically be used. For example, if you rotate clockwise three times,
``gui/quickfort`` will shorten the sequence to a single counterclockwise
rotation for you.

Any settings you set in the UI, such as search terms for the blueprint list or
transformation options, are saved for the next time you open the UI. This is for
convenience when you are applying multiple related blueprints that need to have
the same transformation and repetition settings when they are applied.

Examples
--------

``gui/quickfort``
    Open the quickfort interface with saved settings.
``gui/quickfort dreamfort``
    Open with a custom filter that shows only blueprints that match the string
    ``dreamfort``.
``gui/quickfort myblueprint.csv``
    Open with the ``myblueprint.csv`` blueprint pre-loaded.
