unforbid
========

.. dfhack-tool::
    :summary: Unforbid all items.
    :tags: fort productivity items

This tool quickly and easily unforbids all items. This is especially useful
after a siege to allow cleaning up the mess (or dumping of caged prisoner's
equipment with `stripcaged`).

Usage
-----

::

    unforbid all [<options>]

Options
-------

``-u``, ``--include-unreachable``
    Allows the tool to unforbid unreachable items.

``-q``, ``--quiet``
    Suppress non-error console output.

``-X``, ``--include-worn``
    Include worn (X) and tattered (XX) items when unforbidding.
