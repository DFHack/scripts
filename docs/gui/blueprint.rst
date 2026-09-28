gui/blueprint
=============

.. dfhack-tool::
    :summary: Record a live game map in a quickfort blueprint.
    :tags: fort design buildings map stockpile


The `blueprint` plugin records the structure of a portion of your fortress in
a blueprint file that you (or anyone else) can later play back with `quickfort`.

This script provides a visual, interactive interface to make configuring and
using the blueprint plugin much easier.

Usage
-----

::

    gui/blueprint [<name> [<phases>]] [<options>]

All parameters are optional, but, if specified, they will override the initial
values set in the interface. See the `blueprint` documentation for information
on the possible options.

Examples
--------

``gui/blueprint``
    Start the blueprint GUI with default initial values.
``gui/blueprint tavern dig build --format pretty``
    Start the blueprint GUI with the blueprint name pre-set to ``tavern``, the
    ``dig`` and ``build`` blueprint phases enabled (and all other phases turned
    off), and with the output format set to ``pretty``.
