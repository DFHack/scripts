gui/seedwatch
=============

.. dfhack-tool::
    :summary: Manages seed and plant cooking based on seed stock levels.
    :tags: fort auto plants

This is the configuration interface for the `seedwatch` plugin. You can
configure a target stock amount for each seed type. If the number of seeds of
that type falls below the target, then the plants and seeds of that type will
be protected from cookery. If the number rises above the target + 20, then
cooking will be allowed again.

Usage
-----

::

    gui/seedwatch
