fix/corrupt-jobs
================

.. dfhack-tool::
    :summary: Removes jobs with an id of -1 from units.
    :tags: fort bugfix

This fix cleans up corrupt jobs so they don't cause crashes. It runs automatically on fort load, so you don't have to run it manually.

Usage
-----

::

    fix/corrupt-jobs
