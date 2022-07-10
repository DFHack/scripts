
devel/kill-hf
=============

Kills the specified historical figure, even if off-site, or terminates a
pregnancy. Useful for working around :bug:`11549`.

Usage::

    devel/kill-hf [-p|--pregnancy] [-n|--dry-run] HISTFIG_ID

Arguments:

``histfig_id``:
    the ID of the historical figure to target

``-p``, ``--pregnancy``:
    if specified, and if the historical figure is pregnant, terminate the
    pregnancy instead of killing the historical figure

``-n``, ``--dry-run``:
    if specified, only print the name of the historical figure

