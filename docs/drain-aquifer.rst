drain-aquifer
=============

.. dfhack-tool::
    :summary: Remove some or all aquifers on the map.
    :tags: fort armok map

This tool irreversibly removes 'aquifer' tags from map blocks. Also see
`prospect` for discovering the range of layers that currently have aquifers.

Usage
-----

::

    drain-aquifer [<options>]

Examples
--------

``drain-aquifer``
    Remove all aquifers on the map.
``drain-aquifer --top 2``
    Remove all aquifers on the map except for the top 2 levels of aquifer.
``drain-aquifer -d``
    Remove all aquifers on the current z-level and below.
``drain-aquifer -f light``
    Remove all light aquifers on the map.


Options
-------

``-t``, ``--top <num>``
    Remove all aquifers on the map except for the top ``<num>`` levels,
    starting from the first level that has an aquifer tile. Note that there may
    be less than ``<num>`` levels of aquifer after the command is run if the
    levels of aquifer are not contiguous.
``-d``, ``--zdown``
    Remove all aquifers on the current z-level and below.
``-u``, ``--zup``
    Remove all aquifers on the current z-level and above.
``-z``, ``--cur-zlevel``
    Remove all aquifers on the current z-level.
``-f``, ``--filter [light/heavy]``
    Remove all light or heavy aquifers.