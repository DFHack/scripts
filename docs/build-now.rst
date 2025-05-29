build-now
=========

.. dfhack-tool::
    :summary: Instantly completes building construction jobs.
    :tags: fort armok buildings

By default, all unsuspended buildings on the map are completed, but the area of
effect is configurable.

Note that no units will get architecture experience for any buildings that
require that skill to construct.

Usage
-----

::

    build-now [<pos> [<pos>]] [<options>]

Where the optional ``<pos>`` pair can be used to specify the coordinate bounds
within which ``build-now`` will operate. If they are not specified,
``build-now`` will scan the entire map. If only one ``<pos>`` is specified, only
the building at that coordinate is built.

The ``<pos>`` parameters can either be an ``<x>,<y>,<z>`` triple (e.g.
``35,12,150``) or the string ``here``, which means the position of the active
keyboard game cursor.

Examples
--------

``build-now``
    Completes all unsuspended construction jobs on the map.
``build-now here``
    Builds the unsuspended, unconstructed building under the cursor.

Options
-------

``-q``, ``--quiet``
    Suppress informational output (error messages are still printed).
``-z``, ``--zlevel``
    Restrict operation to the currently visible z-level
