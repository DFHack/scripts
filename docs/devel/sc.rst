devel/sc
========

.. dfhack-tool::
    :summary: Scan DF structures for errors.
    :tags: dev

Size Check: scans structures for invalid vectors, misaligned structures, and
unidentified enum values.

.. note::

    This script can take a very long time to complete, and DF may be
    unresponsive while it is running. You can use `kill-lua` to interrupt
    this script.

Usage
-----

``devel/sc``
    Scan ``world``.
``devel/sc -all``
    Scan all globals.
``devel/sc <expr>``
    Scan the result of the given expression.
