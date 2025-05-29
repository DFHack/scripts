devel/kill-hf
=============

.. dfhack-tool::
    :summary: Kill a historical figure.
    :tags: unavailable

This tool can kill the specified historical figure, even if off-site, or
terminate a pregnancy. Useful for working around :bug:`11549`.

Usage
-----

::

    devel/kill-hf [-p|--pregnancy] [-n|--dry-run] <histfig_id>

Options
-------

``histfig_id``
    The ID of the historical figure to target.
``-p``, ``--pregnancy``
    If specified, and if the historical figure is pregnant, terminate the
    pregnancy instead of killing the historical figure.
``-n``, ``--dry-run``
    If specified, only print the name of the historical figure instead of making
    any changes.
