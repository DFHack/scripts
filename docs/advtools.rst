advtools
========

.. dfhack-tool::
    :summary: A collection of useful adventure mode tools.
    :tags: adventure interface

Usage
-----

::

    advtools party add-core [<options>]

Examples
--------

``advtools party add-core``
    Add the selected "extra" party member to your core party.

``party`` Options
-----------------

TBD

Overlays
--------

This tool provides several functions that are managed by the overlay
framework. They can be repositioned via `gui/overlay` or toggled via
`gui/control-panel`.

``advtools.conversation``
~~~~~~~~~~~~~~~~~~~~~~~~~

When enabled, this overlay will automatically add additional searchable
keywords to conversation topics. In particular, topics that relate to slain
enemies will gain the ``slay`` and ``kill`` keywords.
