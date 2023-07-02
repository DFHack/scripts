ban-cooking
===========

.. dfhack-tool::
    :summary: Protect entire categories of ingredients from being cooked.
    :tags: fort productivity items plants

This tool provides a far more convenient way to ban cooking categories of foods
than the native kitchen interface.

Usage
-----

::
    ban-cooking <type|all> [<type> ...] [<options>]

Valid types are ``booze``, ``brew``, ``fruit``, ``honey``, ``milk``, ``mill``,
``oil``, ``seeds`` (i.e. non-tree plants with seeds), ``tallow``, and
``thread``. It is possible to include multiple types or all types in a single ban-cooking
call: ``ban-cooking oil tallow`` will ban both oil and tallow from cooking.
``ban-cooking all`` will ban all types from cooking.

Examples::

    on-new-fortress ban-cooking all

Ban cooking all otherwise useful ingredients once when starting a new fortress.
Note that this exact command can be enabled via the ``Autostart`` tab of
`gui/control-panel`.

Options
-------

``-v``, ``--verbose``
    Print each ban as it happens.
